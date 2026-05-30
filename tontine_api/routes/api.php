<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\TontineController;
use App\Http\Controllers\CotisationController;
use App\Http\Controllers\SuturaController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\NotificationController;
use Illuminate\Support\Facades\Route;

/*
|─────────────────────────────────────────────────────────────────────────────
| API Routes — Tontine Digitale
| Toutes les routes authentifiées utilisent Laravel Passport (Bearer Token)
|─────────────────────────────────────────────────────────────────────────────
*/

// ─── ROUTES PUBLIQUES (sans authentification) ─────────────────────────────────
Route::prefix('auth')->group(function () {
    Route::post('/send-otp',       [AuthController::class, 'sendOtp']);
    Route::post('/verify-otp',     [AuthController::class, 'verifyOtp']);
   Route::post('/auth/register', [AuthController::class, 'registerAdmin']);
    Route::post('/join-invite',    [AuthController::class, 'joinViaInvite']);
});

// Webhook paiements (sans auth — appelé par Wave / Orange Money)
Route::post('/cotisations/webhook', [CotisationController::class, 'webhook'])
    ->name('webhook.paiement');

// ─── ROUTES AUTHENTIFIÉES ─────────────────────────────────────────────────────
Route::middleware('auth:api')->group(function () {

    // Auth
    Route::prefix('auth')->group(function () {
        Route::get('/me',     [AuthController::class, 'me']);
        Route::post('/logout', [AuthController::class, 'logout']);
    });

    // Dashboard
    Route::prefix('dashboard')->group(function () {
        Route::get('/stats',    [DashboardController::class, 'stats']);
        Route::get('/activites', [DashboardController::class, 'activites']);
    });

    // Tontines
    Route::prefix('tontines')->group(function () {
        Route::get('/',                                  [TontineController::class, 'index']);
        Route::post('/',                                 [TontineController::class, 'store']);         // admin
        Route::get('/{id}',                              [TontineController::class, 'show']);
        Route::put('/{id}',                              [TontineController::class, 'update']);        // admin
        Route::delete('/{id}',                           [TontineController::class, 'destroy']);       // admin
        Route::post('/{id}/invite',                      [TontineController::class, 'generateInvite']); // admin
        Route::get('/{id}/membres',                      [TontineController::class, 'membres']);
        Route::delete('/{id}/membres/{userId}',          [TontineController::class, 'removeMembre']);  // admin
        Route::post('/{id}/tirage',                      [TontineController::class, 'lancerTirage']); // admin
        Route::get('/{id}/tirage/historique',            [TontineController::class, 'historiqueTirage']);
    });

    // Cotisations
    Route::prefix('cotisations')->group(function () {
        Route::get('/',             [CotisationController::class, 'index']);
        Route::post('/initier',     [CotisationController::class, 'initierPaiement']);
        Route::post('/verifier',    [CotisationController::class, 'verifierPaiement']);
    });

    // Sutura (Urgences)
    Route::prefix('sutura')->group(function () {
        Route::get('/',             [SuturaController::class, 'index']);
        Route::post('/',            [SuturaController::class, 'store']);
        Route::post('/{id}/voter',  [SuturaController::class, 'voter']);
    });

    // Notifications
    Route::prefix('notifications')->group(function () {
        Route::get('/',                  [NotificationController::class, 'index']);
        Route::get('/non-lues',          [NotificationController::class, 'nbNonLues']);
        Route::post('/{id}/lire',        [NotificationController::class, 'marquerLue']);
        Route::post('/lire-toutes',      [NotificationController::class, 'marquerToutesLues']);
        Route::post('/fcm-token',        [NotificationController::class, 'enregistrerFcmToken']);
    });
});
