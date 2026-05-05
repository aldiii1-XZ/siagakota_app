import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_sync_service.dart';

class UpdateService {
  final ApiSyncService sync;

  UpdateService({ApiSyncService? syncService}) : sync = syncService ?? ApiSyncService();

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final package = await PackageInfo.fromPlatform();
      sync.setPackageInfo(package);

      final updateInfo = await sync.fetchUpdateInfo();
      if (updateInfo == null) {
        debugPrint('UpdateService: No update available');
        return;
      }

      if (!context.mounted) return;
      await _showDialog(
        context: context,
        latestVersion: updateInfo.latestVersion,
        apkUrl: updateInfo.apkUrl,
        forceUpdate: updateInfo.force,
      );
    } catch (e, st) {
      debugPrint('UpdateService error: $e');
      debugPrint('$st');
    }
  }

  Future<void> _showDialog({
    required BuildContext context,
    required String latestVersion,
    required String apkUrl,
    required bool forceUpdate,
  }) async {
    final Uri uri = Uri.parse(apkUrl);
    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(forceUpdate ? 'Wajib Update' : 'Update tersedia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Versi terbaru: $latestVersion'),
                const SizedBox(height: 8),
                const Text('Silakan unduh APK terbaru untuk melanjutkan.'),
              ],
            ),
            actions: <Widget>[
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Nanti'),
                ),
              FilledButton(
                onPressed: () async {
                  final NavigatorState navigator = Navigator.of(ctx);
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e, st) {
                    debugPrint('UpdateService launch error: $e');
                    debugPrint('$st');
                  }
                  if (!forceUpdate && navigator.canPop()) {
                    navigator.pop();
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      },
    );
  }
}
