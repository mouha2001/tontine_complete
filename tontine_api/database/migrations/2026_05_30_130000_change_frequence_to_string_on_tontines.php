<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // La fréquence reste descriptive ; on passe d'un enum (3 valeurs) à une
    // simple chaîne pour autoriser quotidien/bimestriel sans CHECK rigide.
    // La validation des valeurs est faite au niveau des contrôleurs.
    public function up(): void
    {
        Schema::table('tontines', function (Blueprint $table) {
            $table->string('frequence', 20)->change();
        });
    }

    public function down(): void
    {
        Schema::table('tontines', function (Blueprint $table) {
            $table->enum('frequence', ['hebdomadaire', 'bimensuel', 'mensuel'])->change();
        });
    }
};
