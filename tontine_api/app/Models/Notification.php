<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'titre',
        'message',
        'type',
        'lue',
    ];

    protected $casts = [
        'lue' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
