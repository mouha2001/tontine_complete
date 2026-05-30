<?php

namespace App\Http\Controllers;

use App\Models\Tontine;
use App\Models\Tirage;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class TontineController extends Controller
{
    public function __construct(private NotificationService $notifService) {}

    // ─── LISTE MES TONTINES ───────────────────────────────────────────────────
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->isAdmin) {
            // Admin voit les tontines qu'il a créées + celles où il est membre
            $tontines = Tontine::with('admin')
                ->where('admin_id', $user->id)
                ->orWhereHas('membres', fn($q) => $q->where('user_id', $user->id))
                ->orderByDesc('created_at')
                ->get();
        } else {
            // Membre voit uniquement ses tontines
            $tontines = $user->tontinesMembre()
                ->with('admin')
                ->orderByDesc('tontine_membres.created_at')
                ->get();
        }

        return response()->json([
            'data' => $tontines->map(fn($t) => $t->toApiArray())->values(),
        ]);
    }

    // ─── DÉTAIL ───────────────────────────────────────────────────────────────
    public function show(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::with(['admin', 'membres'])->findOrFail($id);
        $this->authorizeAccess($request->user(), $tontine);

        return response()->json([
            'data' => $tontine->toApiArray(withMembers: true),
        ]);
    }

    // ─── CRÉER (admin only) ───────────────────────────────────────────────────
    public function store(Request $request): JsonResponse
    {
        $this->requireAdmin($request);

        $validated = $request->validate([
            'nom'                => 'required|string|max:100',
            'description'        => 'nullable|string|max:500',
            'montant_cotisation' => 'required|numeric|min:500',
            'frequence'          => 'required|in:hebdomadaire,bimensuel,mensuel',
            'nombre_membres'     => 'required|integer|min:2|max:50',
            'date_debut'         => 'nullable|date|after_or_equal:today',
        ]);

        $tontine = Tontine::create([
            ...$validated,
            'admin_id' => $request->user()->id,
            'statut'   => 'en_attente',
        ]);

        // L'admin est automatiquement membre
        $tontine->membres()->attach($request->user()->id);

        return response()->json([
            'message' => 'Tontine créée avec succès',
            'data'    => $tontine->load('admin')->toApiArray(),
        ], 201);
    }

    // ─── MODIFIER (admin only) ────────────────────────────────────────────────
    public function update(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
        $this->requireAdmin($request);
        $this->requireOwner($request->user(), $tontine);

        $validated = $request->validate([
            'nom'                => 'sometimes|string|max:100',
            'description'        => 'nullable|string|max:500',
            'montant_cotisation' => 'sometimes|numeric|min:500',
            'frequence'          => 'sometimes|in:hebdomadaire,bimensuel,mensuel',
            'nombre_membres'     => 'sometimes|integer|min:2|max:50',
            'statut'             => 'sometimes|in:en_attente,active,terminee',
            'date_debut'         => 'nullable|date',
        ]);

        $tontine->update($validated);

        return response()->json([
            'message' => 'Tontine mise à jour',
            'data'    => $tontine->load('admin')->toApiArray(),
        ]);
    }

    // ─── SUPPRIMER (admin only) ───────────────────────────────────────────────
    public function destroy(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
        $this->requireAdmin($request);
        $this->requireOwner($request->user(), $tontine);

        if ($tontine->statut === 'active') {
            return response()->json([
                'message' => 'Impossible de supprimer une tontine active',
            ], 422);
        }

        $tontine->delete();
        return response()->json(['message' => 'Tontine supprimée']);
    }

    // ─── GÉNÉRER LIEN INVITATION ──────────────────────────────────────────────
    public function generateInvite(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
        $this->requireAdmin($request);
        $this->requireOwner($request->user(), $tontine);

        return response()->json([
            'invite_url'  => $tontine->invite_url,
            'invite_code' => $tontine->invite_code,
        ]);
    }

    // ─── MEMBRES ──────────────────────────────────────────────────────────────
    public function membres(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
        $this->authorizeAccess($request->user(), $tontine);

        $membres = $tontine->membres()
            ->withPivot(['ordre_tirage', 'a_recu_fonds', 'created_at'])
            ->get();

        return response()->json([
            'data' => $membres->map->toApiArray()->values(),
        ]);
    }

    // ─── RETIRER UN MEMBRE (admin only) ───────────────────────────────────────
    public function removeMembre(Request $request, int $id, int $userId): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
        $this->requireAdmin($request);
        $this->requireOwner($request->user(), $tontine);

        if ($userId === $tontine->admin_id) {
            return response()->json(['message' => 'Impossible de retirer l\'administrateur'], 422);
        }

        $tontine->membres()->detach($userId);

        return response()->json(['message' => 'Membre retiré de la tontine']);
    }

    // ─── TIRAGE (admin only) ──────────────────────────────────────────────────
    public function lancerTirage(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::with('membres')->findOrFail($id);
        $this->requireAdmin($request);
        $this->requireOwner($request->user(), $tontine);

        if ($tontine->statut !== 'active') {
            return response()->json(['message' => 'La tontine doit être active pour lancer le tirage'], 422);
        }

        // Membres n'ayant pas encore reçu les fonds
        $eligibles = $tontine->membres()
            ->wherePivot('a_recu_fonds', false)
            ->get();

        if ($eligibles->isEmpty()) {
            return response()->json(['message' => 'Tous les membres ont déjà reçu les fonds'], 422);
        }

        // Tirage aléatoire cryptographiquement sûr
        $gagnant = $eligibles->random();

        // Enregistrer le tirage
        $tirage = Tirage::create([
            'tontine_id'      => $tontine->id,
            'gagnant_id'      => $gagnant->id,
            'tour'            => $tontine->tour_actuel + 1,
            'montant_attribue' => $tontine->montant_cotisation * $tontine->membres_actuels,
        ]);

        // Marquer le gagnant
        $tontine->membres()->updateExistingPivot($gagnant->id, ['a_recu_fonds' => true]);
        $tontine->increment('tour_actuel');

        // Vérifier si tous ont reçu → terminer
        if ($tontine->membres()->wherePivot('a_recu_fonds', false)->count() === 0) {
            $tontine->update(['statut' => 'terminee']);
        }

        // Notifier tous les membres
        $tontine->membres->each(function ($membre) use ($gagnant, $tontine, $tirage) {
            $this->notifService->send(
                $membre->id,
                'tirage_resultat',
                '🎰 Résultat du tirage !',
                "{$gagnant->nom} a gagné le tour {$tirage->tour} de la tontine {$tontine->nom}",
                ['tontine_id' => $tontine->id, 'tirage_id' => $tirage->id],
            );
        });

        return response()->json([
            'message'  => 'Tirage effectué avec succès',
            'gagnant'  => $gagnant->toApiArray(),
            'tour'     => $tirage->tour,
            'montant'  => $tirage->montant_attribue,
            'timestamp' => $tirage->created_at->toISOString(),
        ]);
    }

    // ─── HISTORIQUE TIRAGES ───────────────────────────────────────────────────
    public function historiqueTirage(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
        $this->authorizeAccess($request->user(), $tontine);

        $tirages = Tirage::with('gagnant')
            ->where('tontine_id', $id)
            ->orderBy('tour')
            ->get();

        return response()->json([
            'data' => $tirages->map(fn($t) => [
                'id'              => $t->id,
                'tour'            => $t->tour,
                'montant_attribue' => $t->montant_attribue,
                'gagnant'         => $t->gagnant->toApiArray(),
                'created_at'      => $t->created_at->toISOString(),
            ])->values(),
        ]);
    }

    // ─── GUARDS ───────────────────────────────────────────────────────────────
    private function requireAdmin(Request $request): void
    {
        abort_if(!$request->user()->isAdmin, 403, 'Accès réservé aux administrateurs');
    }

    private function requireOwner($user, Tontine $tontine): void
    {
        abort_if($tontine->admin_id !== $user->id, 403, 'Vous n\'êtes pas propriétaire de cette tontine');
    }

    private function authorizeAccess($user, Tontine $tontine): void
    {
        $isMember = $tontine->membres()->where('user_id', $user->id)->exists();
        $isAdmin  = $tontine->admin_id === $user->id;
        abort_if(!$isMember && !$isAdmin, 403, 'Accès refusé à cette tontine');
    }
}
