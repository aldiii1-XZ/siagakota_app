import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/index.dart';

const String kDefaultApkUrl = 'https://example.com/siagakota/app-latest.apk';

class CloudSyncService {
  final bool enable = true; // set false untuk mematikan cloud sync.
  late SupabaseClient _supabase;
  bool _ready = false;
  PackageInfo? _packageInfo;

  bool get isReady => _ready;

  Future<void> init() async {
    if (!enable) return;
    try {
      _supabase = Supabase.instance.client;
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  void setPackageInfo(PackageInfo info) {
    _packageInfo = info;
  }

  Stream<List<Report>> listenReports() {
    if (!isReady) return const Stream.empty();
    return _supabase.from('reports').stream(primaryKey: ['id']).map(
        (snap) => snap.map((d) => Report.fromJson(d)).toList());
  }

  Future<List<Report>> fetchReports() async {
    if (!isReady) return [];
    try {
      final List<dynamic> data = await _supabase.from('reports').select();
      return data.map((d) => Report.fromJson(d)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> upsertReport(Report report) async {
    if (!isReady) return;
    await _supabase.from('reports').upsert(report.toJson());
  }

  Future<void> deleteReport(String id) async {
    if (!isReady) return;
    await _supabase.from('reports').delete().eq('id', id);
  }

  Future<AppUpdateInfo?> fetchUpdateInfo() async {
    if (!isReady || _packageInfo == null) return null;
    try {
      final response =
          await _supabase.from('meta').select().eq('id', 'app').single();

      if (response.isEmpty) return null;
      final latest = response['latestVersion'] as String?;
      final note = response['note'] as String?;
      final apkUrl = response['apkUrl'] as String?;
      final force = response['forceUpdate'] as bool? ?? false;
      if (latest == null) return null;
      final needsUpdate = _isNewer(latest, _packageInfo!.version);
      if (!needsUpdate) return null;
      return AppUpdateInfo(
        latestVersion: latest,
        note: note ?? 'Versi $latest tersedia. Silakan perbarui aplikasi.',
        force: force,
        apkUrl: apkUrl ?? kDefaultApkUrl,
      );
    } catch (_) {
      return null;
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

  /// Upload image to Supabase Storage and return the public URL
  /// Returns null if upload fails or service is not ready
  Future<String?> uploadImage(String reportId, Uint8List imageBytes) async {
    if (!isReady) return null;
    try {
      final fileName = 'laporan_$reportId.jpg';

      // Upload to 'report_images' bucket
      await _supabase.storage.from('report_images').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl =
          _supabase.storage.from('report_images').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('Gagal upload gambar: $e');
      return null;
    }
  }
}
