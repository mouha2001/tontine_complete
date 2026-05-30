<?php
// 2024_01_01_000002_create_tontines_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // ─── TONTINES ────────────────────────────────────────────────────────
        Schema::create('tontines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_id')->constrained('users')->onDelete('cascade');
            $table->string('nom');
            $table->text('description')->nullable();
            $table->decimal('montant_cotisation', 12, 2);
            $table->enum('frequence', ['hebdomadaire', 'bimensuel', 'mensuel']);
            $table->integer('nombre_membres');
            $table->enum('statut', ['en_attente', 'active', 'terminee'])->default('en_attente');
            $table->date('date_debut')->nullable();
            $table->date('date_fin')->nullable();
            $table->integer('tour_actuel')->default(0);
            $table->string('invite_code', 20)->unique()->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        // ─── MEMBRES DE TONTINE ───────────────────────────────────────────────
        Schema::create('tontine_membres', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tontine_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->integer('ordre_tirage')->nullable(); // ordre attribué
            $table->boolean('a_recu_fonds')->default(false);
            $table->timestamps();
            $table->unique(['tontine_id', 'user_id']);
        });

        // ─── COTISATIONS ─────────────────────────────────────────────────────
        Schema::create('cotisations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tontine_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->decimal('montant', 12, 2);
            $table->enum('statut', ['en_attente', 'confirme', 'echoue'])->default('en_attente');
            $table->enum('methode_paiement', ['wave', 'orange_money']);
            $table->string('reference')->nullable()->unique(); // ref paiement externe
            $table->string('receipt_url')->nullable();
            $table->json('webhook_data')->nullable(); // données webhook Wave/OM
            $table->timestamp('paye_le')->nullable();
            $table->timestamps();
        });

        // ─── SUTURA (URGENCES) ────────────────────────────────────────────────
        Schema::create('suturas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tontine_id')->constrained()->onDelete('cascade');
            $table->foreignId('demandeur_id')->constrained('users')->onDelete('cascade');
            // demandeur_id est stocké mais jamais exposé dans l'API (anonymat)
            $table->decimal('montant_demande', 12, 2);
            $table->text('motif');
            $table->enum('statut', ['en_cours', 'approuve', 'rejete'])->default('en_cours');
            $table->timestamp('resultat_at')->nullable();
            $table->timestamps();
        });

        // ─── VOTES SUTURA ─────────────────────────────────────────────────────
        Schema::create('sutura_votes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sutura_id')->constrained('suturas')->onDelete('cascade');
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->boolean('approuve');
            $table->timestamps();
            $table->unique(['sutura_id', 'user_id']); // un seul vote par membre
        });

        // ─── TIRAGES ──────────────────────────────────────────────────────────
        Schema::create('tirages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tontine_id')->constrained()->onDelete('cascade');
            $table->foreignId('gagnant_id')->constrained('users')->onDelete('cascade');
            $table->integer('tour');
            $table->decimal('montant_attribue', 12, 2);
            $table->timestamps();
        });

        // ─── NOTIFICATIONS ────────────────────────────────────────────────────
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('type'); // 'cotisation_confirmee', 'vote_sutura', 'tirage_resultat', etc.
            $table->string('titre');
            $table->text('message');
            $table->json('data')->nullable(); // données additionnelles (tontine_id, etc.)
            $table->boolean('lu')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('tirages');
        Schema::dropIfExists('sutura_votes');
        Schema::dropIfExists('suturas');
        Schema::dropIfExists('cotisations');
        Schema::dropIfExists('tontine_membres');
        Schema::dropIfExists('tontines');
    }
};
