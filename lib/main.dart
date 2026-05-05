import 'dart:io' show File, Platform;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; /*  */
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'update_service.dart';
import 'theme.dart';
import 'components.dart';

final NotificationService notificationService = NotificationService();
final CloudSyncService cloudSync = CloudSyncService();
const String kDefaultApkUrl = 'https://example.com/siagakota/app-latest.apk';

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
        ChangeNotifierProvider(
          create: (_) => ReportController(cloud: cloudSync),
        ),
      ],
      child: const SiagaKotaApp(),
    ),
  );
}

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

/// Representasi user yang disimpan di Firestore.
class UserProfile {
  final String id;
  final String nama;
  final String role;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.nama,
    required this.role,
    required this.createdAt,
  });
}

/// Layanan khusus untuk operasi Supabase terkait user.
class UserService {
  final SupabaseClient _supabase;
  UserService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<UserProfile> createUser(
      {required String name, String role = 'user'}) async {
    final now = DateTime.now();
    try {
      final response = await _supabase
          .from('users')
          .insert({
            'nama': name,
            'role': role,
            'created_at': now.toIso8601String(),
          })
          .select()
          .single();

      return UserProfile(
        id: response['id'] as String,
        nama: response['nama'] as String,
        role: response['role'] as String,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (_) {
      return UserProfile(
        id: const Uuid().v4(),
        nama: name,
        role: role,
        createdAt: now,
      );
    }
  }

  Future<UserProfile?> getUser(String id) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', id).single();

      return UserProfile(
        id: response['id'] as String,
        nama: response['nama'] as String? ?? '-',
        role: response['role'] as String? ?? 'user',
        createdAt: DateTime.parse(response['created_at'] as String? ??
            DateTime.now().toIso8601String()),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Menyimpan sesi login di SharedPreferences (ID & nama user).
class UserSessionManager {
  static const _keyUserId = 'session_user_id';
  static const _keyUserName = 'session_user_name';
  static const _keyAccounts = 'accountsV2'; // format: name::id

  Future<void> saveSession(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUserName, user.nama);
  }

  Future<void> saveSessionRaw(
      {required String id, required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, id);
    await prefs.setString(_keyUserName, name);
  }

  Future<Map<String, String>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyAccounts) ?? [];
    final map = <String, String>{};
    for (final entry in raw) {
      final parts = entry.split('::');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  Future<void> saveAccounts(Map<String, String> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = accounts.entries.map((e) => '${e.key}::${e.value}').toList();
    await prefs.setStringList(_keyAccounts, list);
  }

  Future<(String?, String?)> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyUserId), prefs.getString(_keyUserName));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
  }
}

class AuthController extends ChangeNotifier {
  final _userService = UserService();
  final _session = UserSessionManager();
  Map<String, String> _accountIds = {}; // name -> userId
  String? _userId;
  String? _userName;
  bool _ready = false;
  bool _isAdmin = false;
  String? _adminKecamatan;

  String? get userId => _userId;
  String? get userName => _userName;
  List<String> get accounts => List.unmodifiable(_accountIds.keys);
  bool get isReady => _ready;
  bool get isLoggedIn => _userId != null;
  bool get isAdmin => _isAdmin;
  String? get adminKecamatan => _adminKecamatan;

  AuthController() {
    _load();
  }

  Future<void> _load() async {
    try {
      _accountIds = await _session.loadAccounts();
      final session = await _session.loadSession();
      _userId = session.$1;
      _userName = session.$2;
    } catch (e) {
      // Jika gagal baca prefs, tetap lanjut dengan data kosong agar UI tidak hang.
      _accountIds = {};
      _userId = null;
      _userName = null;
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> _persistAccounts() async {
    try {
      await _session.saveAccounts(_accountIds);
    } catch (_) {}
  }

  Future<void> createAccount(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final user = await _userService.createUser(name: clean);
    _userId = user.id;
    _userName = user.nama;
    _accountIds[user.nama] = user.id;
    await _persistAccounts();
    await _session.saveSession(user);
    notifyListeners();
  }

  Future<void> loginWithExisting(String name) async {
    final id = _accountIds[name];
    if (id == null) return;
    _userId = id;
    _userName = name;
    await _session.saveSessionRaw(id: id, name: name);
    notifyListeners();
  }

  Future<bool> loginAsAdmin({
    required String password,
    required String kecamatan,
  }) async {
    const adminPassword = 'admin123';
    if (password.trim() != adminPassword) return false;
    _adminKecamatan = kecamatan;
    _isAdmin = true;
    _userName = 'Admin';
    _userId = 'admin';
    await _session.saveSessionRaw(id: _userId!, name: _userName!);
    notifyListeners();
    return true;
  }

  void logout() {
    _userName = null;
    _userId = null;
    _isAdmin = false;
    _adminKecamatan = null;
    _session.clearSession();
    notifyListeners();
  }
}

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showStatusChange(String title, String body) async {
    if (kIsWeb || !_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      'status_channel',
      'Status Laporan',
      channelDescription: 'Notifikasi perubahan status laporan',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notifDetails = NotificationDetails(android: androidDetails);
    await _plugin.show(DateTime.now().millisecond, title, body, notifDetails);
  }
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    // Quick connectivity probe to Supabase.
    () async {
      try {
        await Supabase.instance.client.from('test').insert({
          'message': 'Supabase Connected ✅',
          'time': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    await _updateService.checkForUpdate(context);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SiagaLoadingWidget(
        message: 'Memuat SiagaKota...',
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (!auth.isReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isLoggedIn) {
          return const HomeShell();
        }
        return const LoginPage();
      },
    );
  }
}

enum ReportStatus { diterima, proses, selesai }

enum ExportFormat { csv, pdf, doc, print }

const List<String> kecamatanPalembang = [
  'Alang-Alang Lebar',
  'Bukit Kecil',
  'Gandus',
  'Ilir Barat I',
  'Ilir Barat II',
  'Ilir Timur I',
  'Ilir Timur II',
  'Ilir Timur III',
  'Jakabaring',
  'Kalidoni',
  'Kemuning',
  'Kertapati',
  'Plaju',
  'Sako',
  'Seberang Ulu I',
  'Seberang Ulu II',
  'Sematang Borang',
  'Sukarami',
];

extension ReportStatusText on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.diterima:
        return 'Diterima';
      case ReportStatus.proses:
        return 'Proses';
      case ReportStatus.selesai:
        return 'Selesai';
    }
  }

  Color get color {
    switch (this) {
      case ReportStatus.diterima:
        return AppTheme.warning;
      case ReportStatus.proses:
        return AppTheme.info;
      case ReportStatus.selesai:
        return AppTheme.success;
    }
  }
}

class Hotspot {
  final double latitude;
  final double longitude;
  final int count;
  final double averageSeverity;

