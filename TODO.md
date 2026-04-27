# TODO Setup Laravel + MySQL + Tailwind CSS Backend

## Phase 1: Laravel Project Setup
- [x] Create backend/ directory
- [x] Initialize Laravel project via Composer
- [x] Configure .env for MySQL
- [x] Install Laravel Sanctum
- [ ] Setup Tailwind CSS with Vite

## Phase 2: Database Layer
- [ ] Migration: create_users_table (extend default)
- [ ] Migration: create_reports_table
- [ ] Migration: create_app_meta_table
- [ ] Eloquent Models: User, Report, AppMeta with relations

## Phase 3: REST API for Flutter
- [ ] AuthController: register, login, profile
- [ ] ReportController: CRUD, upvote, filter
- [ ] AdminController: stats, status update
- [ ] MetaController: app update info
- [ ] API Routes in routes/api.php
- [ ] File storage config for photos
- [ ] Sanctum middleware setup

## Phase 4: Web Admin Panel (Tailwind CSS)
- [ ] Blade layout with Tailwind
- [ ] Admin login page
- [ ] Dashboard with stats cards
- [ ] Reports list table with filters
- [ ] Report detail & status update
- [ ] User management page
- [ ] Responsive navbar layout

## Phase 5: Flutter Integration
- [ ] Create lib/services/api_service.dart
- [ ] Update CloudSyncService in main.dart
- [ ] Handle multipart photo upload
- [ ] Update pubspec.yaml if needed

## Phase 6: Seeding & Testing
- [ ] Database seeders for demo data
- [ ] Test API endpoints
- [ ] Instructions for running

