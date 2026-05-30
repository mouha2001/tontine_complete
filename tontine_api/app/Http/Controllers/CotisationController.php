<?php

namespace App\Http\Controllers;

use App\Models\Cotisation;
use App\Models\Tontine;
use App\Services\NotificationService;
use App\Services\PaiementService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

class CotisationController extends Controller
{
    public function __construct(
        private PaiementService $paiementService,
        private NotificationService $notifService,
    ) {}

    // ─── LISTE DES COTISATIONS ────────────────────────────────────────────────
    public function index(Request $request): JsonResponse
    {
        $user  = $request->user();
        $query = Cotisation::with(['user', 'tontine']);

        if ($request->filled('tontine_id')) {
            $tontineId = $request->integer('tontine_id');
            $tontine   = Tontine::findOrFail($tontineId);

            // Admin peut voir toutes les cotisations de sa tontine
            if ($user->isAdmin && $tontine->admin_id === $user->id) {
                $query->where('tontine_id', $tontineId);
            } else {
                // Membre : uniquement les siennes
                $query->where('tontine_id', $tontineId)
                      ->where('user_id', $user->id);
            }
        } else {
            if (!$user->isAdmin) {
                $query->where('user_id', $user->id);
            }
        }

        $cotisations = $query->orderByDesc('created_at')->get();

        return response()->json([
            'data' => $cotisations->map(fn($c) => $this->formatCotisation($c))->values(),
        ]);
    }

    // ─── INITIER UN PAIEMENT ──────────────────────────────────────────────────
    public function initierPaiement(Request $request): JsonResponse
    {
        $request->validate([
            'tontine_id'       => 'required|integer|exists:tontines,id',
            'montant'          => 'required|numeric|min:1',
            'methode_paiement' => 'required|in:wave,orange_money',
        ]);

        $user    = $request->user();
        $tontine = Tontine::findOrFail($request->tontine_id);

        // Vérifier que l'utilisateur est membre
        if (!$tontine->membres()->where('user_id', $user->id)->exists()) {
            return response()->json(['message' => 'Vous n\'êtes pas membre de cette tontine'], 403);
        }

        $reference = 'TON-' . strtoupper(Str::random(12));

        // Créer la cotisation en attente
        $cotisation = Cotisation::create([
            'tontine_id'       => $tontine->id,
            'user_id'          => $user->id,
            'montant'          => $request->montant,
            'statut'           => 'en_attente',
            'methode_paiement' => $request->methode_paiement,
            'reference'        => $reference,
        ]);

        // Appeler l'API de paiement
        $result = $this->paiementService->initier(
            methode: $request->methode_paiement,
            montant: $request->montant,
            reference: $reference,
            telephone: $user->telephone,
            description: "Cotisation tontine {$tontine->nom}",
            callbackUrl: config('app.url') . '/api/cotisations/webhook',
        );

        return response()->json([
            'reference'   => $reference,
            'payment_url' => $result['payment_url'],
            'expires_at'  => $result['expires_at'] ?? now()->addMinutes(15)->toISOString(),
        ]);
    }

    // ─── VÉRIFIER STATUT PAIEMENT ─────────────────────────────────────────────
    public function verifierPaiement(Request $request): JsonResponse
    {
        $request->validate(['reference' => 'required|string']);

        $cotisation = Cotisation::with(['user', 'tontine'])
            ->where('reference', $request->reference)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        // Vérifier avec l'API externe si toujours en attente
        if ($cotisation->statut === 'en_attente') {
            $status = $this->paiementService->verifier(
                $cotisation->methode_paiement,
                $cotisation->reference,
            );

            if ($status === 'confirme') {
                $cotisation->update([
                    'statut'  => 'confirme',
                    'paye_le' => now(),
                ]);
                $this->onPaiementConfirme($cotisation);
            } elseif ($status === 'echoue') {
                $cotisation->update(['statut' => 'echoue']);
            }
        }

        return response()->json([
            'data' => $this->formatCotisation($cotisation),
        ]);
    }

    // ─── WEBHOOK (appelé par Wave / Orange Money) ─────────────────────────────
    public function webhook(Request $request): JsonResponse
    {
        // Vérifier la signature webhook
        if (!$this->paiementService->verifyWebhookSignature($request)) {
            return response()->json(['error' => 'Signature invalide'], 401);
        }

        $reference = $request->input('reference') ?? $request->input('client_reference');
        $statut    = $request->input('status');

        $cotisation = Cotisation::with(['user', 'tontine'])
            ->where('reference', $reference)
            ->first();

        if (!$cotisation) {
            return response()->json(['error' => 'Cotisation non trouvée'], 404);
        }

        if ($statut === 'SUCCESS' && $cotisation->statut !== 'confirme') {
            $cotisation->update([
                'statut'       => 'confirme',
                'paye_le'      => now(),
                'webhook_data' => $request->all(),
            ]);
            $this->onPaiementConfirme($cotisation);
        } elseif (in_array($statut, ['FAILED', 'CANCELLED', 'EXPIRED'])) {
            $cotisation->update(['statut' => 'echoue', 'webhook_data' => $request->all()]);
        }

        return response()->json(['status' => 'ok']);
    }

    // ─── ON PAIEMENT CONFIRMÉ ─────────────────────────────────────────────────
    private function onPaiementConfirme(Cotisation $cotisation): void
    {
        $tontine = $cotisation->tontine;

        // Notifier le membre
        $this->notifService->send(
            $cotisation->user_id,
            'cotisation_confirmee',
            '✅ Cotisation confirmée',
            "Votre paiement de {$cotisation->montant} FCFA pour {$tontine->nom} a été confirmé",
            ['tontine_id' => $tontine->id, 'cotisation_id' => $cotisation->id],
        );

        // Notifier l'admin
        $this->notifService->send(
            $tontine->admin_id,
            'cotisation_recu',
            '💳 Cotisation reçue',
            "{$cotisation->user->nom} a cotisé {$cotisation->montant} FCFA pour {$tontine->nom}",
            ['tontine_id' => $tontine->id, 'cotisation_id' => $cotisation->id],
        );
    }

    private function formatCotisation(Cotisation $c): array
    {
        return [
            'id'               => $c->id,
            'user_id'          => $c->user_id,
            'tontine_id'       => $c->tontine_id,
            'montant'          => $c->montant,
            'statut'           => $c->statut,
            'methode_paiement' => $c->methode_paiement,
            'reference'        => $c->reference,
            'receipt_url'      => $c->receipt_url,
            'paye_le'          => $c->paye_le?->toISOString(),
            'created_at'       => $c->created_at->toISOString(),
            'user'             => $c->user ? ['nom' => $c->user->nom] : null,
            'tontine'          => $c->tontine ? ['nom' => $c->tontine->nom] : null,
        ];
    }
}
