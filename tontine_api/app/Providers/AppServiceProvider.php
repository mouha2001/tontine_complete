<?php

namespace App\Providers;

use App\Support\Phone;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Anti-spam OTP : limite PAR NUMÉRO (et non par IP, pour ne pas bloquer
        // plusieurs utilisateurs derrière un même NAT opérateur) — 3 SMS / minute.
        RateLimiter::for('otp', function (Request $request) {
            // Normaliser AVANT de bâtir la clé : sinon "+221…", "221…", "77…"
            // compteraient comme des numéros différents → throttle contournable.
            $phone = Phone::normalize((string) $request->input('telephone'));
            return Limit::perMinute(3)->by($phone ?: $request->ip());
        });
    }
}
