<?php
// ═══════════════════════════════════════════════════════════════════════════════
// DashboardController
// ═══════════════════════════════════════════════════════════════════════════════
namespace App\Http\Controllers;

use App\Models\Cotisation;
use App\Models\Sutura;
use App\Models\Tontine;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function stats(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->isAdmin) {
            return $this->adminStats($user);
        }
        return $this->membreStats($user);
    }

    private function adminStats($user): JsonResponse
    {
        $tontineIds = $user->tontinesAdmin()->pluck('id');

        $totalMembres   = \DB::table('tontine_membres')
                            ->whereIn('tontine_id', $tontineIds)
                            ->distinct('user_id')
                            ->count('user_id');

        $totalCollecte  = Cotisation::whereIn('tontine_id', $tontineIds)
                            ->where('statut', 'confirme')
                            ->sum('montant');

        $tontinesActives = Tontine::where('admin_id', $user->id)
                            ->where('statut', 'active')
                            ->count();

        $urgencesEnCours = Sutura::whereIn('tontine_id', $tontineIds)
                            ->where('statut', 'en_cours')
                            ->count();

        $cotisationsRecentes = Cotisation::with(['user', 'tontine'])
                            ->whereIn('tontine_id', $tontineIds)
                            ->where('statut', 'confirme')
                            ->orderByDesc('paye_le')
                            ->limit(5)
                            ->get()
                            ->map(fn($c) => [
                                'type'       => 'cotisation',
                                'label'      => "{$c->user->nom} a cotisé {$c->montant} FCFA",
                                'tontine'    => $c->tontine->nom,
                                'created_at' => $c->paye_le?->toISOString() ?? $c->created_at->toISOString(),
                            ]);

        return response()->json([
            'total_tontines'    => $user->tontinesAdmin()->count(),
            'tontines_actives'  => $tontinesActives,
            'total_membres'     => $totalMembres,
            'total_collecte'    => $totalCollecte,
            'urgences_en_cours' => $urgencesEnCours,
            'activites_recentes' => $cotisationsRecentes,
        ]);
    }

    private function membreStats($user): JsonResponse
    {
        $tontineIds = $user->tontinesMembre()->pluck('tontines.id');

        $totalCotise = Cotisation::where('user_id', $user->id)
                        ->where('statut', 'confirme')
                        ->sum('montant');

        $cotisationsEnAttente = Cotisation::where('user_id', $user->id)
                        ->where('statut', 'en_attente')
                        ->count();

        $votesEnCours = Sutura::whereIn('tontine_id', $tontineIds)
                        ->where('statut', 'en_cours')
                        ->where('demandeur_id', '!=', $user->id)
                        ->whereDoesntHave('votes', fn($q) => $q->where('user_id', $user->id))
                        ->count();

        return response()->json([
            'nb_tontines'              => $tontineIds->count(),
            'total_cotise'             => $totalCotise,
            'cotisations_en_attente'   => $cotisationsEnAttente,
            'votes_en_attente'         => $votesEnCours,
        ]);
    }

    public function activites(Request $request): JsonResponse
    {
        $user  = $request->user();
        $limit = min($request->integer('limit', 10), 50);

        $tontineIds = $user->isAdmin
            ? $user->tontinesAdmin()->pluck('id')
            : $user->tontinesMembre()->pluck('tontines.id');

        $activites = Cotisation::with(['user', 'tontine'])
            ->whereIn('tontine_id', $tontineIds)
            ->where('statut', 'confirme')
            ->orderByDesc('paye_le')
            ->limit($limit)
            ->get()
            ->map(fn($c) => [
                'id'         => $c->id,
                'type'       => 'cotisation',
                'emoji'      => '💳',
                'label'      => "{$c->user->nom} — {$c->montant} FCFA",
                'tontine'    => $c->tontine->nom,
                'methode'    => $c->methode_paiement,
                'created_at' => $c->paye_le?->toISOString() ?? $c->created_at->toISOString(),
            ]);

        return response()->json(['data' => $activites]);
    }
}