  const Hotspot({
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.averageSeverity,
  });
}

class Report {
  final String id;
  final String nama;
  final String jenis;
  final String deskripsi;
  final double latitude;
  final double longitude;
  final double severity; // 1..5
  final String kecamatan;
  final String? fotoPath;
  final Uint8List? fotoBytes;
  final double? accuracyMeters;
  final DateTime createdAt;
  final String owner; // nama akun yang membuat
  ReportStatus status;
  int votes;
  String? duplicateOf;
  double weatherRisk;

  Report({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.deskripsi,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.kecamatan,
    required this.fotoPath,
    required this.fotoBytes,
    required this.accuracyMeters,
    required this.createdAt,
    required this.owner,
    this.status = ReportStatus.diterima,
    this.votes = 0,
    this.duplicateOf,
    this.weatherRisk = 0,
  });

  double get priorityScore => severity * 2 + votes + weatherRisk;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'jenis': jenis,
        'deskripsi': deskripsi,
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity,
        'kecamatan': kecamatan,
        'fotoPath': fotoPath,
        'fotoBytes': fotoBytes != null ? base64Encode(fotoBytes!) : null,
        'accuracyMeters': accuracyMeters,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'votes': votes,
        'duplicateOf': duplicateOf,
        'weatherRisk': weatherRisk,
        'owner': owner,
      };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as String,
        nama: json['nama'] as String? ?? '-',
        jenis: json['jenis'] as String? ?? 'Banjir',
        deskripsi: json['deskripsi'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        severity: (json['severity'] as num).toDouble(),
        kecamatan: json['kecamatan'] as String? ?? kecamatanPalembang.first,
        fotoPath: json['fotoPath'] as String?,
        fotoBytes: json['fotoBytes'] != null
            ? base64Decode(json['fotoBytes'] as String)
            : null,
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        status: ReportStatus.values.firstWhere((e) => e.name == json['status'],
            orElse: () => ReportStatus.diterima),
        votes: json['votes'] as int? ?? 0,
        duplicateOf: json['duplicateOf'] as String?,
        weatherRisk: (json['weatherRisk'] as num?)?.toDouble() ?? 0,
        owner: json['owner'] as String? ?? '-',
      );
}

class ReportDraft {
  final String nama;
  final String jenis;
  final String deskripsi;
  final double severity;
  final String kecamatan;
  final String? fotoPath;
  final String? fotoBase64;

