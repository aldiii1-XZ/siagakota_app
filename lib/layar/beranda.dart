/// SiagaKota — beranda.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../controllers/index.dart';
import '../layar/admin.dart';
import '../layar/auth_gate.dart';
import '../layar/dasbor.dart';
import '../layar/form_laporan.dart';
import '../layar/laporan.dart';
import '../layar/peta.dart';
import '../update_service.dart';
import '../widgets/chatbot.dart';

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
    if (!mounted) return;
    if (ok) {
      await _ambilLokasiAwal();
    } else {
      // Izin lokasi ditolak: tetap tampilkan data lingkungan memakai
      // titik pusat Kota Palembang agar dashboard tidak kosong.
      context.read<EnvironmentController>().muatSemua(
            lat: -2.9761,
            lon: 104.7754,
          );
    }
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: GestureDetector(
            onTap: () async {
              auth.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthGate()), (r) => false);
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withAlpha(60), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SiagaKota', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.3)),
            Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
                const SizedBox(width: 5),
                Text(auth.isAdmin ? 'PUSAT KOMANDO' : 'PORTAL WARGA',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
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
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelPage())),
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              label: Text(auth.adminKecamatan ?? 'Panel'),
              style: TextButton.styleFrom(foregroundColor: Colors.blueGrey.shade800),
            ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: () {
              auth.logout();
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (route) => false);
            },
            icon: const Icon(Icons.logout_rounded, size: 20),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SiagaBotWidget(),
          const SizedBox(height: 12),
          if (!auth.isAdmin)
            FloatingActionButton.extended(
              heroTag: 'report_fab',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportFormPage()));
              },
              icon: const Icon(Icons.add),
              label: const Text('Buat Laporan'),
              backgroundColor: const Color(0xFF4F46E5),
            ),
        ],
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
      // Muat data lingkungan (cuaca, kualitas udara, gempa) untuk titik ini.
      if (mounted) {
        context.read<EnvironmentController>().muatSemua(
              lat: pos.latitude,
              lon: pos.longitude,
            );
      }
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

// ═══════════════════════════════════════════════════════
// SIAGABOT WIDGET — AI Chatbot Floating
// ═══════════════════════════════════════════════════════

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

// ═══════════════════════════════════════
// RADAR SENTIMEN PUBLIK PANEL (Petugas)
// ═══════════════════════════════════════
