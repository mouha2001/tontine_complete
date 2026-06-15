<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Cotisation à l'avance : 'periode' = le mois CIBLÉ par la cotisation
    // (1er jour du mois). Permet de payer en avance pour un mois futur.
    public function up(): void
    {
        Schema::table('cotisations', function (Blueprint $table) {
            $table->date('periode')->nullable()->after('statut');
        });
    }

    public function down(): void
    {
        Schema::table('cotisations', function (Blueprint $table) {
            $table->dropColumn('periode');
        });
    }
};