  ReportDraft({
    required this.nama,
    required this.jenis,
    required this.deskripsi,
    required this.severity,
    required this.kecamatan,
    this.fotoPath,
    this.fotoBase64,
  });

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'jenis': jenis,
        'deskripsi': deskripsi,
        'severity': severity,
        'kecamatan': kecamatan,
        'fotoPath': fotoPath,
        'fotoBase64': fotoBase64,
      };

  factory ReportDraft.fromJson(Map<String, dynamic> json) => ReportDraft(
        nama: json['nama'] as String,
        jenis: json['jenis'] as String? ?? 'Banjir',
        deskripsi: json['deskripsi'] as String? ?? '',
        severity: (json['severity'] as num?)?.toDouble() ?? 3,
        kecamatan: json['kecamatan'] as String? ?? kecamatanPalembang.first,
        fotoPath: json['fotoPath'] as String?,
        fotoBase64: json['fotoBase64'] as String?,
      );
}

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
    _attachCloud();
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
    final newReport = Report(
      id: _uuid.v4(),
      nama: nama,
      jenis: jenis,
      deskripsi: deskripsi,
      latitude: position.latitude,
      longitude: position.longitude,
      severity: severity,
      kecamatan: kecamatan,
      fotoPath: fotoPath,
      fotoBytes: fotoBytes,
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final UpdateService _updateService = UpdateService();
  Position? _currentPosition;
  bool _locLoading = false;
  String? _locError;
  String? _locLabel;
  Future<bool>? _permissionRequestFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initLocationFlow();
    _checkUpdate();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  Future<void> _initLocationFlow() async {
    final ok = await _ensureLocationPermission();
    if (mounted && ok) await _ambilLokasiAwal();
  }

  Future<void> _checkUpdate() async {
    await _updateService.checkForUpdate(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final reportsProvider = context.watch<ReportController>();
    final visibleReports = auth.isAdmin
        ? reportsProvider.reports
            .where((r) => r.kecamatan == auth.adminKecamatan)
            .toList()
        : reportsProvider.reports
            .where((r) => r.owner == auth.userName)
            .toList();
    final hotspots = auth.isAdmin
        ? reportsProvider.computeHotspots(minCount: 3)
        : reportsProvider.computeHotspots(
            source: visibleReports,
            minCount: 3,
          );
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: SiagaLogo(
            size: 36,
            padding: EdgeInsets.all(4),
            showShadow: false,
          ),
        ),
        title: Text('SiagaKota • ${auth.userName ?? 'Pengguna'}'),
        actions: [
          _LocationBadge(
            position: _currentPosition,
            loading: _locLoading,
            error: _locError,
            label: _locLabel,
            onRefresh: _ambilLokasiAwal,
            onShowError: _showLocError,
          ),
          const SizedBox(width: 6),
          if (auth.isAdmin)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPanelPage()),
                );
              },
              icon: const Icon(Icons.admin_panel_settings),
              label: Text(auth.adminKecamatan ?? 'Panel'),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.blueGrey.shade800),
            ),
          if (auth.isAdmin) const SizedBox(width: 6),
          IconButton(
            tooltip: 'Keluar',
            onPressed: () {
              auth.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthGate()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Beranda'),
            Tab(text: 'Laporan'),
            Tab(text: 'Peta'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const DashboardView(),
          const ReportListView(),
          MapView(
            reports: visibleReports,
            hotspots: hotspots,
            currentPosition: _currentPosition,
            onRefreshLocation: _ambilLokasiAwal,
          ),
        ],
      ),
      floatingActionButton: auth.isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportFormPage()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Buat Laporan'),
            ),
    );
  }

  Future<void> _ambilLokasiAwal() async {
    setState(() {
      _locLoading = true;
      _locError = null;
      _locLabel = null;
    });
    try {
      final pos = await _getPrecisePosition();
      if (pos == null) return;
      _locError = null; // clear previous errors on success
      String? label;
      try {
        final places = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (places.isNotEmpty) {
          final p = places.first;
          final parts = [
            if ((p.street ?? '').isNotEmpty) p.street,
            if ((p.subLocality ?? '').isNotEmpty) p.subLocality,
            if ((p.locality ?? '').isNotEmpty) p.locality,
          ];
          if (parts.isNotEmpty) {
            label = parts.join(', ');
          }
        }
      } catch (_) {
        // abaikan kegagalan reverse geocoding
      }
      setState(() {
        _currentPosition = pos;
        _locLabel = label;
      });
    } catch (e) {
      setState(() => _locError = 'Gagal ambil lokasi: $e');
      _showLocError();
    } finally {
      if (mounted) {
        setState(() => _locLoading = false);
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.always ||
        status == LocationPermission.whileInUse) {
      return true;
    }

    if (status == LocationPermission.deniedForever) {
      _locError =
          'Izin lokasi ditolak permanen. Aktifkan dari pengaturan aplikasi.';
      _showLocError();
      return false;
    }

    if (_permissionRequestFuture != null) {
      return _permissionRequestFuture!;
    }

    _permissionRequestFuture = () async {
      final res = await Geolocator.requestPermission();
      final granted = res == LocationPermission.always ||
          res == LocationPermission.whileInUse;
      if (!granted) {
        _locError = res == LocationPermission.deniedForever
            ? 'Izin lokasi ditolak permanen. Aktifkan dari pengaturan aplikasi.'
            : 'Izin lokasi ditolak';
        _showLocError();
      }
      return granted;
    }();

    try {
      return await _permissionRequestFuture!;
    } finally {
      _permissionRequestFuture = null;
    }
  }

  Future<Position?> _getPrecisePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locError = 'Layanan lokasi belum aktif');
      _showLocError();
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final granted = await _ensureLocationPermission();
      if (!granted) return null;
      permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        setState(() => _locError = 'Izin lokasi ditolak');
        _showLocError();
        return null;
      }
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
    } on TimeoutException catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }

    if (pos == null) {
      setState(() => _locError = 'Gagal ambil lokasi (tidak ada data GPS)');
      _showLocError();
    }
    return pos;
  }

  void _showLocError() {
    if (!mounted || _locError == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_locError!)));
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final controller = TextEditingController();
  final adminPassController = TextEditingController();
  String _adminKecamatan = kecamatanPalembang.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_handleNameChanged);
    controller.dispose();
    adminPassController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final hasAccounts = auth.accounts.isNotEmpty;
        final theme = Theme.of(context);
        final canCreate = !_saving && controller.text.trim().isNotEmpty;
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFDFEFF),
                  Color(0xFFF4F8FF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: -120,
                    left: -80,
                    child: _backgroundOrb(
                      size: 260,
                      color: AppTheme.primary.withAlpha(18),
                    ),
                  ),
                  Positioned(
                    top: 180,
                    right: -110,
                    child: _backgroundOrb(
                      size: 240,
                      color: AppTheme.secondary.withAlpha(14),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: FadeInScale(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: SiagaLogo(
                                  size: 92,
                                  padding: EdgeInsets.all(10),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'SiagaKota',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1C3F70),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                hasAccounts
                                    ? 'Portal layanan pengaduan masyarakat. Pilih akun yang sudah dibuat atau tambahkan akun baru.'
                                    : 'Portal layanan pengaduan masyarakat. Buat akun terlebih dahulu agar laporan bisa tersimpan.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6F86A8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _buildAdminEntryCard(),
                              const SizedBox(height: 24),
                              if (hasAccounts) ...[
                                _buildSectionTitle('Pilih akun'),
                                const SizedBox(height: 14),
                                ...auth.accounts.map(
                                  (name) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildAccountCard(
                                      name: name,
                                      onTap: () async {
                                        await auth.loginWithExisting(name);
                                        if (!context.mounted) return;
                                        Navigator.of(context)
                                            .pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (_) => const AuthGate(),
                                          ),
                                          (route) => false,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              _buildSectionTitle('Buat akun baru'),
                              const SizedBox(height: 14),
                              _buildNameField(),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 68,
                                child: FilledButton.icon(
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person_add_alt_1_rounded),
                                  label: Text(
                                    _saving ? 'Menyimpan...' : 'Simpan & Masuk',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: canCreate
                                        ? AppTheme.primary.withAlpha(210)
                                        : const Color(0xFFD9E3F1),
                                    foregroundColor: canCreate
                                        ? Colors.white
                                        : const Color(0xFF8FA4C3),
                                    disabledBackgroundColor:
                                        const Color(0xFFD9E3F1),
                                    disabledForegroundColor:
                                        const Color(0xFF8FA4C3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: canCreate
                                      ? () => _createAccount(auth)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 44),
                              Text(
                                '© 2026 SIAGAKOTA PALEMBANG',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFF8CA2C4),
                                  letterSpacing: 2.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createAccount(AuthController auth) async {
    final name = controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama akun tidak boleh kosong')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await auth.createAccount(name);
      if (!mounted) return;
      controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun tersimpan dan login berhasil')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan akun: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAdminLogin() async {
    final auth = context.read<AuthController>();
    adminPassController.clear();
    final success = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Masuk mode Admin'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adminPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password admin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _adminKecamatan,
                  decoration: const InputDecoration(
                    labelText: 'Kecamatan yang dikelola',
                    border: OutlineInputBorder(),
                  ),
                  items: kecamatanPalembang
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(k),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      _adminKecamatan = val ?? kecamatanPalembang.first,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await auth.loginAsAdmin(
                    password: adminPassController.text,
                    kecamatan: _adminKecamatan,
                  );
                  if (!ok) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Password admin salah')),
                    );
                    return;
                  }
                  if (mounted) {
                    navigator.pop(true);
                  }
                },
                child: const Text('Masuk'),
              ),
            ],
          ),
        ) ??
        false;

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  Widget _buildAdminEntryCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _openAdminLogin,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(245),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD7E1F0)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withAlpha(18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF5FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF2F6BFF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Masuk sebagai Petugas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF23446F),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard({
    required String name,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF8FBEFF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F6BFF).withAlpha(24),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_circle_outlined,
                  color: Color(0xFF2F6BFF),
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F3B64),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AKUN TERDAFTAR',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF8AA3C8),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC4D0E1),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: 'Nama akun',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD6E0ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD6E0ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF84B6FF), width: 1.8),
        ),
      ),
      onSubmitted: (_) {
        if (!_saving && controller.text.trim().isNotEmpty) {
          _createAccount(context.read<AuthController>());
        }
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF8FA6C7),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Divider(
            color: Color(0xFFD9E3EF),
            thickness: 1.4,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _backgroundOrb({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withAlpha(0),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportListView extends StatelessWidget {
  const ReportListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (context, controller, _) {
        final auth = context.watch<AuthController>();
        final items = auth.isAdmin
            ? controller.sortedReports
                .where((r) => r.kecamatan == auth.adminKecamatan)
                .toList()
            : controller.sortedReports
                .where((r) => r.owner == auth.userName)
                .toList();
        final drafts = controller.drafts;

        if (items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (drafts.isNotEmpty)
                DraftsBanner(drafts: drafts, controller: controller),
              EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Belum ada laporan',
                subtitle: 'Mulai buat laporan untuk wilayahmu.',
                iconColor: AppTheme.primary,
                action: FilledButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Buat laporan'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportFormPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length + (drafts.isNotEmpty ? 1 : 0),
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (drafts.isNotEmpty) {
              if (index == 0) {
                return DraftsBanner(drafts: drafts, controller: controller);
              }
              final report = items[index - 1];
              return ReportCard(report: report);
            }
            final report = items[index];
            return ReportCard(report: report);
          },
        );
      },
    );
  }
}

