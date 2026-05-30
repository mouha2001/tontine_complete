<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Database\Eloquent\SoftDeletes;
use Laravel\Passport\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, SoftDeletes;

    protected $fillable = [
        'nom',
        'telephone',
        'email',
        'adresse',
        'photo_url',
        'role',
        'otp_code',
        'otp_expires_at',
        'telephone_verified',
        'fcm_token',
    ];

    protected $hidden = [
        'otp_code',
        'otp_expires_at',
        'remember_token',
    ];

    protected $casts = [
        'otp_expires_at'       => 'datetime',
        'telephone_verified'   => 'boolean',
    ];

    // ─── ACCESSORS ────────────────────────────────────────────────────────────
    public function getIsAdminAttribute(): bool
    {
        return $this->role === 'admin';
    }

    public function getInitialesAttribute(): string
    {
        $parts = explode(' ', trim($this->nom));
        if (count($parts) >= 2) {
            return strtoupper($parts[0][0] . $parts[1][0]);
        }
        return strtoupper(substr($this->nom, 0, 2));
    }

    // ─── OTP ──────────────────────────────────────────────────────────────────
    public function generateOtp(): string
    {
        $otp = (string) random_int(100000, 999999);
        $this->update([
            'otp_code'       => $otp,
            'otp_expires_at' => now()->addMinutes(10),
        ]);
        return $otp;
    }

    public function verifyOtp(string $otp): bool
    {
        return $this->otp_code === $otp
            && $this->otp_expires_at
            && $this->otp_expires_at->isFuture();
    }

    public function clearOtp(): void
    {
        $this->update([
            'otp_code'           => null,
            'otp_expires_at'     => null,
            'telephone_verified' => true,
        ]);
    }

    // ─── RELATIONS ────────────────────────────────────────────────────────────
    public function tontinesAdmin()
    {
        return $this->hasMany(Tontine::class, 'admin_id');
    }

    public function tontinesMembre()
    {
        return $this->belongsToMany(Tontine::class, 'tontine_membres')
                    ->withPivot(['ordre_tirage', 'a_recu_fonds'])
                    ->withTimestamps();
    }

    public function cotisations()
    {
        return $this->hasMany(Cotisation::class);
    }

    public function suturaVotes()
    {
        return $this->hasMany(SuturaVote::class);
    }

    public function notifications()
    {
        return $this->hasMany(Notification::class)->orderByDesc('created_at');
    }

    public function tirages()
    {
        return $this->hasMany(Tirage::class, 'gagnant_id');
    }

    // ─── TOARRAY (API RESOURCE) ───────────────────────────────────────────────
    public function toApiArray(): array
    {
        return [
            'id'         => $this->id,
            'nom'        => $this->nom,
            'telephone'  => $this->telephone,
            'email'      => $this->email,
            'adresse'    => $this->adresse,
            'photo_url'  => $this->photo_url,
            'role'       => $this->role,
            'initiales'  => $this->initiales,
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
