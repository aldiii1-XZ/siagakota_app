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
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final NotificationService notificationService = NotificationService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  notificationService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ReportController()),
      ],
      child: const SiagaKotaApp(),
    ),
  );
}

class AuthController extends ChangeNotifier {
  String? _userName;
  List<String> _accounts = [];
  bool _ready = false;
  bool _isAdmin = false;
  String? _adminKecamatan;

  String? get userName => _userName;
  List<String> get accounts => List.unmodifiable(_accounts);
  bool get isReady => _ready;
  bool get isLoggedIn => _userName != null;
  bool get isAdmin => _isAdmin;
  String? get adminKecamatan => _adminKecamatan;

  AuthController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accounts = prefs.getStringList('accounts') ?? [];
      _userName = prefs.getString('lastUser');
    } catch (e) {
      // Jika gagal baca prefs, tetap lanjut dengan data kosong agar UI tidak hang.
      _accounts = [];
      _userName = null;
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> _persistAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('accounts', _accounts);
    } catch (_) {
      // Abaikan kegagalan penyimpanan, biarkan berjalan tanpa persistensi.
    }
  }

  Future<void> _persistLastUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userName == null) {
        await prefs.remove('lastUser');
      } else {
        await prefs.setString('lastUser', _userName!);
      }
    } catch (_) {
      // Abaikan kegagalan penyimpanan, biarkan berjalan tanpa persistensi.
    }
  }

  Future<void> createAccount(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _userName = clean;
    if (!_accounts.contains(clean)) {
      _accounts.add(clean);
    }
    await _persistAccounts();
    await _persistLastUser();
    notifyListeners();
  }

  Future<void> loginWithExisting(String name) async {
    if (!_accounts.contains(name)) return;
    _userName = name;
    await _persistLastUser();
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
    notifyListeners();
    return true;
  }

  void logout() {
    _userName = null;
    _isAdmin = false;
    _adminKecamatan = null;
    _persistLastUser();
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xFFF7F8FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0.6,
          foregroundColor: Colors.black87,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          extendedPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
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
        return Colors.orange.shade600;
      case ReportStatus.proses:
        return Colors.blue.shade600;
      case ReportStatus.selesai:
        return Colors.green.shade600;
    }
  }
}