class DraftsBanner extends StatelessWidget {
  const DraftsBanner({
    super.key,
    required this.drafts,
    required this.controller,
  });

  final List<ReportDraft> drafts;
  final ReportController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Draft laporan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: drafts
                  .map(
                    (d) => InputChip(
                      label: Text(d.jenis),
                      avatar: const Icon(Icons.drafts, size: 18),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportFormPage(draft: d),
                          ),
                        );
                        await controller.removeDraft(d);
                      },
                      onDeleted: () => controller.removeDraft(d),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, this.initialCenter});

  final LatLng? initialCenter;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late LatLng _center;
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? const LatLng(-6.2000, 106.8166);
    _selected = widget.initialCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih lokasi di peta'),
        actions: [
          TextButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.pop<LatLng>(context, _selected),
            child: const Text(
              'Pakai',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 15,
          minZoom: 3,
          maxZoom: 18,
          onTap: (tapPosition, point) {
            setState(() => _selected = point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.siagakota',
          ),
          if (_selected != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selected!,
                  width: 42,
                  height: 42,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 36,
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selected == null
                    ? 'Ketuk peta untuk memilih titik.'
                    : 'Dipilih: ${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ReportController>();
    final auth = context.watch<AuthController>();
    final formatter = DateFormat('dd MMM HH:mm');

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: severityColor(
                      report.severity,
                    ).withAlpha((0.15 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    report.severity.toStringAsFixed(1),
                    style: TextStyle(
                      color: severityColor(report.severity),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.jenis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatter.format(report.createdAt),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(report.deskripsi, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(icon: Icons.map, label: report.kecamatan),
                _InfoChip(icon: Icons.place, label: _coordLabel(report)),
                if (report.duplicateOf != null)
                  _InfoChip(icon: Icons.link, label: 'Duplikasi'),
                _InfoChip(
                  icon: Icons.how_to_vote,
                  label: '${report.votes} dukungan',
                ),
              ],
            ),
            if (report.fotoBytes != null || report.fotoPath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: report.fotoBytes != null
                    ? Image.memory(
                        report.fotoBytes!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          height: 160,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Text('Foto tidak dapat dimuat'),
                        ),
                      )
                    : Image.file(
                        File(report.fotoPath!),
                        height: 160,
                        width: double.infinity,
                        cacheHeight: 720,
                        cacheWidth: 1280,
                        filterQuality: FilterQuality.medium,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          height: 160,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Text('Foto tidak dapat dimuat'),
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () => controller.upvote(report.id),
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                  color: Colors.indigo,
                ),
                Text('${report.votes}'),
                const Spacer(),
                IconButton(
                  tooltip: auth.isAdmin ? 'Hapus laporan' : 'Tarik laporan',
                  onPressed: () => _confirmDelete(context, controller, auth),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade500,
                ),
                if (auth.isAdmin)
                  PopupMenuButton<ReportStatus>(
                    tooltip: 'Ubah status',
                    onSelected: (val) =>
                        controller.updateStatus(report.id, val),
                    itemBuilder: (_) => ReportStatus.values
                        .map(
                          (s) => PopupMenuItem(
                            value: s,
                            child: Text(s.label),
                          ),
                        )
                        .toList(),
                    child: const Icon(Icons.more_vert),
                  )
                else
                  Tooltip(
                    message: 'Hanya admin yang dapat mengubah status',
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _coordLabel(Report r) =>
      '${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}';

  Future<void> _confirmDelete(
    BuildContext context,
    ReportController controller,
    AuthController auth,
  ) async {
    final isAdmin = auth.isAdmin;
    final title = isAdmin ? 'Hapus laporan?' : 'Tarik laporan?';
    final message = isAdmin
        ? 'Laporan akan dihapus permanen.'
        : 'Laporan akan ditarik dan tidak tampil lagi.';
    final actionLabel = isAdmin ? 'Hapus' : 'Tarik';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await controller.deleteReport(
      id: report.id,
      isAdmin: isAdmin,
      requester: auth.userName,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Laporan berhasil ${isAdmin ? 'dihapus' : 'ditarik'}'
              : 'Gagal menghapus laporan',
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: status.color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  const _LocationBadge({
    required this.position,
    required this.loading,
    required this.error,
    required this.label,
    required this.onRefresh,
    required this.onShowError,
  });

  final Position? position;
  final bool loading;
  final String? error;
  final String? label;
  final Future<void> Function() onRefresh;
  final VoidCallback onShowError;

  @override
  Widget build(BuildContext context) {
    final text = () {
      if (loading) return 'Memuat...';
      if (error != null) return 'Lokasi off';
      if ((label ?? '').isNotEmpty) return label!;
      if (position != null) {
        return '${position!.latitude.toStringAsFixed(2)}, ${position!.longitude.toStringAsFixed(2)}';
      }
      return 'Lokasi?';
    }();

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onPressed: loading
              ? null
              : () async {
                  await onRefresh();
                  if (error != null) onShowError();
                },
          icon: Icon(
            loading ? Icons.timelapse : Icons.my_location,
            size: 18,
            color: loading
                ? Colors.blueGrey
                : (error != null ? Colors.red : Colors.blue),
          ),
          label: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (ctx, controller, child) {
        final auth = ctx.watch<AuthController>();
        final visible = auth.isAdmin
            ? controller.reports
                .where((r) => r.kecamatan == auth.adminKecamatan)
                .toList()
            : controller.reports
                .where((r) => r.owner == auth.userName)
                .toList();
        final total = visible.length;
        final selesai =
            visible.where((r) => r.status == ReportStatus.selesai).length;
        final proses =
            visible.where((r) => r.status == ReportStatus.proses).length;
        final diterima = total - selesai - proses;

        Map<String, int> perJenis = {};
        for (final r in visible) {
          perJenis[r.jenis] = (perJenis[r.jenis] ?? 0) + 1;
        }
        final hotspots = auth.isAdmin
            ? controller.computeHotspots(minCount: 3)
            : controller.computeHotspots(
                source: visible,
                minCount: 3,
              );

        final recentReports = [...visible]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _DashboardHero(
              isAdmin: auth.isAdmin,
              userName: auth.userName,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  title: 'Total Laporan',
                  value: '$total',
                  icon: Icons.assignment_outlined,
                  iconColor: const Color(0xFF2563EB),
                  background: const Color(0xFFEFF6FF),
                ),
                _MetricCard(
                  title: 'Diterima',
                  value: '$diterima',
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFFD97706),
                  background: const Color(0xFFFFF7ED),
                ),
                _MetricCard(
                  title: 'Diproses',
                  value: '$proses',
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  background: const Color(0xFFF5F3FF),
                ),
                _MetricCard(
                  title: 'Selesai',
                  value: '$selesai',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF059669),
                  background: const Color(0xFFECFDF5),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                final leftPanel = _DashboardReportsPanel(
                  auth: auth,
                  reports: recentReports,
                );
                final rightPanel = Column(
                  children: [
                    _DashboardSummaryPanel(
                      perJenis: perJenis,
                      hotspots: hotspots,
                    ),
                    const SizedBox(height: 16),
                    _DashboardActionsPanel(
                      isAdmin: auth.isAdmin,
                      onExport: () => _showExportSheet(context),
                    ),
                  ],
                );

                if (!isWide) {
                  return Column(
                    children: [
                      leftPanel,
                      const SizedBox(height: 16),
                      rightPanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: leftPanel),
                    const SizedBox(width: 20),
                    Expanded(child: rightPanel),
                  ],
                );
              },
            ),
            if (hotspots.isNotEmpty) ...[
              Text(
                'Wilayah rawan (≥3 laporan dalam radius ~1km)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...hotspots.take(5).map(
                    (h) => ListTile(
                      leading:
                          const Icon(Icons.warning_amber, color: Colors.red),
                      title: Text(
                        '${h.latitude.toStringAsFixed(4)}, ${h.longitude.toStringAsFixed(4)}',
                      ),
                      subtitle: Text(
                        '${h.count} laporan • keparahan rata-rata ${h.averageSeverity.toStringAsFixed(1)}',
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_view),
                title: const Text('Export ke CSV / Excel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, ExportFormat.csv);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export ke PDF'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, ExportFormat.pdf);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Export ke Word (.doc)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, ExportFormat.doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Print langsung'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, ExportFormat.print);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportData(BuildContext context, ExportFormat format) async {
    final controller = context.read<ReportController>();
    final auth = context.read<AuthController>();
    final data = auth.isAdmin
        ? controller.reports
            .where((r) => r.kecamatan == auth.adminKecamatan)
            .toList()
        : controller.reports.where((r) => r.owner == auth.userName).toList();
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data untuk diexport')),
      );
      return;
    }

    try {
      switch (format) {
        case ExportFormat.csv:
          await _exportCsv(data);
          if (!context.mounted) return;
          _toast(context, 'CSV siap dibagikan');
          break;
        case ExportFormat.pdf:
          await _exportPdf(data, share: true);
          if (!context.mounted) return;
          _toast(context, 'PDF siap dibagikan');
          break;
        case ExportFormat.doc:
          await _exportDoc(data);
          if (!context.mounted) return;
          _toast(context, 'Dokumen .doc siap dibagikan');
          break;
        case ExportFormat.print:
          await _exportPdf(data, share: false, printDirect: true);
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, 'Gagal export: $e');
    }
  }

  Future<void> _exportCsv(List<Report> data) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'Jenis,Nama,Deskripsi,Severity,Status,Kecamatan,Latitude,Longitude,Tanggal,Akun',
    );
    for (final r in data) {
      buffer.writeln(
        '${_csv(r.jenis)},${_csv(r.nama)},${_csv(r.deskripsi)},${r.severity},${r.status.label},${_csv(r.kecamatan)},${r.latitude},${r.longitude},${r.createdAt.toIso8601String()},${_csv(r.owner)}',
      );
    }
    final bytes = utf8.encode(buffer.toString());
    final file = XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: 'siagakota_export.csv',
    );
    await Share.shareXFiles([file], text: 'Export data SiagaKota');
  }

  Future<void> _exportDoc(List<Report> data) async {
    final buffer = StringBuffer();
    buffer.writeln('Data Laporan SiagaKota');
    buffer.writeln('=======================');
    for (final r in data) {
      buffer.writeln(
        '- ${r.jenis} | ${r.nama} | ${r.deskripsi} | Severity ${r.severity} | ${r.status.label} | ${r.kecamatan} | ${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)} | ${DateFormat('dd MMM yyyy HH:mm').format(r.createdAt)} | ${r.owner}',
      );
    }
    final bytes = utf8.encode(buffer.toString());
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/msword',
      name: 'siagakota_export.doc',
    );
    await Share.shareXFiles([file], text: 'Export DOC SiagaKota');
  }

  Future<void> _exportPdf(
    List<Report> data, {
    bool share = true,
    bool printDirect = false,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            'Data Laporan SiagaKota',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: [
              'Jenis',
              'Nama',
              'Deskripsi',
              'Severity',
              'Status',
              'Kecamatan',
              'Koordinat',
              'Tanggal',
              'Akun',
            ],
            data: data
                .map(
                  (r) => [
                    r.jenis,
                    r.nama,
                    r.deskripsi,
                    r.severity.toStringAsFixed(1),
                    r.status.label,
                    r.kecamatan,
                    '${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}',
                    DateFormat('dd MMM yyyy HH:mm').format(r.createdAt),
                    r.owner,
                  ],
                )
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
            columnWidths: {2: const pw.FixedColumnWidth(160)},
          ),
        ],
      ),
    );

    final bytes = await doc.save();

    if (printDirect) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
      return;
    }

    final file = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: 'siagakota_export.pdf',
    );
    await Share.shareXFiles([file], text: 'Export PDF SiagaKota');
  }

  String _csv(String value) {
    final v = value.replaceAll('"', '""');
    return '"$v"';
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.isAdmin,
    required this.userName,
  });

  final bool isAdmin;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin ? 'Dashboard Petugas' : 'Beranda Warga',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'Ringkasan laporan masyarakat yang membutuhkan penanganan.'
                      : 'Pantau laporan Anda dan buat pengaduan baru dengan cepat.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ),
          ),
          if (!isAdmin && (userName ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                userName!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.background,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width < 720 ? (width - 44) / 2 : 220.0;
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardReportsPanel extends StatelessWidget {
  const _DashboardReportsPanel({
    required this.auth,
    required this.reports,
  });

  final AuthController auth;
  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  auth.isAdmin
                      ? 'Antrean Laporan Masyarakat'
                      : 'Daftar Laporan Anda',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                ),
              ),
              const Icon(Icons.tune_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada laporan')),
            )
          else
            ...reports.take(3).map((report) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DashboardReportTile(
                    report: report,
                    isAdmin: auth.isAdmin,
                  ),
                )),
        ],
      ),
    );
  }
}

