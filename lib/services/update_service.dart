import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
        bool busy = false;
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            Future<void> run(Future<void> Function() action) async {
              if (busy) return;
              setState(() => busy = true);
              try {
                await action();
              } finally {
                if (context.mounted) {
                  setState(() => busy = false);
                }
              }
            }

            return PopScope(
              canPop: !forceUpdate && !busy,
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
                    if (busy) ...<Widget>[
                      const SizedBox(height: 12),
                      const Row(
                        children: <Widget>[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text('Memproses APK...')),
                        ],
                      ),
                    ],
                  ],
                ),
                actions: <Widget>[
                  if (!forceUpdate)
                    TextButton(
                      onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                      child: const Text('Nanti'),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            try {
                              await _shareApk(apkUrl, latestVersion);
                            } catch (e, st) {
                              debugPrint('UpdateService share error: $e');
                              debugPrint('$st');
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Gagal membagikan APK: $e')),
                                );
                              }
                            }
                          }),
                    child: const Text('Bagikan APK'),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final NavigatorState navigator = Navigator.of(ctx);
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (e, st) {
                              debugPrint('UpdateService launch error: $e');
                              debugPrint('$st');
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Gagal membuka link APK: $e')),
                                );
                              }
                            }
                            if (!forceUpdate && navigator.canPop()) {
                              navigator.pop();
                            }
                          }),
                    child: const Text('Update'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareApk(String apkUrl, String latestVersion) async {
    final File apkFile = await _downloadApk(apkUrl, latestVersion);
    await Share.shareXFiles(
      <XFile>[XFile(apkFile.path, mimeType: 'application/vnd.android.package-archive')],
      text: 'APK SiagaKota versi $latestVersion',
    );
  }

  Future<File> _downloadApk(String apkUrl, String latestVersion) async {
    final Uri uri = Uri.parse(apkUrl);
    final http.Response response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final Directory dir = await getTemporaryDirectory();
    final String fileName = _apkFileName(uri, latestVersion);
    final File file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  String _apkFileName(Uri uri, String latestVersion) {
    final String lastSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last.trim() : '';
    if (lastSegment.toLowerCase().endsWith('.apk')) {
      return lastSegment;
    }
    final String safeVersion = latestVersion.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    return 'siagakota-$safeVersion.apk';
  }
}
