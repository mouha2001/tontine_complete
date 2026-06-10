<?php
// ═══════════════════════════════════════════════════════════════════════════════
// OtpService — Envoi SMS via DExchange SMS (opérateur sénégalais)
// ═══════════════════════════════════════════════════════════════════════════════
namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class OtpService
{
    public function send(string $telephone, string $otp): void
    {
        $message = "Votre code OTP Tontine est : $otp. Valable 10 minutes. Ne le partagez pas.";

        // ─── FALLBACK SANS CLÉ ────────────────────────────────────────────────
        // Le mode log dépend UNIQUEMENT de l'absence de clé DExchange (jamais de
        // app.env, pour éviter qu'un APP_ENV mal réglé fasse fuiter les OTP en prod).
        if (blank(config('services.dexchange.key'))) {
            if (config('app.debug')) {
                // Dev : on logge l'OTP pour pouvoir tester sans SMS
                Log::info("OTP pour $telephone : $otp");
                return;
            }
            // Prod sans clé = mauvaise configuration → on échoue clairement,
            // sans jamais écrire l'OTP en clair dans les logs.
            Log::error('OTP non envoyé : clé DExchange SMS absente en production');
            throw new \RuntimeException('Service SMS non configuré');
        }

        $this->sendViaDExchange($telephone, $message);
    }

    // ─── ENVOI RÉEL VIA DEXCHANGE SMS ─────────────────────────────────────────
    private function sendViaDExchange(string $telephone, string $message): void
    {
        // Le numéro est stocké au format local (ex 771234567, sans indicatif).
        // DExchange exige l'international SANS '+' : 221771234567.
        $to = '221' . ltrim($telephone, '0');

        try {
            $response = Http::withToken(config('services.dexchange.key'))
                ->acceptJson()
                ->asJson()
                ->retry(2, 500, throw: false)
                ->post(rtrim(config('services.dexchange.url'), '/') . '/send/sms', [
                    'signature' => config('services.dexchange.signature'),
                    'content'   => $message,
                    'number'    => [$to],
                ]);

            if ($response->failed()) {
                // On NE logge JAMAIS l'OTP en clair ici (uniquement l'erreur fournisseur)
                Log::error('DExchange SMS échec', [
                    'status' => $response->status(),
                    'body'   => $response->json() ?? $response->body(),
                    'number' => $to,
                ]);
                throw new \RuntimeException('Échec de l\'envoi du SMS');
            }
        } catch (\Throwable $e) {
            Log::error('DExchange SMS exception : ' . $e->getMessage(), ['number' => $to]);
            throw new \RuntimeException('Échec de l\'envoi du SMS');
        }
    }
}