class _DashboardReportTile extends StatelessWidget {
  const _DashboardReportTile({
    required this.report,
    required this.isAdmin,
  });

  final Report report;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM • HH:mm');
    final urgencyColor = severityColor(report.severity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  report.jenis == 'Pohon Tumbang'
                      ? Icons.warning_amber_rounded
                      : Icons.place_outlined,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.deskripsi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.id.substring(0, 8)} • ${report.jenis}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                    ),
                  ],
                ),
              ),
              if (report.severity >= 4)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.kecamatan,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    formatter.format(report.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              StatusChip(status: report.status),
              const Spacer(),
              Text(
                isAdmin ? 'Proses Laporan' : 'Lihat Detail',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF2563EB),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSummaryPanel extends StatelessWidget {
  const _DashboardSummaryPanel({
    required this.perJenis,
    required this.hotspots,
  });

  final Map<String, int> perJenis;
  final List<Hotspot> hotspots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Kategori',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          ...perJenis.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.label_outline_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key)),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (hotspots.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Text(
              'Titik Rawan',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            ...hotspots.take(3).map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${h.count} laporan • rata-rata ${h.averageSeverity.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _DashboardActionsPanel extends StatelessWidget {
  const _DashboardActionsPanel({
    required this.isAdmin,
    required this.onExport,
  });

  final bool isAdmin;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAdmin ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isAdmin
                      ? Icons.navigation_outlined
                      : Icons.file_download_outlined,
                  color: isAdmin
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isAdmin ? 'Sistem Navigasi Patroli' : 'Ekspor Data Laporan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAdmin
                ? 'Buka panel ekspor atau tindak lanjuti laporan warga dengan alur yang lebih cepat.'
                : 'Unduh ringkasan laporan Anda dalam format CSV, PDF, Word, atau cetak langsung.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Buka Aksi Export'),
            ),
          ),
        ],
      ),
    );
  }
}

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.reports,
    required this.hotspots,
    required this.currentPosition,
    required this.onRefreshLocation,
  });

  final List<Report> reports;
  final List<Hotspot> hotspots;
  final Position? currentPosition;
  final Future<void> Function() onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    final circles = hotspots
        .map(
          (h) => CircleMarker(
            point: LatLng(h.latitude, h.longitude),
            radius: 80,
            color: Colors.red.withAlpha((0.18 * 255).round()),
            borderColor: Colors.red.shade600,
            borderStrokeWidth: 2,
          ),
        )
        .toList();

    final markers = <Marker>[
      if (currentPosition != null)
        Marker(
          point: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Colors.blue),
        ),
      ...reports.map(
        (r) => Marker(
          point: LatLng(r.latitude, r.longitude),
          width: 42,
          height: 42,
          child: Tooltip(
            message: '${r.jenis}\n${r.status.label}',
            child: const Icon(Icons.location_on, color: Colors.red),
          ),
        ),
      ),
    ];

    final center = currentPosition != null
        ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
        : (reports.isNotEmpty
            ? LatLng(reports.first.latitude, reports.first.longitude)
            : const LatLng(-6.2000, 106.8166));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: onRefreshLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Segarkan lokasi'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openNearestNavigation(),
                icon: const Icon(Icons.directions),
                label: const Text('Arahkan ke laporan terdekat'),
              ),
              const Spacer(),
              if (hotspots.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${hotspots.length} titik rawan',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.siagakota',
                maxZoom: 19,
              ),
              if (circles.isNotEmpty) CircleLayer(circles: circles),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
      ],
    );
  }

  void _openNearestNavigation() async {
    if (currentPosition == null || reports.isEmpty) return;
    final nearest = _nearestReport();
    final lat = nearest.latitude;
    final lng = nearest.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Report _nearestReport() {
    final d = Distance();
    final origin = LatLng(
      currentPosition!.latitude,
      currentPosition!.longitude,
    );
    Report? nearest;
    double best = double.infinity;
    for (final r in reports) {
      final dist = d(origin, LatLng(r.latitude, r.longitude));
      if (dist < best) {
        best = dist;
        nearest = r;
      }
    }
    return nearest ?? reports.first;
  }
}

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  ReportStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.isAdmin) {
      // Jika bukan admin, kembali ke beranda.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          IconButton(
            tooltip: 'Reset filter',
            icon: const Icon(Icons.filter_alt_off),
            onPressed:
                _filter == null ? null : () => setState(() => _filter = null),
          ),
        ],
      ),
      body: Consumer<ReportController>(
        builder: (context, rc, child) {
          final list = [...rc.reports]..sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
            );
          Iterable<Report> filtered = list;
          if (_filter != null) {
            filtered = filtered.where((r) => r.status == _filter);
          }
          final auth = context.read<AuthController>();
          filtered = filtered.where((r) => r.kecamatan == auth.adminKecamatan);
          final filteredList = filtered.toList();

          final total = rc.reports.length;
          final selesai =
              rc.reports.where((r) => r.status == ReportStatus.selesai).length;
          final proses =
              rc.reports.where((r) => r.status == ReportStatus.proses).length;
          final diterima =
              rc.reports.where((r) => r.status == ReportStatus.diterima).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  _AdminStat(label: 'Total', value: '$total'),
                  const SizedBox(width: 10),
                  _AdminStat(label: 'Diterima', value: '$diterima'),
                  const SizedBox(width: 10),
                  _AdminStat(label: 'Proses', value: '$proses'),
                  const SizedBox(width: 10),
                  _AdminStat(label: 'Selesai', value: '$selesai'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Filter status:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  DropdownButton<ReportStatus?>(
                    value: _filter,
                    hint: const Text('Semua'),
                    onChanged: (val) => setState(() => _filter = val),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Semua'),
                      ),
                      ...ReportStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 4),
              if (filteredList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child:
                      Center(child: Text('Belum ada laporan untuk ditinjau')),
                )
              else
                ...filteredList.map(
                  (r) => _AdminCard(
                    report: r,
                    onSetStatus: (status) => rc.updateStatus(r.id, status),
                    onDelete: () => rc.deleteReport(
                      id: r.id,
                      isAdmin: true,
                      requester: auth.userName,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminStat extends StatelessWidget {
  const _AdminStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.report,
    required this.onSetStatus,
    required this.onDelete,
  });

  final Report report;
  final void Function(ReportStatus) onSetStatus;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy • HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  report.jenis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                StatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatter.format(report.createdAt),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Text(report.deskripsi),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.person,
                  label: report.nama,
                ),
                _InfoChip(
                  icon: Icons.map,
                  label: report.kecamatan,
                ),
                _InfoChip(
                  icon: Icons.location_on,
                  label:
                      '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                ),
                _InfoChip(
                  icon: Icons.priority_high,
                  label: 'Severity ${report.severity.toStringAsFixed(1)}',
                ),
                _InfoChip(
                  icon: Icons.how_to_vote,
                  label: '${report.votes} dukungan',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusButton(
                  target: ReportStatus.diterima,
                  current: report.status,
                  label: 'Diterima',
                  color: Colors.orange,
                  onTap: () => onSetStatus(ReportStatus.diterima),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  target: ReportStatus.proses,
                  current: report.status,
                  label: 'Proses',
                  color: Colors.blue,
                  onTap: () => onSetStatus(ReportStatus.proses),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  target: ReportStatus.selesai,
                  current: report.status,
                  label: 'Selesai',
                  color: Colors.green,
                  onTap: () => onSetStatus(ReportStatus.selesai),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade200),
                ),
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus laporan?'),
        content: const Text('Data laporan akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await onDelete();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(ok ? 'Laporan berhasil dihapus' : 'Gagal menghapus laporan'),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.target,
    required this.current,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final ReportStatus target;
  final ReportStatus current;
  final String label;
  final MaterialColor color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = target == current;
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor: active
              ? color.withAlpha((0.14 * 255).round())
              : Colors.grey.shade100,
          foregroundColor: active ? color.shade700 : Colors.black87,
        ),
        onPressed: active ? null : onTap,
        child: Text(label),
      ),
    );
  }
}

