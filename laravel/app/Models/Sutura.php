<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Sutura extends Model
{
    use HasFactory;

    protected $fillable = [
        'tontine_id',
        'demandeur_id',
        'montant_demande',
        'motif',
        'statut',
        'vote_expires_at',
        'resultat_at',
        'paye_le',
    ];

    protected $casts = [
        'vote_expires_at' => 'datetime',
        'resultat_at'     => 'datetime',
        'paye_le'         => 'datetime',
    ];

    public function demandeur()
    {
        return $this->belongsTo(User::class, 'demandeur_id');
    }

    public function tontine()
    {
        return $this->belongsTo(Tontine::class);
    }

    public function votes()
    {
        return $this->hasMany(SuturaVote::class);
    }
}
