<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Paiements gérés hors-app : la cotisation est un ENREGISTREMENT suivi dans l'app,
    // validé par l'admin. methode_paiement devient une simple étiquette (wave / orange_money
    // / free_money / cash) ; confirme_par trace l'admin qui a validé.
    public function up(): void
    {
        Schema::table('cotisations', function (Blueprint $table) {
            $table->string('methode_paiement', 20)->change();
            $table->unsignedBigInteger('confirme_par')->nullable()->after('statut');
        });
    }

    public function down(): void
    {
        Schema::table('cotisations', function (Blueprint $table) {
            $table->dropColumn('confirme_par');
            $table->enum('methode_paiement', ['wave', 'orange_money'])->change();
        });
    }
};
