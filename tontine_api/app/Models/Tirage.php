<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Tirage extends Model
{
    protected $fillable = [
        'tontine_id',
        'gagnant_id',
        'tour',
        'montant_attribue',
    ];

    protected $casts = [
        'montant_attribue' => 'decimal:2',
    ];

    // ─── RELATIONS ────────────────────────────────────────────────────────────
    public function tontine()
    {
        return $this->belongsTo(Tontine::class);
    }

    public function gagnant()
    {
        return $this->belongsTo(User::class, 'gagnant_id');
    }
}
