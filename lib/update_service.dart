import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateCheckResult {
  final bool isUpdateAvailable;
  final bool forceUpdate;
  final String apkUrl;
  final String latestVersion;

  const UpdateCheckResult({
    required this.isUpdateAvailable,
    required this.forceUpdate,
    required this.apkUrl,
    required this.latestVersion,
  });

  static const none = UpdateCheckResult(
    isUpdateAvailable: false,
    forceUpdate: false,
    apkUrl: '',
    latestVersion: '',
  );
}

class UpdateService {
  UpdateService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '0.0.0';
    }
  }

  Future<Map<String, dynamic>?> getLatestVersionFromFirestore() async {
    try {
      final snap = await _firestore.collection('config').doc('app_version').get();
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final current = await getCurrentVersion();
      final remote = await getLatestVersionFromFirestore();
      if (remote == null) return UpdateCheckResult.none;

      final latest = remote['latestVersion'] as String? ?? '';
      final apkUrl = remote['apkUrl'] as String? ?? '';
      final force = remote['forceUpdate'] as bool? ?? false;

      if (latest.isEmpty || apkUrl.isEmpty) return UpdateCheckResult.none;

      final needsUpdate = _isNewer(latest, current);
      if (!needsUpdate) return UpdateCheckResult.none;

      return UpdateCheckResult(
        isUpdateAvailable: true,
        forceUpdate: force,
        apkUrl: apkUrl,
        latestVersion: latest,
      );
    } catch (_) {
      return UpdateCheckResult.none;
    }
  }

  bool _isNewer(String latest, String current) {
    List<int> parse(String v) =>
        v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
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
}
