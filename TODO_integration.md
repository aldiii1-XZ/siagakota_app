# TODO Integration: Flutter + Laravel API

## Plan Steps
- [x] 1. Update pubspec.yaml (remove supabase_flutter)
- [x] 4. `flutter pub get`
- [x] 2. Enhance lib/services/api_service.dart (add multipart photo upload)
- [ ] 3. Refactor lib/main.dart (remove Supabase, add ApiSyncService, update Auth/Report controllers)
- [ ] 5. Test backend: `cd backend && php artisan serve`
- [ ] 6. Test Flutter: `flutter run`
- [ ] 7. Full test: register, create report with photo, admin update, sync

**Current: Step 3 - Refactor lib/main.dart**

## Instructions
Run commands in VSCode terminal. Backend uses SQLite dev DB (auto-created).
