<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class NotificationService
{
    // ─── ENVOYER UNE NOTIFICATION ─────────────────────────────────────────────
    public function send(
        int $userId,
        string $type,
        string $titre,
        string $message,
        array $data = [],
    ): void {
        // 1. Sauvegarder en base
        Notification::create([
            'user_id' => $userId,
            'type'    => $type,
            'titre'   => $titre,
            'message' => $message,
            'data'    => $data,
            'lu'      => false,
        ]);

        // 2. Push notification Firebase si token disponible
        $user = User::find($userId);
        if ($user?->fcm_token) {
            $this->sendFcm($user->fcm_token, $titre, $message, $data);
        }
    }

    // ─── FIREBASE CLOUD MESSAGING ─────────────────────────────────────────────
    private function sendFcm(
        string $fcmToken,
        string $titre,
        string $message,
        array $data = [],
    ): void {
        if (config('app.env') === 'local') {
            Log::info("FCM push: $titre → $message");
            return;
        }

        $serverKey = config('services.firebase.server_key');

        Http::withHeaders([
            'Authorization' => "key=$serverKey",
            'Content-Type'  => 'application/json',
        ])->post('https://fcm.googleapis.com/fcm/send', [
            'to' => $fcmToken,
            'notification' => [
                'title' => $titre,
                'body'  => $message,
                'sound' => 'default',
                'badge' => 1,
            ],
            'data' => array_map('strval', $data),
        ]);
    }

    // ─── ENVOYER À PLUSIEURS UTILISATEURS ────────────────────────────────────
    public function sendToMany(array $userIds, string $type, string $titre, string $message, array $data = []): void
    {
        foreach ($userIds as $userId) {
            $this->send($userId, $type, $titre, $message, $data);
        }
    }
}
