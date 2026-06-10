<?php

namespace App\Support;

class Phone
{
    /**
     * Normalise un numéro sénégalais au format LOCAL (sans indicatif) :
     * retire les espaces, le préfixe '+' et l'indicatif '221'.
     * Ex : "+221 77 123 45 67", "221771234567", "771234567" → "771234567".
     *
     * Partagé entre le rate limiter (clé par numéro) et le contrôleur d'auth
     * pour garantir une clé identique avant et après le middleware throttle.
     */
    public static function normalize(string $phone): string
    {
        $phone = preg_replace('/\s+/', '', $phone);
        $phone = ltrim($phone, '+');
        if (str_starts_with($phone, '221')) {
            $phone = substr($phone, 3);
        }
        return $phone;
    }
}
