<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    // Parts multiples : un membre peut prendre 1 à 3 parts (double/triple).
    // - nombre_parts  : nombre de parts détenues
    // - parts_recues  : nombre de fois où le membre a déjà reçu les fonds
    //                   (remplace le booléen a_recu_fonds, insuffisant pour >1 part)
    public function up(): void
    {
        Schema::table('tontine_membres', function (Blueprint $table) {
            $table->unsignedInteger('nombre_parts')->default(1)->after('ordre_tirage');
            $table->unsignedInteger('parts_recues')->default(0)->after('nombre_parts');
        });

        // Reprise des données existantes : a_recu_fonds=true → 1 part reçue
        DB::table('tontine_membres')->where('a_recu_fonds', true)->update(['parts_recues' => 1]);

        Schema::table('tontine_membres', function (Blueprint $table) {
            $table->dropColumn('a_recu_fonds');
        });
    }

    public function down(): void
    {
        Schema::table('tontine_membres', function (Blueprint $table) {
            $table->boolean('a_recu_fonds')->default(false)->after('ordre_tirage');
        });

        DB::table('tontine_membres')->where('parts_recues', '>', 0)->update(['a_recu_fonds' => true]);

        Schema::table('tontine_membres', function (Blueprint $table) {
            $table->dropColumn(['nombre_parts', 'parts_recues']);
        });
    }
};
