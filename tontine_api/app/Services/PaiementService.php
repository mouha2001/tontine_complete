<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Request;

class PaiementService
{
    // ─── INITIER UN PAIEMENT ──────────────────────────────────────────────────
    public function initier(
        string $methode,
        float $montant,
        string $reference,
        string $telephone,
        string $description,
        string $callbackUrl,
    ): array {
        return match ($methode) {
            'wave'         => $this->initierWave($montant, $reference, $telephone, $description, $callbackUrl),
            'orange_money' => $this->initierOrangeMoney($montant, $reference, $telephone, $description, $callbackUrl),
            default        => throw new \InvalidArgumentException("Méthode de paiement inconnue : $methode"),
        };
    }

    // ─── WAVE ─────────────────────────────────────────────────────────────────
    private function initierWave(
        float $montant,
        string $reference,
        string $telephone,
        string $description,
        string $callbackUrl,
    ): array {
        if (config('app.env') === 'local') {
            return [
                'payment_url' => "https://pay.wave.com/m/demo?ref=$reference",
                'expires_at'  => now()->addMinutes(15)->toISOString(),
            ];
        }

        $response = Http::withToken(config('services.wave.api_key'))
            ->post('https://api.wave.com/v1/checkout/sessions', [
                'amount'           => (int) $montant,
                'currency'         => 'XOF',
                'client_reference' => $reference,
                'success_url'      => config('app.frontend_url') . '/paiement/succes?ref=' . $reference,
                'error_url'        => config('app.frontend_url') . '/paiement/erreur?ref=' . $reference,
                'webhook_url'      => $callbackUrl,
            ]);

        if ($response->failed()) {
            Log::error('Wave API error', $response->json());
            throw new \RuntimeException('Erreur Wave : ' . ($response->json()['message'] ?? 'Inconnue'));
        }

        return [
            'payment_url' => $response->json('wave_launch_url'),
            'expires_at'  => $response->json('when_expires'),
        ];
    }

    // ─── ORANGE MONEY ─────────────────────────────────────────────────────────
    private function initierOrangeMoney(
        float $montant,
        string $reference,
        string $telephone,
        string $description,
        string $callbackUrl,
    ): array {
        if (config('app.env') === 'local') {
            return [
                'payment_url' => "https://api.orange.com/orange-money-webpay/sn/v1/demo?ref=$reference",
                'expires_at'  => now()->addMinutes(15)->toISOString(),
            ];
        }

        // Step 1 : Obtenir token d'accès
        $tokenResponse = Http::withBasicAuth(
            config('services.orange_money.client_id'),
            config('services.orange_money.client_secret'),
        )->asForm()->post('https://api.orange.com/oauth/v3/token', [
            'grant_type' => 'client_credentials',
        ]);

        $accessToken = $tokenResponse->json('access_token');

        // Step 2 : Initier paiement
        $response = Http::withToken($accessToken)
            ->post('https://api.orange.com/orange-money-webpay/sn/v1/webpayment', [
                'merchant_key'   => config('services.orange_money.merchant_key'),
                'currency'       => 'OUV',
                'order_id'       => $reference,
                'amount'         => (int) $montant,
                'return_url'     => config('app.frontend_url') . '/paiement/succes?ref=' . $reference,
                'cancel_url'     => config('app.frontend_url') . '/paiement/erreur?ref=' . $reference,
                'notif_url'      => $callbackUrl,
                'lang'           => 'fr',
                'reference'      => $description,
            ]);

        return [
            'payment_url' => $response->json('payment_url'),
            'expires_at'  => now()->addMinutes(15)->toISOString(),
        ];
    }

    // ─── VÉRIFIER STATUT ─────────────────────────────────────────────────────
    public function verifier(string $methode, string $reference): string
    {
        if (config('app.env') === 'local') {
            return 'confirme'; // Auto-confirmer en dev
        }

        return match ($methode) {
            'wave'         => $this->verifierWave($reference),
            'orange_money' => $this->verifierOrangeMoney($reference),
            default        => 'en_attente',
        };
    }

    private function verifierWave(string $reference): string
    {
        $response = Http::withToken(config('services.wave.api_key'))
            ->get("https://api.wave.com/v1/checkout/sessions?client_reference=$reference");

        $status = $response->json('status');
        return match ($status) {
            'complete' => 'confirme',
            'failed'   => 'echoue',
            default    => 'en_attente',
        };
    }

    private function verifierOrangeMoney(string $reference): string
    {
        // Orange Money ne dispose pas d'endpoint de vérification direct
        // Le statut arrive via webhook
        return 'en_attente';
    }

    // ─── VÉRIFIER SIGNATURE WEBHOOK ──────────────────────────────────────────
    public function verifyWebhookSignature(Request $request): bool
    {
        if (config('app.env') === 'local') {
            return true;
        }

        $signature = $request->header('X-Wave-Signature')
                  ?? $request->header('X-Orange-Signature');

        if (!$signature) return false;

        $secret  = config('services.wave.webhook_secret');
        $payload = $request->getContent();
        $expected = 'sha256=' . hash_hmac('sha256', $payload, $secret);

        return hash_equals($expected, $signature);
    }
}
