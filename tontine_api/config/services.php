<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // SMS / OTP — DExchange SMS (https://docs.dexchange-sms.com)
    // ⚠️ Clé câblée en dur (fallback). Surchargeable via DEXCHANGE_SMS_KEY dans .env.
    //    À faire tourner / déplacer en variable d'env si le dépôt est partagé.
    'dexchange' => [
        'url'       => env('DEXCHANGE_SMS_URL', 'https://api-v2.dexchange-sms.com/api/v1'),
        'key'       => env('DEXCHANGE_SMS_KEY') ?: 'API-KEY-939fa6f7-afd4-4778-beec-cb78856ded8d',
        'signature' => env('DEXCHANGE_SMS_SIGNATURE', 'MARKETIFLY'),
    ],

];
