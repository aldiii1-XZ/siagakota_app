import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Layanan pengecekan update aplikasi dengan sumber data Firestore.
/// Mengambil dokumen `config/app_version` yang berisi:
/// - latestVersion (String)
/// - apkUrl (String)
/// - forceUpdate (bool)
class UpdateService {
  UpdateService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;

      final snap = await _firestore.collection('config').doc('app_version').get();
      final data = snap.data();
      if (data == null) {
        debugPrint('UpdateService: Firestore doc empty');
        return;
      }

      final latest = data['latestVersion'] as String? ?? '';
      final apkUrl = data['apkUrl'] as String? ?? '';
      final force = data['forceUpdate'] as bool? ?? false;

      if (latest.isEmpty || apkUrl.isEmpty) {
        debugPrint('UpdateService: latest/apkUrl missing');
        return;
      }

      final needsUpdate = _isNewer(latest, currentVersion);
      if (!needsUpdate) return;

      if (!context.mounted) return;
      await _showDialog(
        context: context,
        latestVersion: latest,
        apkUrl: apkUrl,
        forceUpdate: force,
      );
    } catch (e, st) {
      debugPrint('UpdateService error: $e');
      debugPrint('$st');
    }
  }

  bool _isNewer(String latest, String current) {
    List<int> parse(String v) => v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = parse(latest);
    final c = parse(current);
    final len = l.length > c.length ? l.length : c.length;
    for (var i = 0; i < len; i++) {
      final li = i < l.length ? l[i] : 0;
      final ci = i < c.length ? c[i] : 0;
      if (li > ci) return true;
      if (li < ci) return false;
    }
    return false;
  }

  Future<void> _showDialog({
    required BuildContext context,
    required String latestVersion,
    required String apkUrl,
    required bool forceUpdate,
  }) async {
    final uri = Uri.parse(apkUrl);
    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) {
        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(forceUpdate ? 'Wajib Update' : 'Update tersedia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versi terbaru: $latestVersion'),
                const SizedBox(height: 8),
                const Text('Silakan unduh APK terbaru untuk melanjutkan.'),
              ],
            ),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Nanti'),
                ),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(ctx);
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
