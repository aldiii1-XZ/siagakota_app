/// SiagaKota — titik masuk aplikasi.
/// Menyiapkan layanan, penyedia status, dan tema; lalu membuka layar splash.
library;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'controllers/index.dart';
import 'services/index.dart';
import 'layar/splash.dart';

final notificationService = NotificationService();
final cloudSync = CloudSyncService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zlrochssnbctknwngade.supabase.co',
    anonKey: 'sb_publishable_GKXuik7hl19yglck_IlSUg_pt0Zbvl8',
  );
  await notificationService.init();
  await cloudSync.init();
  final packageInfo = await PackageInfo.fromPlatform();
  cloudSync.setPackageInfo(packageInfo);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        // Pemberitahuan didaftarkan sebelum laporan supaya laporan bisa
        // mengirim pemberitahuan saat status berubah.
        ChangeNotifierProvider(create: (_) => PemberitahuanController()),
        ChangeNotifierProvider(
          create: (ctx) => ReportController(
            cloud: cloudSync,
            onStatusBerubah: (report, status) {
              ctx
                  .read<PemberitahuanController>()
                  .tambahPerubahanStatus(report: report, status: status);
            },
          ),
        ),
        ChangeNotifierProvider(create: (_) => EnvironmentController()),
      ],
      child: const SiagaKotaApp(),
    ),
  );
}

class SiagaKotaApp extends StatelessWidget {
  const SiagaKotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SiagaKota',
      theme: AppTheme.getTheme(),
      home: const SplashScreen(),
    );
  }
}
