<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Quand un tirage honore une urgence approuvée (le demandeur reçoit le pot),
    // on horodate ici pour ne pas la ré-honorer aux tirages suivants.
    public function up(): void
    {
        Schema::table('suturas', function (Blueprint $table) {
            $table->timestamp('paye_le')->nullable()->after('resultat_at');
        });
    }

    public function down(): void
    {
        Schema::table('suturas', function (Blueprint $table) {
            $table->dropColumn('paye_le');
        });
    }
};