Color severityColor(double severity) {
  if (severity >= 4) return Colors.red.shade600;
  if (severity >= 3) return Colors.deepOrange.shade400;
  if (severity >= 2) return Colors.amber.shade600;
  return Colors.green.shade600;
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
        status: ReportStatus.values
            .firstWhere((e) => e.name == json['status'], orElse: () => ReportStatus.diterima),
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
  final List<Report> _reports = [];
  final _uuid = const Uuid();
  final List<Report> _sortedCache = [];
  bool _sortedDirty = true;
  final List<ReportDraft> _drafts = [];
  bool _draftLoaded = false;

  ReportController() {
    loadDrafts();
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
    notifyListeners();
  }

  Report? _findDuplicate(Report incoming) {
    const radiusMeters = 200.0;
    const timeWindow = Duration(hours: 2);
    for (final r in _reports) {
      final sameType = r.jenis == incoming.jenis;
      final closeBy =
          Geolocator.distanceBetween(
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
  Position? _currentPosition;
  bool _locLoading = false;
  String? _locError;
  String? _locLabel;
  bool _permAsked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initLocationFlow();
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final reportsProvider = context.watch<ReportController>();
    final visibleReports = auth.isAdmin
        ? reportsProvider.reports
            .where((r) => r.kecamatan == auth.adminKecamatan)
            .toList()
        : reportsProvider.reports.where((r) => r.owner == auth.userName).toList();
    final hotspots = auth.isAdmin
        ? reportsProvider.computeHotspots(minCount: 3)
        : reportsProvider.computeHotspots(
            source: visibleReports,
            minCount: 3,
          );
    return Scaffold(
      appBar: AppBar(
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
              style: TextButton.styleFrom(foregroundColor: Colors.blueGrey.shade800),
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
            Tab(text: 'Laporan'),
            Tab(text: 'Dashboard'),
            Tab(text: 'Peta'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const ReportListView(),
          const DashboardView(),
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
    if (_permAsked) return true;
    _permAsked = true;

    Future<bool> request() async {
      final res = await Geolocator.requestPermission();
      return res == LocationPermission.always ||
          res == LocationPermission.whileInUse;
    }

    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.always ||
        status == LocationPermission.whileInUse) {
      return true;
    }

    if (!mounted) return false;
    final granted =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Izinkan lokasi'),
            content: const Text(
              'Kami memerlukan akses lokasi untuk menunjukkan laporan terdekat dan mengisi koordinat Anda secara otomatis.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx, false);
                },
                child: const Text('Tolak'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final res = await request();
                  if (!context.mounted) return;
                  Navigator.pop(ctx, res);
                },
                child: const Text('Izinkan'),
              ),
            ],
          ),
        ) ??
        false;

    if (!granted) {
      _locError = 'Izin lokasi ditolak';
      _showLocError();
      return false;
    }
    return true;
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

  @override
  void dispose() {
    controller.dispose();
    adminPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final hasAccounts = auth.accounts.isNotEmpty;
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_person, size: 64, color: Colors.blue),
                    const SizedBox(height: 12),
                    Text(
                      'Masuk ke SiagaKota',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasAccounts
                          ? 'Pilih akun yang sudah dibuat atau tambahkan akun baru.'
                          : 'Buat akun terlebih dahulu agar laporan bisa tersimpan.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Masuk sebagai Admin'),
                      onPressed: _openAdminLogin,
                    ),
                    const SizedBox(height: 16),
                    if (hasAccounts) ...[
                      Text(
                        'Pilih akun',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: auth.accounts
                            .map(
                              (name) => ElevatedButton.icon(
                                icon: const Icon(Icons.person),
                                label: Text(name),
                                onPressed: () async {
                                  await auth.loginWithExisting(name);
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const AuthGate(),
                                    ),
                                    (route) => false,
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Buat akun baru',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Nama akun',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _createAccount(auth),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Simpan & Masuk'),
                      onPressed: () => _createAccount(auth),
                    ),
                  ],
                ),
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
    await auth.createAccount(name);
    if (!mounted) return;
    controller.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
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
                  value: _adminKecamatan,
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
                  onChanged: (val) => _adminKecamatan = val ?? kecamatanPalembang.first,
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
                  final ok = await auth.loginAsAdmin(
                    password: adminPassController.text,
                    kecamatan: _adminKecamatan,
                  );
                  if (!mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password admin salah')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('Belum ada laporan'),
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
                if (auth.isAdmin)
                  PopupMenuButton<ReportStatus>(
                    tooltip: 'Ubah status',
                    onSelected: (val) => controller.updateStatus(report.id, val),
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
            : controller.reports.where((r) => r.owner == auth.userName).toList();
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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Ringkasan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(title: 'Total laporan', value: '$total'),
                _StatCard(title: 'Diterima', value: '$diterima'),
                _StatCard(title: 'Proses', value: '$proses'),
                _StatCard(title: 'Selesai', value: '$selesai'),
              ],
            ),
            const SizedBox(height: 20),
            Text('Per jenis', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...perJenis.entries.map(
              (e) => ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(e.key),
                trailing: Text('${e.value}'),
              ),
            ),
            const SizedBox(height: 20),
            if (hotspots.isNotEmpty) ...[
              Text(
                'Wilayah rawan (≥3 laporan dalam radius ~1km)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...hotspots.take(5).map(
                (h) => ListTile(
                  leading: const Icon(Icons.warning_amber, color: Colors.red),
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
            ElevatedButton.icon(
              onPressed: () => _showExportSheet(context),
              icon: const Icon(Icons.download),
              label: const Text('Export / Print'),
            ),
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
            color: Colors.red.withOpacity(0.18),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red, size: 18),
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
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            onPressed: _filter == null ? null : () => setState(() => _filter = null),
          ),
        ],
      ),
      body: Consumer<ReportController>(
        builder: (_, rc, __) {
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
          final selesai = rc.reports.where((r) => r.status == ReportStatus.selesai).length;
          final proses = rc.reports.where((r) => r.status == ReportStatus.proses).length;
          final diterima = rc.reports.where((r) => r.status == ReportStatus.diterima).length;

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
                  const Text('Filter status:', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  child: Center(child: Text('Belum ada laporan untuk ditinjau')),
                )
              else
                ...filteredList.map(
                  (r) => _AdminCard(
                    report: r,
                    onSetStatus: (status) => rc.updateStatus(r.id, status),
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
  const _AdminCard({required this.report, required this.onSetStatus});

  final Report report;
  final void Function(ReportStatus) onSetStatus;

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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          ],
        ),
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
          backgroundColor: active ? color.withOpacity(0.14) : Colors.grey.shade100,
          foregroundColor: active ? color.shade700 : Colors.black87,
        ),
        onPressed: active ? null : onTap,
        child: Text(label),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
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
                value: _selectedKecamatan,
                decoration: const InputDecoration(labelText: 'Kecamatan'),
                items: kecamatanPalembang
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(k),
                      ),
                    )
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedKecamatan = val ?? kecamatanPalembang.first),
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
    if (mode == LocationLabelMode.street && position != null && _alamatJalan == null) {
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
      ).showSnackBar(const SnackBar(content: Text('Pilih lokasi terlebih dahulu')));
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
