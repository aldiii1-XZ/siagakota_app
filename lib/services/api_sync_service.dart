import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report.dart';
import 'api_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ApiSyncService {
  bool _ready = false;
  PackageInfo? _packageInfo;
  // Use static methods

  bool get isReady => _ready;

  Future<void> init() async {
    _ready = true;
  }

  void setPackageInfo(PackageInfo info) {
    _packageInfo = info;
  }

  Future<List<Report>> fetchReports({
    String? kecamatan,
    String? status,
    String? owner,
  }) async {
    final data = await ApiService.fetchReports(
      kecamatan: kecamatan,
      status: status,
      owner: owner,
    );
    return data.map((json) => Report.fromJson(json)).toList();
  }

  Future<void> createReport(Report report) async {
    final fotoBase64 = report.fotoBytes != null 
        ? base64Encode(report.fotoBytes!) 
        : null;

    final result = await ApiService.createReport(
      nama: report.nama,
      jenis: report.jenis,
      deskripsi: report.deskripsi,
      latitude: report.latitude,
      longitude: report.longitude,
      severity: report.severity,
      kecamatan: report.kecamatan,
      owner: report.owner,
      accuracyMeters: report.accuracyMeters,
      fotoBase64: fotoBase64,
    );

    // Update local cache
    await _cacheReports([Report.fromJson(result)]);
  }

  Future<void> updateStatus(String id, String status) async {
  await ApiService.updateReportStatus(id, status);
    await _refreshLocalCache();
  }

  Future<void> upvote(String id) async {
  await ApiService.upvoteReport(id);
    await _refreshLocalCache();
  }

  Future<bool> deleteReport(String id) async {
  final success = await ApiService.deleteReport(id);
    if (success) {
      await _removeFromLocalCache(id);
    }
    return success;
  }

  Future<AppUpdateInfo?> fetchUpdateInfo() async {
    if (_packageInfo == null) return null;
    final meta = await ApiService.fetchMeta();
    final latest = meta['latest_version'] as String?;
    final note = meta['note'] as String?;
    final apkUrl = meta['apk_url'] as String?;
    final force = meta['force_update'] as bool? ?? false;

    if (latest == null) return null;
    final needsUpdate = _isNewer(latest, _packageInfo!.version);
    if (!needsUpdate) return null;

    return AppUpdateInfo(
      latestVersion: latest,
      note: note ?? 'Versi $latest tersedia.',
      force: force,
      apkUrl: apkUrl ?? '',
    );
  }

  Future<void> _cacheReports(List<Report> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final existingJson = prefs.getStringList('reports_cache') ?? [];
    final allReports = [
      ...reports.map((r) => jsonEncode(r.toJson())),
      ...existingJson,
    ];
    await prefs.setStringList('reports_cache', allReports);
  }

  Future<void> _refreshLocalCache() async {
    final allReports = await fetchReports();
    await _cacheReports(allReports);
  }

  Future<void> _removeFromLocalCache(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existingJson = prefs.getStringList('reports_cache') ?? [];
    final filtered = existingJson.where((jsonStr) {
      final data = jsonDecode(jsonStr);
      return data['id'] != id;
    }).toList();
    await prefs.setStringList('reports_cache', filtered);
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
}

class AppUpdateInfo {
  final String latestVersion;
  final String note;
  final bool force;
  final String apkUrl;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.note,
    required this.force,
    required this.apkUrl,
  });
}
