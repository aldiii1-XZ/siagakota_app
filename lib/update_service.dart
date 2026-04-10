import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Layanan pengecekan update aplikasi dengan sumber data Supabase.
/// Mengambil dokumen dari tabel `meta` dengan id='app_version' yang berisi:
/// - latest_version (String)
/// - apk_url (String)
/// - force_update (bool)
class UpdateService {
  UpdateService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;

      final response = await _supabase
          .from('meta')
          .select()
          .eq('id', 'app_version')
          .maybeSingle();
      
      if (response == null) {
        debugPrint('UpdateService: Supabase doc empty');
        return;
      }

      final String latest = response['latest_version'] as String? ?? '';
      final String apkUrl = response['apk_url'] as String? ?? '';
      final bool force = response['force_update'] as bool? ?? false;

      if (latest.isEmpty || apkUrl.isEmpty) {
        debugPrint('UpdateService: latest/apkUrl missing');
        return;
      }

      final bool needsUpdate = _isNewer(latest, currentVersion);
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
    int compareLists(List<int> a, List<int> b) {
      final int maxLen = a.length > b.length ? a.length : b.length;
      for (int i = 0; i < maxLen; i++) {
        final int ai = i < a.length ? a[i] : 0;
        final int bi = i < b.length ? b[i] : 0;
        if (ai > bi) return 1;
        if (ai < bi) return -1;
      }
      return 0;
    }

    List<int> parse(String v) {
      final String core = v.split('+').first.split('-').first;
      return core
          .split('.')
          .map((String e) => int.tryParse(e) ?? 0)
          .toList();
    }

    return compareLists(parse(latest), parse(current)) > 0;
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
