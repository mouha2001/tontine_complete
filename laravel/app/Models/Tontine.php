<?php
// ─── TONTINE ──────────────────────────────────────────────────────────────────
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class Tontine extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'admin_id', 'nom', 'description', 'montant_cotisation',
        'frequence', 'nombre_membres', 'statut', 'date_debut',
        'date_fin', 'tour_actuel', 'invite_code',
    ];

    protected $casts = [
        'montant_cotisation' => 'decimal:2',
        'date_debut'         => 'date',
        'date_fin'           => 'date',
    ];

    protected static function boot()
    {
        parent::boot();
        static::creating(function ($t) {
            $t->invite_code = 'TN-' . strtoupper(Str::random(8));
        });
    }

    // ─── RELATIONS ────────────────────────────────────────────────────────────
    public function admin() { return $this->belongsTo(User::class, 'admin_id'); }

    public function membres()
    {
        return $this->belongsToMany(User::class, 'tontine_membres')
                    ->withPivot(['ordre_tirage', 'a_recu_fonds'])
                    ->withTimestamps();
    }

    public function cotisations() { return $this->hasMany(Cotisation::class); }
    public function sutura()      { return $this->hasMany(Sutura::class); }
    public function tirages()     { return $this->hasMany(Tirage::class); }

    // ─── ACCESSORS ────────────────────────────────────────────────────────────
    public function getMembresActuelsAttribute(): int
    {
        return $this->membres()->count();
    }

    public function getTotalCollecteAttribute(): float
    {
        return (float) $this->cotisations()
            ->where('statut', 'confirme')
            ->sum('montant');
    }

    public function getInviteUrlAttribute(): string
    {
        return config('app.frontend_url') . '/invite/' . $this->invite_code;
    }

    public function toApiArray(bool $withMembers = false): array
    {
        $data = [
            'id'                  => $this->id,
            'nom'                 => $this->nom,
            'description'         => $this->description,
            'montant_cotisation'  => $this->montant_cotisation,
            'frequence'           => $this->frequence,
            'nombre_membres'      => $this->nombre_membres,
            'membres_actuels'     => $this->membres_actuels,
            'statut'              => $this->statut,
            'date_debut'          => $this->date_debut?->toDateString(),
            'date_fin'            => $this->date_fin?->toDateString(),
            'tour_actuel'         => $this->tour_actuel,
            'invite_code'         => $this->invite_code,
            'invite_url'          => $this->invite_url,
            'total_collecte'      => $this->total_collecte,
            'admin_id'            => $this->admin_id,
            'admin'               => $this->admin ? ['nom' => $this->admin->nom] : null,
            'created_at'          => $this->created_at?->toISOString(),
        ];

        if ($withMembers) {
            $data['membres'] = $this->membres->map->toApiArray()->values();
        }

        return $data;
    }
}
