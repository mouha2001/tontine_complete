<?php

namespace App\Services;

use App\Models\Tontine;
use App\Models\User;

class TontineMembershipService
{
    public function __construct(private NotificationService $notif) {}

    /**
     * Tente d'ajouter $user à $tontine comme membre simple, avec $parts parts (1 à 3).
     * Vérifie le doublon et la capacité (comptée en parts), attache puis notifie l'admin.
     *
     * @return array{ok: bool, status: int, message: string}
     */
    public function join(Tontine $tontine, User $user, int $parts = 1): array
    {
        $parts = max(1, min(3, $parts));

        if ($tontine->membres()->where('user_id', $user->id)->exists()) {
            return ['ok' => false, 'status' => 422, 'message' => 'Vous êtes déjà membre de cette tontine'];
        }

        // Capacité comptée en parts : somme(parts) ne doit pas dépasser le total de parts
        if ($tontine->parts_actuelles + $parts > $tontine->nombre_membres) {
            $restantes = $tontine->places_restantes;
            return ['ok' => false, 'status' => 422, 'message' => $restantes > 0
                ? "Il ne reste que {$restantes} part(s) disponible(s) dans cette tontine"
                : 'La tontine est complète'];
        }

        $tontine->membres()->attach($user->id, ['nombre_parts' => $parts]);

        $nom   = trim("{$user->prenom} {$user->nom}");
        $suffix = $parts > 1 ? " ({$parts} parts)" : '';
        $this->notif->send(
            $tontine->admin_id,
            'nouveau_membre',
            'Nouveau membre',
            "{$nom} a rejoint la tontine {$tontine->nom}{$suffix}",
            ['tontine_id' => $tontine->id],
        );

        return ['ok' => true, 'status' => 200, 'message' => 'Vous avez rejoint la tontine avec succès'];
    }
}
