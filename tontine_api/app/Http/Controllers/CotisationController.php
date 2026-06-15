<?php

namespace App\Http\Controllers;

use App\Models\Cotisation;
use App\Models\Tontine;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class CotisationController extends Controller
{
    public function __construct(private NotificationService $notifService) {}

    // ─── LISTE DES COTISATIONS ────────────────────────────────────────────────
    public function index(Request $request): JsonResponse
    {
        $user  = $request->user();
        $query = Cotisation::with(['user', 'tontine']);

        if ($request->filled('tontine_id')) {
            $tontineId = $request->integer('tontine_id');
            $tontine   = Tontine::findOrFail($tontineId);

            // L'admin (propriétaire) voit toutes les cotisations de SA tontine ;
            // un membre ne voit que les siennes.
            if ($tontine->admin_id === $user->id) {
                $query->where('tontine_id', $tontineId);
            } else {
                $query->where('tontine_id', $tontineId)->where('user_id', $user->id);
            }
        } else {
            $query->where('user_id', $user->id);
        }

        $cotisations = $query->orderByDesc('created_at')->get();

        return response()->json([
            'data' => $cotisations->map(fn($c) => $this->formatCotisation($c))->values(),
        ]);
    }

    // ─── ENREGISTRER UNE COTISATION ───────────────────────────────────────────
    // Le paiement se fait HORS de l'app (Wave/OM/Free/espèces). Le membre déclare
    // sa cotisation ; elle reste "en_attente" jusqu'à validation par l'admin.
    public function initierPaiement(Request $request): JsonResponse
    {
        $request->validate([
            'tontine_id'       => 'required|integer|exists:tontines,id',
            'methode_paiement' => 'required|in:wave,orange_money,free_money,cash',
            'reference'        => 'nullable|string|max:100',
            'periode'          => 'nullable|date',
        ]);

        $user    = $request->user();
        $tontine = Tontine::findOrFail($request->tontine_id);

        // Membre + ses parts (montant calculé côté serveur, jamais depuis le client)
        $parts = $tontine->membres()->where('user_id', $user->id)->value('tontine_membres.nombre_parts');
        if ($parts === null) {
            return response()->json(['message' => 'Vous n\'êtes pas membre de cette tontine'], 403);
        }

        $montant = $tontine->montant_cotisation * (int) $parts;

        // Mois ciblé : mois courant par défaut, ou un mois FUTUR (cotisation à l'avance).
        // On interdit un mois passé.
        $periode = $request->filled('periode')
            ? Carbon::parse($request->periode)->startOfMonth()
            : now()->startOfMonth();
        if ($periode->lt(now()->startOfMonth())) {
            return response()->json([
                'message' => 'On ne peut cotiser que pour le mois en cours ou à l\'avance',
            ], 422);
        }

        $moisLabel = $periode->locale('fr')->translatedFormat('F Y');

        // Anti-doublon PAR MOIS : pas deux cotisations actives pour le même mois
        // (mais on peut payer plusieurs mois différents à l'avance).
        if (Cotisation::where('tontine_id', $tontine->id)
                ->where('user_id', $user->id)
                ->whereDate('periode', $periode->toDateString())
                ->whereIn('statut', ['en_attente', 'confirme'])->exists()) {
            return response()->json([
                'message' => "Vous avez déjà une cotisation pour {$moisLabel}",
            ], 422);
        }

        $cotisation = Cotisation::create([
            'tontine_id'       => $tontine->id,
            'user_id'          => $user->id,
            'montant'          => $montant,
            'statut'           => 'en_attente',
            'periode'          => $periode,
            'methode_paiement' => $request->methode_paiement,
            'reference'        => $request->reference ?: 'COT-' . strtoupper(Str::random(10)),
        ]);

        // Notifier l'admin pour validation
        $this->notifService->send(
            $tontine->admin_id,
            'cotisation_a_valider',
            '💳 Cotisation à valider',
            trim("{$user->prenom} {$user->nom}") . " a déclaré une cotisation de {$montant} FCFA pour {$moisLabel} ({$tontine->nom})",
            ['tontine_id' => $tontine->id, 'cotisation_id' => $cotisation->id],
        );

        return response()->json([
            'message' => 'Cotisation enregistrée, en attente de validation',
            'data'    => $this->formatCotisation($cotisation->load(['user', 'tontine'])),
        ], 201);
    }

    // ─── CONFIRMER UNE COTISATION (admin de la tontine) ───────────────────────
    public function confirmer(Request $request, int $id): JsonResponse
    {
        $cotisation = Cotisation::with(['user', 'tontine'])->findOrFail($id);
        $this->requireOwner($request->user(), $cotisation->tontine);

        if ($cotisation->statut !== 'en_attente') {
            return response()->json(['message' => 'Seule une cotisation en attente peut être confirmée'], 422);
        }

        $cotisation->update([
            'statut'       => 'confirme',
            'paye_le'      => now(),
            'confirme_par' => $request->user()->id,
        ]);

        $this->notifService->send(
            $cotisation->user_id,
            'cotisation_confirmee',
            '✅ Cotisation confirmée',
            "Votre cotisation de {$cotisation->montant} FCFA pour {$cotisation->tontine->nom} a été confirmée",
            ['tontine_id' => $cotisation->tontine_id, 'cotisation_id' => $cotisation->id],
        );

        return response()->json([
            'message' => 'Cotisation confirmée',
            'data'    => $this->formatCotisation($cotisation),
        ]);
    }

    // ─── REJETER UNE COTISATION (admin de la tontine) ─────────────────────────
    public function rejeter(Request $request, int $id): JsonResponse
    {
        $cotisation = Cotisation::with(['user', 'tontine'])->findOrFail($id);
        $this->requireOwner($request->user(), $cotisation->tontine);

        if ($cotisation->statut !== 'en_attente') {
            return response()->json(['message' => 'Seule une cotisation en attente peut être rejetée'], 422);
        }

        $cotisation->update(['statut' => 'echoue']);

        $this->notifService->send(
            $cotisation->user_id,
            'cotisation_rejetee',
            '❌ Cotisation rejetée',
            "Votre cotisation de {$cotisation->montant} FCFA pour {$cotisation->tontine->nom} a été rejetée",
            ['tontine_id' => $cotisation->tontine_id, 'cotisation_id' => $cotisation->id],
        );

        return response()->json([
            'message' => 'Cotisation rejetée',
            'data'    => $this->formatCotisation($cotisation),
        ]);
    }

    // ─── GUARD ────────────────────────────────────────────────────────────────
    private function requireOwner($user, Tontine $tontine): void
    {
        abort_if($tontine->admin_id !== $user->id, 403, 'Action réservée à l\'administrateur de la tontine');
    }

    private function formatCotisation(Cotisation $c): array
    {
        return [
            'id'               => $c->id,
            'user_id'          => $c->user_id,
            'tontine_id'       => $c->tontine_id,
            'montant'          => $c->montant,
            'statut'           => $c->statut,
            'periode'          => $c->periode?->toDateString(),
            'methode_paiement' => $c->methode_paiement,
            'reference'        => $c->reference,
            'paye_le'          => $c->paye_le?->toISOString(),
            'created_at'       => $c->created_at->toISOString(),
            'user'             => $c->user ? ['nom' => $c->user->nom, 'prenom' => $c->user->prenom] : null,
            'tontine'          => $c->tontine ? ['nom' => $c->tontine->nom] : null,
        ];
    }
}
