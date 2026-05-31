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
                    ->withPivot(['ordre_tirage', 'nombre_parts', 'parts_recues'])
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

    // Total des parts déjà prises (capacité comptée en parts, pas en personnes)
    public function getPartsActuellesAttribute(): int
    {
        return (int) $this->membres()->sum('tontine_membres.nombre_parts');
    }

    // Places (parts) encore disponibles : nombre_membres = nombre total de parts/tours
    public function getPlacesRestantesAttribute(): int
    {
        return max(0, $this->nombre_membres - $this->parts_actuelles);
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

    public function toApiArray(bool $withMembers = false, ?int $currentUserId = null): array
    {
        $data = [
            'id'                  => $this->id,
            'nom'                 => $this->nom,
            'description'         => $this->description,
            'montant_cotisation'  => $this->montant_cotisation,
            'frequence'           => $this->frequence,
            'nombre_membres'      => $this->nombre_membres,   // = nombre total de parts/tours
            'nombre_parts_total'  => $this->nombre_membres,
            'parts_actuelles'     => $this->parts_actuelles,
            'places_restantes'    => $this->places_restantes,
            'membres_actuels'     => $this->membres_actuels,
            'mes_parts'           => $currentUserId !== null
                ? (int) ($this->membres()->where('user_id', $currentUserId)->value('tontine_membres.nombre_parts') ?? 0)
                : 0,
            'statut'              => $this->statut,
            'date_debut'          => $this->date_debut?->toDateString(),
            'date_fin'            => $this->date_fin?->toDateString(),
            'tour_actuel'         => $this->tour_actuel,
            'invite_code'         => $this->invite_code,
            'invite_url'          => $this->invite_url,
            'total_collecte'      => $this->total_collecte,
            'admin_id'            => $this->admin_id,
            'est_admin'           => $currentUserId !== null && $this->admin_id === $currentUserId,
            'admin'               => $this->admin
                ? ['nom' => $this->admin->nom, 'prenom' => $this->admin->prenom]
                : null,
            'created_at'          => $this->created_at?->toISOString(),
        ];

        if ($withMembers) {
            $data['membres'] = $this->membres->map->toApiArray()->values();
        }

        return $data;
    }
}
