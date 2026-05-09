import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/index.dart';
import '../services/index.dart';

final NotificationService notificationService = NotificationService();

class ReportController extends ChangeNotifier {
  final CloudSyncService? cloud;
  final List<Report> _reports = [];
  final _uuid = const Uuid();
  final List<Report> _sortedCache = [];
  bool _sortedDirty = true;
  final List<ReportDraft> _drafts = [];
  bool _draftLoaded = false;
  bool _reportsLoaded = false;
  StreamSubscription<List<Report>>? _cloudSub;

  ReportController({this.cloud}) {
    loadDrafts();
    loadReports();
    _fetchInitialFromCloud();
    _attachCloud();
  }

  Future<void> _fetchInitialFromCloud() async {
    if (cloud == null) return;
    // Tunggu sebentar agar isReady benar-benar siap (init async).
    await Future.delayed(const Duration(milliseconds: 500));
    final data = await cloud!.fetchReports();
    if (data.isNotEmpty) {
      replaceFromCloud(data);
    }
  }

  @override
  void dispose() {
    _cloudSub?.cancel();
    super.dispose();
  }

  List<Report> get reports => List.unmodifiable(_reports);
  List<ReportDraft> get drafts => List.unmodifiable(_drafts);
  List<Report> get sortedReports {
    if (_sortedDirty) {
      _sortedCache
        ..clear()
        ..addAll(_reports)
        ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
      _sortedDirty = false;
    }
    return List.unmodifiable(_sortedCache);
  }

  Future<void> addReport({
    required String nama,
    required String jenis,
    required String deskripsi,
    required double severity,
    required String kecamatan,
    required String owner,
    required Position position,
    String? fotoPath,
    Uint8List? fotoBytes,
  }) async {
    final reportId = _uuid.v4();

    // Upload photo to Supabase Storage if available
    String? photoUrl;
    if (fotoBytes != null && cloud != null) {
      photoUrl = await cloud!.uploadImage(reportId, fotoBytes);
    }

    final newReport = Report(
      id: reportId,
      nama: nama,
      jenis: jenis,
      deskripsi: deskripsi,
      latitude: position.latitude,
      longitude: position.longitude,
      severity: severity,
      kecamatan: kecamatan,
      fotoPath: fotoPath,
      fotoBytes: null, // Don't store Base64 in database, use photoUrl instead
      photoUrl: photoUrl,
      accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
      createdAt: DateTime.now(),
      owner: owner,
      weatherRisk: _mockWeatherRisk(position.latitude, position.longitude),
    );
    final duplicate = _findDuplicate(newReport);
    if (duplicate != null) {
      newReport.duplicateOf = duplicate.id;
      duplicate.votes += 1;
    }

    _reports.insert(0, newReport);
    _sortedDirty = true;
    await _persistReports();
    _syncUp(newReport);
    notifyListeners();
  }

  Future<void> addDraft(ReportDraft draft) async {
    _drafts.insert(0, draft);
    await _persistDrafts();
    notifyListeners();
  }

  Future<void> removeDraft(ReportDraft draft) async {
    _drafts.remove(draft);
    await _persistDrafts();
    notifyListeners();
  }

  Future<void> _persistDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _drafts.map((d) => d.toJson()).toList();
    prefs.setString('drafts', jsonEncode(list));
  }

  Future<void> loadDrafts() async {
    if (_draftLoaded) return;
    _draftLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('drafts');
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ReportDraft.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _drafts
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {
      // ignore corrupt drafts
    }
  }

  void upvote(String id) {
    final idx = _reports.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _reports[idx].votes += 1;
    _sortedDirty = true;
    _persistReports();
    _syncUp(_reports[idx]);
    notifyListeners();
  }

  void updateStatus(String id, ReportStatus status) {
    final idx = _reports.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _reports[idx].status = status;
    _sortedDirty = true;
    notificationService.showStatusChange(
      'Status laporan berubah',
      '${_reports[idx].jenis} kini ${status.label}',
    );
    _persistReports();
    _syncUp(_reports[idx]);
    notifyListeners();
  }

  Future<bool> deleteReport({
    required String id,
    required bool isAdmin,
    required String? requester,
  }) async {
    final idx = _reports.indexWhere((r) => r.id == id);
    if (idx == -1) return false;

    final report = _reports[idx];
    if (!isAdmin && report.owner != requester) {
      return false;
    }

    _reports.removeAt(idx);
    _sortedDirty = true;
    await _persistReports();
    await cloud?.deleteReport(id);
    notifyListeners();
    return true;
  }

  Report? _findDuplicate(Report incoming) {
    const radiusMeters = 200.0;
    const timeWindow = Duration(hours: 2);
    for (final r in _reports) {
      final sameType = r.jenis == incoming.jenis;
      final closeBy = Geolocator.distanceBetween(
            r.latitude,
            r.longitude,
            incoming.latitude,
            incoming.longitude,
          ) <=
          radiusMeters;
      final recent =
          incoming.createdAt.difference(r.createdAt).abs() <= timeWindow;
      if (sameType && closeBy && recent) {
        return r;
      }
    }
    return null;
  }

  double _mockWeatherRisk(double lat, double lng) {
    return 0.5;
  }

  Future<void> _persistReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _reports.map((r) => r.toJson()).toList();
      await prefs.setString('reports', jsonEncode(list));
    } catch (_) {
      // abaikan kegagalan simpan
    }
  }

  Future<void> loadReports() async {
    if (_reportsLoaded) return;
    _reportsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('reports');
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => Report.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _reports
        ..clear()
        ..addAll(list);
      _sortedDirty = true;
      notifyListeners();
    } catch (_) {
      // abaikan jika gagal parse
    }
  }

  void replaceFromCloud(List<Report> incoming) {
    _reports
      ..clear()
      ..addAll(incoming);
    _sortedDirty = true;
    _persistReports();
    notifyListeners();
  }

  void _attachCloud() {
    if (cloud == null || !cloud!.isReady) return;
    _cloudSub = cloud!.listenReports().listen((data) {
      if (data.isEmpty && _reports.isNotEmpty) {
        // Seed cloud with existing local data.
        for (final r in _reports) {
          _syncUp(r);
        }
        return;
      }
      replaceFromCloud(data);
    });
  }

  void _syncUp(Report report) {
    cloud?.upsertReport(report);
  }

  List<Hotspot> computeHotspots({
    int minCount = 3,
    List<Report>? source,
  }) {
    final data = source ?? _reports;
    if (data.isEmpty) return const [];
    final buckets = <String, _HotBucket>{};
    for (final r in data) {
      final key = _bucketKey(r.latitude, r.longitude);
      final bucket = buckets.putIfAbsent(key, () => _HotBucket());
      bucket.count += 1;
      bucket.latSum += r.latitude;
      bucket.lngSum += r.longitude;
      bucket.severitySum += r.severity;
    }
    final result = <Hotspot>[];
    for (final entry in buckets.entries) {
      final b = entry.value;
      if (b.count < minCount) continue;
      result.add(
        Hotspot(
          latitude: b.latSum / b.count,
          longitude: b.lngSum / b.count,
          count: b.count,
          averageSeverity: b.severitySum / b.count,
        ),
      );
    }
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  String _bucketKey(double lat, double lng) {
    // Grid kasar ~1 km (0.01 derajat) untuk penanda rawan.
    final latKey = (lat * 100).round();
    final lngKey = (lng * 100).round();
    return '$latKey:$lngKey';
  }
}

class _HotBucket {
  int count = 0;
  double latSum = 0;
  double lngSum = 0;
  double severitySum = 0;
}
