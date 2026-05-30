<?php
// ═══════════════════════════════════════════════════════════════════════════════
// OtpService — Envoi SMS via opérateurs sénégalais
// ═══════════════════════════════════════════════════════════════════════════════
namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class OtpService
{
    public function send(string $telephone, string $otp): void
    {
        $message = "Votre code OTP Tontine est : $otp. Valable 10 minutes. Ne le partagez pas.";

        // ─── MODE DÉVELOPPEMENT ───────────────────────────────────────────────
        if (config('app.env') === 'local') {
            Log::info("OTP pour $telephone : $otp");
            return;
        }

        // ─── ENVOI VIA TWILIO (recommandé pour le Sénégal) ───────────────────
        // Remplacer par votre fournisseur SMS préféré
        $this->sendViaTwilio($telephone, $message);
    }

    private function sendViaTwilio(string $telephone, string $message): void
    {
        $sid   = config('services.twilio.sid');
        $token = config('services.twilio.token');
        $from  = config('services.twilio.from');

        // Normaliser le numéro au format international
        $to = '+221' . ltrim($telephone, '0');

        Http::withBasicAuth($sid, $token)
            ->post("https://api.twilio.com/2010-04-01/Accounts/$sid/Messages.json", [
                'From' => $from,
                'To'   => $to,
                'Body' => $message,
            ]);
    }
}
