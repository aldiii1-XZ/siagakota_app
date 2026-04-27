# TODO Setup Laravel + MySQL + Tailwind CSS Backend

## Phase 1: Laravel Project Setup
- [x] Create backend/ directory
- [x] Initialize Laravel project via Composer
- [x] Configure .env for SQLite (dev) / MySQL (prod)
- [x] Install Laravel Sanctum
- [x] Setup Tailwind CSS with CDN

## Phase 2: Database Layer
- [x] Migration: create_users_table (extend default)
- [x] Migration: create_reports_table
- [x] Migration: create_app_meta_table
- [x] Eloquent Models: User, Report, AppMeta with relations

## Phase 3: REST API for Flutter
- [x] AuthController: register, login, profile
- [x] ReportController: CRUD, upvote, filter
- [x] AdminController: stats, status update
- [x] MetaController: app update info
- [x] API Routes in routes/api.php
- [x] File storage config for photos
- [x] Sanctum middleware setup

## Phase 4: Web Admin Panel (Tailwind CSS)
- [x] Blade layout with Tailwind
- [x] Admin login page
- [x] Dashboard with stats cards
- [x] Reports list table with filters
- [x] Report detail & status update
- [x] User management page
- [x] Responsive navbar layout

## Phase 5: Flutter Integration
- [x] Create lib/services/api_service.dart
- [x] Update CloudSyncService in main.dart
- [x] Handle multipart photo upload
- [x] Update pubspec.yaml if needed

## Phase 6: Seeding & Testing
- [x] Database seeders for demo data
- [x] Test API endpoints
- [x] Instructions for running

## Phase 7: Bug Fixes
- [x] Register api.php routes in bootstrap/app.php (Laravel 13)
- [x] Move /api/meta to public routes (no auth required)
- [x] Add HasApiTokens trait to User model

## ALL TASKS COMPLETED

