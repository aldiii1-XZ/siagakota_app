# SiagaKota Backend Setup Guide

## Stack
- **Backend**: Laravel 13 (PHP 8.5+)
- **Database**: SQLite (default untuk dev) / MySQL (production)
- **CSS**: Tailwind CSS (CDN)
- **Auth**: Laravel Sanctum (API token)

---

## Struktur Direktori

```
backend/                     # Laravel project
├── app/Http/Controllers/
│   ├── Api/
│   │   ├── AuthController.php      # API auth (register/login)
│   │   ├── ReportController.php    # API CRUD laporan
│   │   └── MetaController.php      # API app update info
│   └── WebAdminController.php      # Web panel admin
├── app/Models/
│   ├── User.php
│   ├── Report.php
│   └── AppMeta.php
├── database/migrations/
│   ├── 2026_04_28_000001_add_fields_to_users_table.php
│   ├── 2026_04_28_000002_create_reports_table.php
│   └── 2026_04_28_000003_create_app_meta_table.php
├── database/seeders/
│   └── DatabaseSeeder.php          # Demo data
├── resources/views/admin/          # Blade views
│   ├── login.blade.php
│   ├── dashboard.blade.php
│   ├── reports.blade.php
│   ├── report_detail.blade.php
│   ├── users.blade.php
│   └── settings.blade.php
├── resources/views/layouts/
│   └── admin.blade.php             # Layout Tailwind
├── routes/
│   ├── api.php                     # REST API routes
│   └── web.php                     # Web admin routes
└── database/database.sqlite        # SQLite database

lib/services/
└── api_service.dart                # Flutter HTTP client
```

---

## Pre-requisit

- PHP 8.5+
- Composer 2.9+
- SQLite (untuk dev)
- MySQL (untuk production)

---

## Cara Menjalankan

### 1. Setup Database (Development - SQLite)

Database sudah otomatis menggunakan SQLite. File `backend/database/database.sqlite` sudah dibuat.

Jika ingin reset:
```powershell
cd backend
php artisan migrate:fresh --seed
```

### 2. Setup Database (Production - MySQL)

Edit `backend/.env`:
```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=siagakota_db
DB_USERNAME=root
DB_PASSWORD=your_password
```

Buat database MySQL:
```sql
CREATE DATABASE siagakota_db;
```

Lalu jalankan:
```powershell
cd backend
php artisan migrate --seed
```

### 3. Jalankan Server

```powershell
cd backend
php artisan serve
```

Server berjalan di `http://localhost:8000`

---

## Endpoint API

### Authentication
| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| POST | `/api/register` | Register user baru (nama) |
| POST | `/api/login` | Login (email, password) |
| GET | `/api/user` | Profile user (auth) |

### Reports
| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| GET | `/api/reports?kecamatan=&status=&owner=` | List laporan |
| POST | `/api/reports` | Buat laporan baru |
| GET | `/api/reports/{id}` | Detail laporan |
| PUT | `/api/reports/{id}/status` | Update status |
| POST | `/api/reports/{id}/upvote` | Upvote laporan |
| DELETE | `/api/reports/{id}` | Hapus laporan |

### App Meta
| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| GET | `/api/meta` | Info versi app |
| POST | `/api/meta` | Update info (admin) |

---

## Panel Admin Web

Akses di browser:

```
http://localhost:8000/admin/login
```

**Demo Login:**
- Email: `admin@siagakota.id`
- Password: `admin123`

**Fitur Panel:**
- Dashboard dengan statistik laporan
- Daftar laporan dengan filter (status, kecamatan, search)
- Detail laporan dengan update status
- Manajemen user
- Pengaturan app update

---

## Integrasi Flutter

File `lib/services/api_service.dart` sudah menyediakan HTTP client untuk semua endpoint API.

### Ubah `baseUrl` jika perlu:

```dart
static const String baseUrl = 'http://10.0.2.2:8000/api';  // Android emulator
static const String baseUrl = 'http://localhost:8000/api';  // iOS simulator
static const String baseUrl = 'https://your-domain.com/api'; // Production
```

### Ganti `CloudSyncService` (main.dart)
Pada file `lib/main.dart`, ganti `Supabase` dengan `ApiService` dari `lib/services/api_service.dart`.

---

## Troubleshooting

### Port 8000 sudah digunakan
```powershell
php artisan serve --port=8080
```

### Permission storage
Pastikan symlink storage sudah dibuat:
```powershell
cd backend
php artisan storage:link
```

### SQLite database tidak ditemukan
```powershell
cd backend
New-Item database/database.sqlite -ItemType File
php artisan migrate --seed
```

---

## Keamanan

- Ganti default admin password `admin123` sebelum production
- Gunakan HTTPS di production
- Enforce rate limiting dengan Laravel Throttle midleware
- Sanctum token harus disimpan dengan aman di device
