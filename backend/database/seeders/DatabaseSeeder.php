<?php

namespace Database\Seeders;

use App\Models\AppMeta;
use App\Models\Report;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::create([
            'name' => 'Administrator',
            'nama' => 'Administrator',
            'email' => 'admin@siagakota.id',
            'password' => Hash::make('admin123'),
            'role' => 'admin',
            'kecamatan' => 'Ilir Barat I',
        ]);

        $user1 = User::create([
            'name' => 'Budi Santoso',
            'nama' => 'Budi Santoso',
            'email' => 'user1@siagakota.local',
            'password' => null,
            'role' => 'user',
        ]);

        $user2 = User::create([
            'name' => 'Ani Wijaya',
            'nama' => 'Ani Wijaya',
            'email' => 'user2@siagakota.local',
            'password' => null,
            'role' => 'user',
        ]);

        $reports = [
            [
                'id' => Str::uuid(), 'nama' => 'Budi Santoso', 'jenis' => 'Banjir',
                'deskripsi' => 'Banjir setinggi 50cm di Jalan Sudirman',
                'latitude' => -2.9761, 'longitude' => 104.7754,
                'severity' => 4, 'kecamatan' => 'Ilir Barat I',
                'status' => 'diterima', 'owner' => 'Budi Santoso',
            ],
            [
                'id' => Str::uuid(), 'nama' => 'Ani Wijaya', 'jenis' => 'Infrastruktur Rusak',
                'deskripsi' => 'Jembatan retak parah, membahayakan pengendara',
                'latitude' => -2.9900, 'longitude' => 104.7600,
                'severity' => 5, 'kecamatan' => 'Bukit Kecil',
                'status' => 'proses', 'owner' => 'Ani Wijaya',
            ],
            [
                'id' => Str::uuid(), 'nama' => 'Budi Santoso', 'jenis' => 'Pohon Tumbang',
                'deskripsi' => 'Pohon besar tumbang menutup jalan',
                'latitude' => -2.9800, 'longitude' => 104.7700,
                'severity' => 3, 'kecamatan' => 'Ilir Timur I',
                'status' => 'selesai', 'owner' => 'Budi Santoso',
            ],
            [
                'id' => Str::uuid(), 'nama' => 'Rina Sari', 'jenis' => 'Banjir',
                'deskripsi' => 'Genangan air di depan sekolah',
                'latitude' => -2.9750, 'longitude' => 104.7780,
                'severity' => 2, 'kecamatan' => 'Ilir Barat I',
                'status' => 'diterima', 'owner' => 'Rina Sari',
            ],
            [
                'id' => Str::uuid(), 'nama' => 'Dedi Kurniawan', 'jenis' => 'Banjir',
                'deskripsi' => 'Banjir merendam rumah warga',
                'latitude' => -2.9765, 'longitude' => 104.7760,
                'severity' => 5, 'kecamatan' => 'Ilir Barat I',
                'status' => 'proses', 'owner' => 'Dedi Kurniawan',
            ],
        ];

        foreach ($reports as $r) {
            Report::create(array_merge($r, [
                'votes' => rand(0, 10),
                'weather_risk' => 0.5,
                'created_at' => now()->subDays(rand(0, 7)),
            ]));
        }

        AppMeta::create([
            'key' => 'app',
            'latest_version' => '1.1.0',
            'note' => 'Perbaikan bug dan peningkatan performa.',
            'apk_url' => 'https://example.com/siagakota/app-latest.apk',
            'force_update' => false,
        ]);
    }
}

