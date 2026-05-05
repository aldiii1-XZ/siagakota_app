# SiagaKota Mobile App Setup TODO

## Approved Plan Steps (Flutter Mobile App Production Setup)

### 1. ✅ Information Gathering Complete
- Analyzed pubspec.yaml, main.dart, android/ios configs.
- App is already functional mobile app.

### 2. 🔄 Generate Launcher Icons
- Run: `flutter pub run flutter_launcher_icons`
- Uses assets/icons/SiagaKota.png

### 3. 📱 Update Android Config
- Edit android/app/build.gradle.kts: app ID to `id.siagakota.app`
- Add permissions to AndroidManifest.xml (location, camera, storage, notifications)
- Setup release signing

### 4. 🍎 Update iOS Config
- Update bundle ID in Xcode project
- Add usage descriptions to Info.plist

### 5. 🎨 Add Splash Screen
- Add flutter_native_splash to pubspec.yaml
- Configure and run generator

### 6. 🔢 Update Version
- pubspec.yaml: version: 1.0.0+1

### 7. 🧪 Test Builds
- `flutter build apk --release`
- `flutter build ios --release`
- Test on device

### 8. 📤 Distribution
- Upload APK to Firebase/Supabase
- Update Supabase meta.apkUrl

**Next: Confirm plan & proceed to step 2? Or revisions?**

