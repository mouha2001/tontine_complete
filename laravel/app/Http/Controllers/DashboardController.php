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
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    // Identifiants des tontines de l'utilisateur : créées (admin_id) + rejointes.
    private function tontineIds($user)
    {
        return Tontine::where('admin_id', $user->id)
            ->orWhereHas('membres', fn($q) => $q->where('user_id', $user->id))
            ->pluck('id');
    }

    public function stats(Request $request): JsonResponse
    {
        $user       = $request->user();
        $tontineIds = $this->tontineIds($user);

        $totalMembres = DB::table('tontine_membres')
            ->whereIn('tontine_id', $tontineIds)
            ->distinct('user_id')
            ->count('user_id');

        $totalCollecte = Cotisation::whereIn('tontine_id', $tontineIds)
            ->where('statut', 'confirme')
            ->sum('montant');

        $tontinesActives = Tontine::whereIn('id', $tontineIds)
            ->where('statut', 'active')
            ->count();

        $urgencesEnCours = Sutura::whereIn('tontine_id', $tontineIds)
            ->where('statut', 'en_cours')
            ->count();

        $activitesRecentes = Cotisation::with(['user', 'tontine'])
            ->whereIn('tontine_id', $tontineIds)
            ->where('statut', 'confirme')
            ->orderByDesc('paye_le')
            ->limit(5)
            ->get()
            ->map(fn($c) => [
                'type'       => 'cotisation',
                'label'      => trim("{$c->user->prenom} {$c->user->nom}") . " a cotisé {$c->montant} FCFA",
                'tontine'    => $c->tontine->nom,
                'created_at' => $c->paye_le?->toISOString() ?? $c->created_at->toISOString(),
            ]);

        // ── Stats personnelles ──
        $totalCotise = Cotisation::where('user_id', $user->id)
            ->where('statut', 'confirme')
            ->sum('montant');

        // ── Rappels de cotisation : tontines actives non payées CE MOIS-CI ──
        // (montant dû = cotisation × parts du membre, aligné sur le tirage mensuel)
        $rappels = [];
        $montantDuMois = 0;

        $tontinesActivesUser = Tontine::whereIn('id', $tontineIds)
            ->where('statut', 'active')
            ->get();

        foreach ($tontinesActivesUser as $t) {
            $parts = (int) (DB::table('tontine_membres')
                ->where('tontine_id', $t->id)
                ->where('user_id', $user->id)
                ->value('nombre_parts') ?? 0);

            if ($parts === 0) continue; // pas membre

            $aPaye = Cotisation::where('tontine_id', $t->id)
                ->where('user_id', $user->id)
                ->where('statut', 'confirme')
                ->whereYear('paye_le', now()->year)
                ->whereMonth('paye_le', now()->month)
                ->exists();

            if (!$aPaye) {
                $montant = (float) $t->montant_cotisation * $parts;
                $rappels[] = [
                    'tontine_id'  => $t->id,
                    'tontine_nom' => $t->nom,
                    'parts'       => $parts,
                    'montant'     => $montant,
                ];
                $montantDuMois += $montant;
            }
        }

        return response()->json([
            'total_tontines'      => $tontineIds->count(),
            'tontines_actives'    => $tontinesActives,
            'total_membres'       => $totalMembres,
            'total_collecte'      => $totalCollecte,
            'urgences_en_cours'   => $urgencesEnCours,
            'total_cotise'        => $totalCotise,
            'montant_du_mois'     => $montantDuMois,
            'rappels_cotisation'  => $rappels,
            'activites_recentes'  => $activitesRecentes,
        ]);
    }

    public function activites(Request $request): JsonResponse
    {
        $user       = $request->user();
        $limit      = min($request->integer('limit', 10), 50);
        $tontineIds = $this->tontineIds($user);

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
                'label'      => trim("{$c->user->prenom} {$c->user->nom}") . " — {$c->montant} FCFA",
                'tontine'    => $c->tontine->nom,
                'methode'    => $c->methode_paiement,
                'created_at' => $c->paye_le?->toISOString() ?? $c->created_at->toISOString(),
            ]);

        return response()->json(['data' => $activites]);
    }
}
