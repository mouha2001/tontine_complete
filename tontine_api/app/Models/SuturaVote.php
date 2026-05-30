<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SuturaVote extends Model
{
    use HasFactory;

    protected $fillable = [
        'sutura_id',
        'user_id',
        'approuve',
    ];

    protected $casts = [
        'approuve' => 'boolean',
    ];

    public function sutura()
    {
        return $this->belongsTo(Sutura::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
