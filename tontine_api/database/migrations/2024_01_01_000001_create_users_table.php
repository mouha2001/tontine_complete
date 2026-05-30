<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('nom');
            $table->string('telephone', 20)->unique();
            $table->string('email')->nullable()->unique();
            $table->string('adresse')->nullable();
            $table->string('photo_url')->nullable();
            $table->enum('role', ['admin', 'membre'])->default('membre');
            $table->string('otp_code', 6)->nullable();
            $table->timestamp('otp_expires_at')->nullable();
            $table->boolean('telephone_verified')->default(false);
            $table->string('fcm_token')->nullable(); // Firebase notifications
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
