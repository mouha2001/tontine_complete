<?php

namespace App\Http\Controllers;

use App\Models\Sutura;
use App\Models\SuturaVote;
use App\Models\Tontine;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class SuturaController extends Controller
{
    public function __construct(private NotificationService $notifService) {}

    // ─── LISTE DES URGENCES ───────────────────────────────────────────────────
    public function index(Request $request): JsonResponse
    {
        $user  = $request->user();
        $query = Sutura::with('tontine');

        if ($request->filled('tontine_id')) {
            $tontineId = $request->integer('tontine_id');
            $this->authorizeAccessToTontine($user, $tontineId);
            $query->where('tontine_id', $tontineId);
        } else {
            // Toutes les urgences des tontines accessibles (créées + rejointes)
            $tontineIds = Tontine::where('admin_id', $user->id)
                ->orWhereHas('membres', fn($q) => $q->where('user_id', $user->id))
                ->pluck('id');
            $query->whereIn('tontine_id', $tontineIds);
        }

        $suturas = $query->orderByDesc('created_at')->get();
        $userId  = $user->id;

        return response()->json([
            'data' => $suturas->map(fn($s) => $this->formatSutura($s, $userId))->values(),
        ]);
    }

    // ─── CRÉER UNE URGENCE ────────────────────────────────────────────────────
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'tontine_id'      => 'required|integer|exists:tontines,id',
            'montant_demande' => 'required|numeric|min:1',
            'motif'           => 'required|string|min:10|max:500',
        ]);

        $user    = $request->user();
        $tontine = Tontine::with('membres')->findOrFail($request->tontine_id);

        // Vérifier que l'utilisateur est membre
        if (!$tontine->membres()->where('user_id', $user->id)->exists()) {
            return response()->json(['message' => 'Vous n\'êtes pas membre de cette tontine'], 403);
        }

        // Vérifier qu'il n'a pas une urgence en cours
        $urgenceEnCours = Sutura::where('tontine_id', $tontine->id)
            ->where('demandeur_id', $user->id)
            ->where('statut', 'en_cours')
            ->exists();

        if ($urgenceEnCours) {
            return response()->json(['message' => 'Vous avez déjà une urgence en cours'], 422);
        }

        $sutura = Sutura::create([
            'tontine_id'     => $tontine->id,
            'demandeur_id'   => $user->id, // stocké en DB mais jamais exposé dans l'API
            'montant_demande' => $request->montant_demande,
            'motif'          => $request->motif,
            'statut'         => 'en_cours',
        ]);

        // Notifier TOUS les membres (anonyme côté UI)
        $tontine->membres->each(function ($membre) use ($sutura, $tontine) {
            if ($membre->id !== $sutura->demandeur_id) {
                $this->notifService->send(
                    $membre->id,
                    'vote_sutura',
                    '🤝 Sutura — Vote requis',
                    "Un membre a soumis une demande d'urgence de {$sutura->montant_demande} FCFA dans {$tontine->nom}",
                    ['tontine_id' => $tontine->id, 'sutura_id' => $sutura->id],
                );
            }
        });

        return response()->json([
            'message' => 'Demande d\'urgence soumise anonymement',
            'data'    => $this->formatSutura($sutura, $user->id),
        ], 201);
    }

    // ─── VOTER ────────────────────────────────────────────────────────────────
    public function voter(Request $request, int $id): JsonResponse
    {
        $request->validate(['approuve' => 'required|boolean']);

        $user   = $request->user();
        $sutura = Sutura::with('tontine.membres')->findOrFail($id);

        if ($sutura->statut !== 'en_cours') {
            return response()->json(['message' => 'Le vote est clôturé'], 422);
        }

        // Vérifier que l'utilisateur est membre de la tontine
        if (!$sutura->tontine->membres()->where('user_id', $user->id)->exists()) {
            return response()->json(['message' => 'Vous n\'êtes pas membre de cette tontine'], 403);
        }

        // Le demandeur ne peut pas voter pour sa propre urgence
        if ($sutura->demandeur_id === $user->id) {
            return response()->json(['message' => 'Vous ne pouvez pas voter pour votre propre demande'], 422);
        }

        // Un seul vote par membre
        if (SuturaVote::where(['sutura_id' => $id, 'user_id' => $user->id])->exists()) {
            return response()->json(['message' => 'Vous avez déjà voté'], 422);
        }

        SuturaVote::create([
            'sutura_id' => $id,
            'user_id'   => $user->id,
            'approuve'  => $request->approuve,
        ]);

        // Vérifier si tous ont voté → calculer résultat
        $sutura->refresh();
        $this->calculerResultat($sutura);

        return response()->json([
            'message' => 'Vote enregistré',
            'data'    => $this->formatSutura($sutura->fresh(), $user->id),
        ]);
    }

    // ─── CALCUL RÉSULTAT ──────────────────────────────────────────────────────
    private function calculerResultat(Sutura $sutura): void
    {
        // Votants éligibles = membres - 1 (le demandeur ne vote pas)
        $eligible = max(1, $sutura->tontine->membres()->count() - 1);
        $needed   = intdiv($eligible, 2) + 1; // majorité stricte

        $votesOui   = SuturaVote::where(['sutura_id' => $sutura->id, 'approuve' => true])->count();
        $votesNon   = SuturaVote::where(['sutura_id' => $sutura->id, 'approuve' => false])->count();
        $totalVotes = $votesOui + $votesNon;

        // On tranche dès qu'une majorité est acquise, sans attendre tous les votes
        if ($votesOui >= $needed) {
            $approuve = true;
        } elseif ($votesNon >= $needed) {
            $approuve = false;
        } elseif ($totalVotes >= $eligible) {
            $approuve = false; // tous ont voté sans majorité « oui » → rejetée
        } else {
            return; // résultat pas encore décidé
        }

        $sutura->update([
            'statut'      => $approuve ? 'approuve' : 'rejete',
            'resultat_at' => now(),
        ]);

        // Notifier le demandeur (anonymat préservé — on notifie via user_id interne)
        $this->notifService->send(
            $sutura->demandeur_id,
            'sutura_resultat',
            $approuve ? '✅ Urgence approuvée' : '❌ Urgence rejetée',
            $approuve
                ? "Votre demande de {$sutura->montant_demande} FCFA a été approuvée par le groupe"
                : "Votre demande de {$sutura->montant_demande} FCFA a été rejetée",
            ['sutura_id' => $sutura->id, 'tontine_id' => $sutura->tontine_id],
        );

        // Notifier l'admin
        $this->notifService->send(
            $sutura->tontine->admin_id,
            'sutura_resultat_admin',
            $approuve ? '🤝 Urgence Sutura approuvée' : '🤝 Urgence Sutura rejetée',
            "La demande d'urgence dans {$sutura->tontine->nom} a été " . ($approuve ? 'approuvée' : 'rejetée'),
            ['sutura_id' => $sutura->id, 'tontine_id' => $sutura->tontine_id],
        );
    }

    // ─── FORMAT SUTURA (SANS EXPOSER L'IDENTITÉ) ─────────────────────────────
    private function formatSutura(Sutura $s, int $currentUserId): array
    {
        $votesOui  = $s->votes()->where('approuve', true)->count();
        $votesNon  = $s->votes()->where('approuve', false)->count();
        $monVote   = $s->votes()->where('user_id', $currentUserId)->first();
        $eligible  = max(1, $s->tontine->membres()->count() - 1);
        $estMien   = $s->demandeur_id === $currentUserId; // visible UNIQUEMENT par le demandeur

        return [
            'id'              => $s->id,
            'tontine_id'      => $s->tontine_id,
            'montant_demande' => $s->montant_demande,
            'motif'           => $s->motif,
            'statut'          => $s->statut,
            'votes_oui'       => $votesOui,
            'votes_non'       => $votesNon,
            'total_votants'   => $votesOui + $votesNon,
            'total_eligibles' => $eligible,
            'mon_vote'        => $monVote ? $monVote->approuve : null,
            'est_mien'        => $estMien,
            'peut_voter'      => $s->statut === 'en_cours' && !$estMien && $monVote === null,
            // JAMAIS exposé : demandeur_id (anonymat). est_mien est calculé par utilisateur.
            'tontine'         => $s->tontine ? ['nom' => $s->tontine->nom] : null,
            'resultat_at'     => $s->resultat_at?->toISOString(),
            'created_at'      => $s->created_at->toISOString(),
        ];
    }

    private function authorizeAccessToTontine($user, int $tontineId): void
    {
        $tontine = Tontine::findOrFail($tontineId);
        $ok = $tontine->admin_id === $user->id
           || $tontine->membres()->where('user_id', $user->id)->exists();
        abort_if(!$ok, 403, 'Accès refusé');
    }
}
