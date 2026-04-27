<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reports', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->nullable()->constrained('users')->onDelete('set null');
            $table->string('nama');
            $table->string('jenis')->default('Banjir');
            $table->text('deskripsi')->nullable();
            $table->decimal('latitude', 10, 8);
            $table->decimal('longitude', 11, 8);
            $table->decimal('severity', 3, 1)->default(3);
            $table->string('kecamatan');
            $table->string('foto_path')->nullable();
            $table->double('accuracy_meters')->nullable();
            $table->enum('status', ['diterima', 'proses', 'selesai'])->default('diterima');
            $table->integer('votes')->default(0);
            $table->uuid('duplicate_of')->nullable();
            $table->decimal('weather_risk', 4, 2)->default(0);
            $table->string('owner');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');
    }
};

