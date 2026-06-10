<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Vote d'urgence à durée limitée : échéance du vote (5 ou 10 min).
    public function up(): void
    {
        Schema::table('suturas', function (Blueprint $table) {
            $table->timestamp('vote_expires_at')->nullable()->after('statut');
        });
    }

    public function down(): void
    {
        Schema::table('suturas', function (Blueprint $table) {
            $table->dropColumn('vote_expires_at');
        });
    }
};
