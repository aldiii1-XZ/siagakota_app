<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_meta', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->string('latest_version')->nullable();
            $table->text('note')->nullable();
            $table->string('apk_url')->nullable();
            $table->boolean('force_update')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_meta');
    }
};

