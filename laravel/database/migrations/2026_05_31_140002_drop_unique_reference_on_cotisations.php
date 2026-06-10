<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // En suivi manuel, 'reference' est une étiquette saisie par le membre
    // (ou auto-générée) — plusieurs cotisations peuvent partager la même valeur.
    // On lève donc la contrainte UNIQUE héritée du flux paiement en ligne.
    public function up(): void
    {
        Schema::table('cotisations', function (Blueprint $table) {
            $table->dropUnique('cotisations_reference_unique');
        });
    }

    public function down(): void
    {
        Schema::table('cotisations', function (Blueprint $table) {
            $table->unique('reference');
        });
    }
};
