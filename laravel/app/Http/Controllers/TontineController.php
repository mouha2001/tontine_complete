<?php

namespace App\Http\Controllers;

use App\Models\Tontine;
use App\Models\Tirage;
use App\Services\NotificationService;
use App\Services\TontineMembershipService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class TontineController extends Controller
{
    public function __construct(private NotificationService $notifService) {}

    // ─── LISTE MES TONTINES ───────────────────────────────────────────────────
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        // Rôle par tontine : chacun voit les tontines qu'il a créées (admin_id)
        // ET celles qu'il a rejointes comme membre.
        $tontines = Tontine::with('admin')
            ->where('admin_id', $user->id)
            ->orWhereHas('membres', fn($q) => $q->where('user_id', $user->id))
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'data' => $tontines->map(fn($t) => $t->toApiArray(currentUserId: $user->id))->values(),
        ]);
    }

    // ─── DÉTAIL ───────────────────────────────────────────────────────────────
    public function show(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::with(['admin', 'membres'])->findOrFail($id);
        $this->authorizeAccess($request->user(), $tontine);

        return response()->json([
            'data' => $tontine->toApiArray(withMembers: true, currentUserId: $request->user()->id),
        ]);
    }

    // ─── CRÉER (tout utilisateur connecté → devient admin de SA tontine) ───────
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'nom'                => 'required|string|max:100',
            'description'        => 'nullable|string|max:500',
            'montant_cotisation' => 'required|numeric|min:500',
            'frequence'          => 'required|in:quotidien,hebdomadaire,bimensuel,mensuel,bimestriel',
            'nombre_membres'     => 'required|integer|min:2|max:50', // = nombre total de parts/tours
            'nombre_parts'       => 'nullable|integer|min:1|max:3',  // parts prises par le créateur
            'date_debut'         => 'nullable|date|after_or_equal:today',
        ]);

        $partsAdmin = $validated['nombre_parts'] ?? 1;
        unset($validated['nombre_parts']);

        // Le créateur ne peut pas prendre plus de parts que la capacité de la tontine
        if ($partsAdmin > $validated['nombre_membres']) {
            return response()->json([
                'message' => 'Le nombre de parts dépasse la capacité de la tontine',
            ], 422);
        }

        $tontine = Tontine::create([
            ...$validated,
            'admin_id' => $request->user()->id,
            'statut'   => 'en_attente',
        ]);

        // Le créateur est automatiquement membre (et admin via admin_id), avec ses parts
        $tontine->membres()->attach($request->user()->id, ['nombre_parts' => $partsAdmin]);

        return response()->json([
            'message' => 'Tontine créée avec succès',
            'data'    => $tontine->load('admin')->toApiArray(currentUserId: $request->user()->id),
        ], 201);
    }

    // ─── REJOINDRE VIA CODE (membre simple) ───────────────────────────────────
    public function join(Request $request, TontineMembershipService $membership): JsonResponse
    {
        $validated = $request->validate([
            'invite_code'  => 'required|string',
            'nombre_parts' => 'nullable|integer|min:1|max:3',
        ]);

        $tontine = Tontine::where('invite_code', $validated['invite_code'])->first();
        if (!$tontine) {
            return response()->json(['message' => 'Code d\'invitation invalide'], 404);
        }

        $result = $membership->join($tontine, $request->user(), $validated['nombre_parts'] ?? 1);
        if (!$result['ok']) {
            return response()->json(['message' => $result['message']], $result['status']);
        }

        return response()->json([
            'message' => $result['message'],
            'data'    => $tontine->load('admin')->toApiArray(currentUserId: $request->user()->id),
        ]);
    }

    // ─── MODIFIER (admin only) ────────────────────────────────────────────────
    public function update(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
        $this->requireOwner($request->user(), $tontine);

        $validated = $request->validate([
            'nom'                => 'sometimes|string|max:100',
            'description'        => 'nullable|string|max:500',
            'montant_cotisation' => 'sometimes|numeric|min:500',
            'frequence'          => 'sometimes|in:quotidien,hebdomadaire,bimensuel,mensuel,bimestriel',
            'nombre_membres'     => 'sometimes|integer|min:2|max:50',
            'statut'             => 'sometimes|in:en_attente,active,terminee',
            'date_debut'         => 'nullable|date',
        ]);

        $tontine->update($validated);

        return response()->json([
            'message' => 'Tontine mise à jour',
            'data'    => $tontine->load('admin')->toApiArray(currentUserId: $request->user()->id),
        ]);
    }

    // ─── SUPPRIMER (admin only) ───────────────────────────────────────────────
    public function destroy(Request $request, int $id): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
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
            ->withPivot(['ordre_tirage', 'nombre_parts', 'parts_recues', 'created_at'])
            ->get();

        return response()->json([
            'data' => $membres->map(fn($m) => [
                ...$m->toApiArray(),
                'est_admin'    => $m->id === $tontine->admin_id,
                'ordre_tirage' => $m->pivot->ordre_tirage,
                'nombre_parts' => (int) $m->pivot->nombre_parts,
                'parts_recues' => (int) $m->pivot->parts_recues,
            ])->values(),
        ]);
    }

    // ─── RETIRER UN MEMBRE (admin only) ───────────────────────────────────────
    public function removeMembre(Request $request, int $id, int $userId): JsonResponse
    {
        $tontine = Tontine::findOrFail($id);
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
        $this->requireOwner($request->user(), $tontine);

        if ($tontine->statut !== 'active') {
            return response()->json(['message' => 'La tontine doit être active pour lancer le tirage'], 422);
        }

        // Tirage mensuel : un seul tirage par mois calendaire
        $dejaCeMois = Tirage::where('tontine_id', $tontine->id)
            ->whereYear('created_at', now()->year)
            ->whereMonth('created_at', now()->month)
            ->exists();
        if ($dejaCeMois) {
            return response()->json(['message' => 'Un tirage a déjà été effectué ce mois-ci'], 422);
        }

        // Parts n'ayant pas encore reçu les fonds (un membre à N parts reste
        // éligible tant qu'il n'a pas reçu N fois)
        $eligibles = $tontine->membres()
            ->whereColumn('tontine_membres.parts_recues', '<', 'tontine_membres.nombre_parts')
            ->get();

        if ($eligibles->isEmpty()) {
            return response()->json(['message' => 'Toutes les parts ont déjà reçu les fonds'], 422);
        }

        // Tirage aléatoire parmi les parts restantes
        $gagnant = $eligibles->random();

        // Le pot d'un tour = cotisation × total des parts de la tontine
        $tirage = Tirage::create([
            'tontine_id'      => $tontine->id,
            'gagnant_id'      => $gagnant->id,
            'tour'            => $tontine->tour_actuel + 1,
            'montant_attribue' => $tontine->montant_cotisation * $tontine->parts_actuelles,
        ]);

        // Incrémenter le nombre de parts reçues par le gagnant
        $tontine->membres()->updateExistingPivot($gagnant->id, [
            'parts_recues' => $gagnant->pivot->parts_recues + 1,
        ]);
        $tontine->increment('tour_actuel');

        // Toutes les parts servies → terminer
        $reste = $tontine->membres()
            ->whereColumn('tontine_membres.parts_recues', '<', 'tontine_membres.nombre_parts')
            ->count();
        if ($reste === 0) {
            $tontine->update(['statut' => 'terminee']);
        }

        // Notifier tous les membres
        $nomGagnant = trim("{$gagnant->prenom} {$gagnant->nom}");
        $tontine->membres->each(function ($membre) use ($nomGagnant, $tontine, $tirage) {
            $this->notifService->send(
                $membre->id,
                'tirage_resultat',
                '🎰 Résultat du tirage !',
                "{$nomGagnant} a gagné le tour {$tirage->tour} de la tontine {$tontine->nom}",
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