enum LocationLabelMode { street, coordinate }

class ReportFormPage extends StatefulWidget {
  const ReportFormPage({super.key, this.draft});

  final ReportDraft? draft;

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final deskripsiController = TextEditingController();
  String jenis = 'Banjir';
  double severity = 3;
  String _selectedKecamatan = kecamatanPalembang.first;
  Position? position;
  String? _alamatJalan;
  bool _alamatLoading = false;
  LocationLabelMode _locationLabelMode = LocationLabelMode.coordinate;
  String? fotoPath;
  Uint8List? fotoBytes;
  bool loadingLocation = false;

  @override
  void dispose() {
    namaController.dispose();
    deskripsiController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    if (d != null) {
      namaController.text = d.nama;
      deskripsiController.text = d.deskripsi;
      jenis = d.jenis;
      severity = d.severity;
      _selectedKecamatan = d.kecamatan;
      if (d.fotoPath != null) fotoPath = d.fotoPath;
      if (d.fotoBase64 != null) {
        fotoBytes = base64Decode(d.fotoBase64!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Laporan')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama Pelapor'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Masukkan nama' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: jenis,
                decoration: const InputDecoration(labelText: 'Jenis laporan'),
                items: const [
                  DropdownMenuItem(value: 'Banjir', child: Text('Banjir')),
                  DropdownMenuItem(
                    value: 'Infrastruktur Rusak',
                    child: Text('Infrastruktur Rusak'),
                  ),
                  DropdownMenuItem(
                    value: 'Pohon Tumbang',
                    child: Text('Pohon tumbang'),
                  ),
                ],
                onChanged: (val) => setState(() => jenis = val ?? 'Banjir'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedKecamatan,
                decoration: const InputDecoration(labelText: 'Kecamatan'),
                items: kecamatanPalembang
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(k),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(
                    () => _selectedKecamatan = val ?? kecamatanPalembang.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: deskripsiController,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Masukkan deskripsi' : null,
              ),
              const SizedBox(height: 12),
              Text('Tingkat keparahan'),
              Slider(
                value: severity,
                min: 1,
                max: 5,
                divisions: 4,
                label: severity.toStringAsFixed(1),
                onChanged: (val) => setState(() => severity = val),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: loadingLocation ? null : _ambilLokasi,
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        loadingLocation ? 'Mengambil...' : 'Ambil lokasi GPS',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pilihLokasiDiPeta,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Pilih di peta'),
                    ),
                  ),
                ],
              ),
              if (position != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tampilan lokasi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<LocationLabelMode>(
                        segments: const [
                          ButtonSegment(
                            value: LocationLabelMode.street,
                            icon: Icon(Icons.route),
                            label: Text('Nama jalan'),
                          ),
                          ButtonSegment(
                            value: LocationLabelMode.coordinate,
                            icon: Icon(Icons.pin_drop),
                            label: Text('Koordinat'),
                          ),
                        ],
                        selected: {_locationLabelMode},
                        onSelectionChanged: (values) {
                          if (values.isEmpty) return;
                          _onLocationModeChanged(values.first);
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildLocationPreview(),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFoto,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Tambah foto'),
                  ),
                  const SizedBox(width: 12),
                  if (fotoPath != null)
                    Expanded(
                      child: Text(
                        File(fotoPath!).path.split(Platform.pathSeparator).last,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (fotoBytes != null)
                    const Expanded(
                      child: Text(
                        'Foto terpilih',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (fotoPath != null || fotoBytes != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: fotoBytes != null
                        ? Image.memory(
                            fotoBytes!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Foto tidak dapat dimuat'),
                            ),
                          )
                        : Image.file(
                            File(fotoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Foto tidak dapat dimuat'),
                            ),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveDraft,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Simpan draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Kirim laporan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ambilLokasi() async {
    setState(() => loadingLocation = true);
    try {
      final pos = await _getPrecisePosition();
      if (pos == null) return;
      await _setPosition(pos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal ambil lokasi: $e')));
    } finally {
      if (mounted) {
        setState(() => loadingLocation = false);
      }
    }
  }

  Future<void> _setPosition(Position pos) async {
    if (!mounted) return;
    setState(() {
      position = pos;
      if (_locationLabelMode == LocationLabelMode.coordinate) {
        _alamatJalan = null;
        _alamatLoading = false;
      }
    });
    if (_locationLabelMode == LocationLabelMode.street) {
      await _fetchAlamat(pos);
    }
  }

  Future<void> _fetchAlamat(Position pos) async {
    setState(() {
      _alamatLoading = true;
      _alamatJalan = null;
    });
    try {
      final places = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        if (places.isNotEmpty) {
          final p = places.first;
          final parts = [
            if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
            if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
            if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          ];
          _alamatJalan = parts.isEmpty ? null : parts.join(', ');
        } else {
          _alamatJalan = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _alamatJalan = null);
    } finally {
      if (mounted) {
        setState(() => _alamatLoading = false);
      }
    }
  }

  void _onLocationModeChanged(LocationLabelMode mode) {
    if (_locationLabelMode == mode) return;
    setState(() => _locationLabelMode = mode);
    if (mode == LocationLabelMode.street &&
        position != null &&
        _alamatJalan == null) {
      _fetchAlamat(position!);
    }
  }

  Widget _buildLocationPreview() {
    if (position == null) {
      return const SizedBox.shrink();
    }
    String label;
    if (_locationLabelMode == LocationLabelMode.street) {
      if (_alamatLoading) {
        label = 'Mengambil nama jalan...';
      } else {
        label = _alamatJalan ?? 'Nama jalan belum tersedia';
      }
    } else {
      label =
          '${position!.latitude.toStringAsFixed(4)}, ${position!.longitude.toStringAsFixed(4)}';
    }
    return Row(
      children: [
        Icon(Icons.place, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pilihLokasiDiPeta() async {
    final initial = position != null
        ? LatLng(position!.latitude, position!.longitude)
        : null;
    final selected = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(initialCenter: initial),
      ),
    );
    if (selected == null) return;
    await _setPosition(_positionFromLatLng(selected));
  }

  Position _positionFromLatLng(LatLng point) {
    return Position(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      floor: null,
      isMocked: false,
    );
  }

  Future<Position?> _getPrecisePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktifkan layanan lokasi')),
        );
      }
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 8),
      );
    } on TimeoutException catch (_) {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final source = await _selectSource();
    if (source == null) return;

    final file = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) return;

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      setState(() {
        fotoBytes = bytes;
        fotoPath = null;
      });
    } else {
      setState(() {
        fotoPath = file.path;
        fotoBytes = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (position == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          const SnackBar(content: Text('Pilih lokasi terlebih dahulu')));
      return;
    }
    if ((jenis == 'Infrastruktur Rusak' || jenis == 'Pohon Tumbang') &&
        fotoPath == null &&
        fotoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jenis ini memerlukan foto')),
      );
      return;
    }

    final controller = context.read<ReportController>();
    final auth = context.read<AuthController>();
    await controller.addReport(
      nama: namaController.text,
      jenis: jenis,
      deskripsi: deskripsiController.text,
      severity: severity,
      kecamatan: _selectedKecamatan,
      owner: auth.userName ?? namaController.text,
      position: position!,
      fotoPath: fotoPath,
      fotoBytes: fotoBytes,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _saveDraft() async {
    final draft = ReportDraft(
      nama: namaController.text,
      jenis: jenis,
      deskripsi: deskripsiController.text,
      severity: severity,
      kecamatan: _selectedKecamatan,
      fotoPath: fotoPath,
      fotoBase64: fotoBytes != null ? base64Encode(fotoBytes!) : null,
    );
    final controller = context.read<ReportController>();
    await controller.addDraft(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft disimpan')));
    Navigator.pop(context);
  }

  Future<ImageSource?> _selectSource() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Ambil dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }
}
