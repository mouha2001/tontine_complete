<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Cotisation extends Model
{
    use HasFactory;

    protected $fillable = [
        'tontine_id',
        'user_id',
        'montant',
        'statut',
        'periode',
        'methode_paiement',
        'reference',
        'receipt_url',
        'confirme_par',
        'paye_le',
    ];

    protected $casts = [
        'paye_le' => 'datetime',
        'periode' => 'date',
        'montant' => 'decimal:2',
    ];

    // ─── RELATIONS ─────────────────────────────

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function tontine()
    {
        return $this->belongsTo(Tontine::class);
    }
}
