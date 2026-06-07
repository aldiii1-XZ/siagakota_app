import 'dart:io' show File, Platform;
import 'dart:convert';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'update_service.dart';
import 'theme.dart';
import 'components.dart';
import 'models/index.dart';
import 'controllers/index.dart';
import 'services/index.dart';

final notificationService = NotificationService();
final cloudSync = CloudSyncService();

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
class SiagaBotWidget extends StatefulWidget {
  const SiagaBotWidget({super.key});
  @override
  State<SiagaBotWidget> createState() => _SiagaBotWidgetState();
}

class _SiagaBotWidgetState extends State<SiagaBotWidget> {
  bool _isOpen = false;
  final _inputCtrl = TextEditingController();
  bool _loading = false;
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Halo! Saya Asisten Laporan Warga 🤖. Ada yang bisa saya bantu terkait informasi laporan infrastruktur atau kondisi kota hari ini?'},
  ];
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _inputCtrl.clear();
      _loading = true;
    });
    _scrollToBottom();
    
    // Ambil data laporan dari ReportController sebagai context (pengganti tools query database)
    final reportCtrl = context.read<ReportController>();
    final reportsContext = reportCtrl.reports.map((r) => 
      "- Jenis: ${r.jenis}, Waktu: ${DateFormat('dd MMM HH:mm').format(r.createdAt)}, Lokasi: ${r.kecamatan} (${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}), Status: ${r.status.label}, Detail: ${r.deskripsi}"
    ).join('\n');

    final reply = await _callLlama(text, reportsContext);
    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'text': reply ?? 'Maaf, tidak bisa memproses permintaan.'});
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<String?> _callLlama(String userMessage, String reportsContext) async {
    final apiKey = const String.fromEnvironment('LLAMA_API_KEY', defaultValue: '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');
    final apiUrl = const String.fromEnvironment('LLAMA_API_URL', defaultValue: 'https://api.openrouter.ai/api/v1/chat/completions');
    
    if (apiKey == 'YOUR_LLAMA_API_KEY' || apiKey.isEmpty) {
       await Future.delayed(const Duration(seconds: 1));
       if (userMessage.toLowerCase().contains("hujan")) {
           return "Sepertinya akan turun hujan hari ini. Harap siapkan payung dan berhati-hati di jalan ya!";
       }
       return "Maaf, saya Asisten Laporan Warga versi simulasi karena API Key Llama belum dikonfigurasi. Saya siap membantu Anda jika API Key sudah dimasukkan!";
    }

    try {
      final systemInstruction = '''Anda adalah "Asisten Laporan Warga", bot AI resmi untuk aplikasi pelaporan banjir dan kerusakan infrastruktur. 
Tugas utama Anda adalah memberikan informasi yang akurat dan *real-time* kepada pengguna berdasarkan laporan yang ada di database sistem.

PANDUAN UTAMA & BATASAN (SANGAT PENTING):
1. SUMBER KEBENARAN TUNGGAL: Anda TIDAK BOLEH mengarang, menebak, atau memprediksi kejadian banjir, cuaca, atau kerusakan infrastruktur. Anda HANYA boleh menjawab berdasarkan data laporan yang diberikan pada konteks.
2. ANTI-HALUSINASI: Jika data mengembalikan hasil kosong (tidak ada laporan relevan), Anda harus menjawab bahwa tidak ada laporan yang masuk. (Contoh: "Berdasarkan data kami, saat ini tidak ada laporan banjir di [Lokasi] untuk hari ini.").
3. JANGAN MENJAMIN KESELAMATAN: Jika tidak ada laporan, jangan pernah menyatakan bahwa area tersebut "100% aman". Cukup nyatakan bahwa "tidak ada laporan yang tercatat di sistem".
4. FORMAT JAWABAN (JIKA ADA DATA): Jika data ditemukan, berikan informasi secara ringkas dan terstruktur. Wajib mencakup:
   - Jenis Kejadian (Banjir/Jalan Rusak/dll)
   - Lokasi Spesifik
   - Waktu Laporan Masuk
   - Detail/Status (misal: "tinggi air 50cm" atau "sedang ditangani")
5. NADA BICARA: Profesional, sopan, empati, dan efisien. Jangan gunakan kalimat berbunga-bunga. Pengguna mungkin dalam kondisi darurat, jadi berikan jawaban yang langsung pada intinya.

ALUR KERJA:
- Saat pengguna bertanya, segera identifikasi parameter (kategori kejadian, lokasi, tanggal/waktu).
- Cocokkan dengan "Data Laporan Saat Ini" yang dilampirkan bersama pertanyaan.
- Terjemahkan data mentah dari konteks menjadi kalimat natural yang mudah dibaca pengguna.''';

      final promptContext = '''Data Laporan Saat Ini:
${reportsContext.isEmpty ? "Tidak ada laporan aktif di sistem." : reportsContext}

Pertanyaan Pengguna: "$userMessage"''';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'temperature': 0.7,
          'max_tokens': 800,
          'messages': [
            {'role': 'system', 'content': systemInstruction},
            {'role': 'user', 'content': promptContext},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Maaf, terjadi kesalahan dari server AI. Code: ${response.statusCode}';
      }
    } catch (e) {
      return 'Maaf, terjadi kesalahan koneksi AI: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen)
          Container(
            width: 320,
            height: 400,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF818CF8), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Asisten Laporan Warga', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        Text('Pemantauan Real-Time', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                      ])),
                      GestureDetector(
                        onTap: () => setState(() => _isOpen = false),
                        child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                ),
                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_loading && i == _messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(padding: EdgeInsets.only(bottom: 8), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))),
                        );
                      }
                      final msg = _messages[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 240),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF4F46E5) : Colors.white,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isUser ? const Radius.circular(4) : null,
                              bottomLeft: isUser ? null : const Radius.circular(4),
                            ),
                            border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(msg['text'] ?? '', style: TextStyle(fontSize: 13, color: isUser ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.w500)),
                        ),
                      );
                    },
                  ),
                ),
                // Input
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Tanya informasi kota...',
                            hintStyle: const TextStyle(fontSize: 13),
                            filled: true, fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // FAB button
        FloatingActionButton(
          heroTag: 'chatbot_fab',
          onPressed: () => setState(() => _isOpen = !_isOpen),
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Icon(_isOpen ? Icons.close_rounded : Icons.chat_bubble_rounded, color: Colors.white),
        ),
      ],
    );
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
        final canCreate = !_saving && controller.text.trim().isNotEmpty;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Stack(
            children: [
              // Background orbs
              Positioned(
                top: -80, left: -80,
                child: Container(
                  width: 360, height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF818CF8).withAlpha(50),
                      const Color(0xFF818CF8).withAlpha(0),
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: -80, right: -80,
                child: Container(
                  width: 360, height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF60A5FA).withAlpha(50),
                      const Color(0xFF60A5FA).withAlpha(0),
                    ]),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: FadeInScale(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo & Title
                            Column(
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5).withAlpha(80),
                                        blurRadius: 24, offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
                                ),
                                const SizedBox(height: 20),
                                RichText(
                                  text: const TextSpan(
                                    text: 'SiagaKota',
                                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
                                    children: [
                                      TextSpan(text: '.', style: TextStyle(color: Color(0xFF2563EB))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Platform Tata Kota & Pengaduan Cerdas',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 36),
                            // Glass card
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(220),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: Colors.white.withAlpha(180)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(12),
                                    blurRadius: 40, offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Officer portal button
                                  _buildAdminEntryCard(),
                                  const SizedBox(height: 24),
                                  // Divider
                                  Row(
                                    children: [
                                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text('AKSES WARGA', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFCBD5E1), letterSpacing: 2)),
                                      ),
                                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Existing accounts
                                  if (hasAccounts) ...[
                                    ...auth.accounts.map((name) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _buildAccountCard(
                                        name: name,
                                        onTap: () async {
                                          await auth.loginWithExisting(name);
                                          if (!context.mounted) return;
                                          Navigator.of(context).pushAndRemoveUntil(
                                            MaterialPageRoute(builder: (_) => const AuthGate()),
                                            (route) => false,
                                          );
                                        },
                                      ),
                                    )),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text('BUAT AKUN BARU', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFCBD5E1), letterSpacing: 2)),
                                        ),
                                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildNameField(),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 58,
                                    child: FilledButton.icon(
                                      icon: _saving
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.person_add_alt_1_rounded),
                                      label: Text(_saving ? 'Menyimpan...' : 'Simpan & Masuk'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: canCreate ? const Color(0xFF4F46E5) : const Color(0xFFD9E3F1),
                                        foregroundColor: canCreate ? Colors.white : const Color(0xFF8FA4C3),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                      onPressed: canCreate ? () => _createAccount(auth) : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              '© 2026 SIAGAKOTA PALEMBANG',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), letterSpacing: 2.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openAdminLogin,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(60),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Masuk Portal Petugas',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withAlpha(15),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_circle_outlined, color: Color(0xFF4F46E5), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
                        const SizedBox(width: 5),
                        const Text('Terverifikasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
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
}
class ReportListView extends StatelessWidget {
  const ReportListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (context, controller, _) {
        final auth = context.watch<AuthController>();
        final items = auth.isAdmin
            ? (auth.adminKecamatan == 'SEMUA WILAYAH' || auth.adminKecamatan == null
                ? controller.sortedReports
                : controller.sortedReports
                    .where((r) => r.kecamatan == auth.adminKecamatan)
                    .toList())
            : controller.sortedReports
                .where((r) => r.owner == auth.userName || r.jenis == 'Pengumuman')
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
    
    final isSos = report.jenis == 'Darurat SOS';
    final isPengumuman = report.jenis == 'Pengumuman';

    return Card(
      color: isSos ? const Color(0xFFFEF2F2) : (isPengumuman ? const Color(0xFFFFFBEB) : Colors.white),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isSos ? const BorderSide(color: Color(0xFFFECACA), width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatter.format(report.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.deskripsi,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF334155),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
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
            if (report.photoUrl != null || report.fotoBytes != null || report.fotoPath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: report.photoUrl != null
                      ? Image.network(
                          report.photoUrl!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _imageError(),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 220,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        )
                      : report.fotoBytes != null
                          ? Image.memory(
                              report.fotoBytes!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _imageError(),
                            )
                          : Image.file(
                              File(report.fotoPath!),
                              height: 220,
                              width: double.infinity,
                              cacheHeight: 1080,
                              cacheWidth: 1920,
                              filterQuality: FilterQuality.high,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _imageError(),
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
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Bagikan laporan',
                  onPressed: () {
                    final shareText = '🚨 [Info Warga] Laporan ${report.jenis} di ${report.kecamatan}!\n\n'
                        'Detail: ${report.deskripsi}\n'
                        'Lokasi: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}\n\n'
                        'Bantu upvote laporan ini di aplikasi SiagaKota agar segera ditangani!\n'
                        'Cek detailnya di: https://siagakota.id/report/${report.id}';
                    Share.share(shareText);
                  },
                  icon: const Icon(Icons.share_outlined),
                  color: Colors.blueGrey,
                ),
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

  Widget _imageError() => Container(
        height: 220,
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.blueGrey.shade300),
            const SizedBox(height: 8),
            Text('Foto tidak tersedia', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12)),
          ],
        ),
      );
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

// ═══════════════════════════════════════
// RADAR SENTIMEN PUBLIK PANEL (Petugas)
// ═══════════════════════════════════════
class _RadarSentimenPanel extends StatelessWidget {
  const _RadarSentimenPanel({required this.reportCount, required this.urgentCount});
  final int reportCount;
  final int urgentCount;

  @override
  Widget build(BuildContext context) {
    final panikPct = reportCount == 0 ? 0 : ((urgentCount / reportCount) * 100).round();
    final emosi = panikPct > 60 ? 'Panik' : panikPct > 30 ? 'Marah' : 'Netral';
    final statusStr = panikPct > 60 ? 'Kritis' : panikPct > 30 ? 'Waspada' : 'Kondusif';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withAlpha(50), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF87171), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Radar Sentimen Publik', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                child: Text(statusStr, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('STATUS EMOSI DOMINAN', style: TextStyle(color: Color(0xFF475569), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(emosi, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('TINGKAT KEPANIKAN', style: TextStyle(color: Color(0xFF475569), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const Spacer(),
              Text('$panikPct%', style: const TextStyle(color: Color(0xFFF87171), fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: panikPct / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(
                panikPct > 60 ? const Color(0xFFF87171) : const Color(0xFFFB923C),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.report_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text('$reportCount total laporan • $urgentCount urgensi tinggi',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// CCTV AI LIVE FEED PANEL (Petugas)
// ═══════════════════════════════════════
class _CctvAiFeedPanel extends StatefulWidget {
  const _CctvAiFeedPanel();

  @override
  State<_CctvAiFeedPanel> createState() => _CctvAiFeedPanelState();
}

class _CctvAiFeedPanelState extends State<_CctvAiFeedPanel> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0, end: 200).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF4F46E5).withAlpha(40), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.videocam_outlined, color: Color(0xFF818CF8), size: 18),
                ),
                const SizedBox(width: 12),
                const Text('CCTV AI Live Feed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.red.withAlpha(40), borderRadius: BorderRadius.circular(6)),
                  child: const Row(children: [
                    Icon(Icons.circle, color: Color(0xFFF87171), size: 6),
                    SizedBox(width: 5),
                    Text('LIVE', style: TextStyle(color: Color(0xFFF87171), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ]),
                ),
              ],
            ),
          ),
          // Simulated CCTV feed
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            child: Container(
              height: 200,
              color: const Color(0xFF020817),
              child: Stack(
                children: [
                  // Scan line
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanAnimation.value, left: 0, right: 0,
                        child: Container(
                          height: 2, 
                          decoration: BoxDecoration(
                            color: const Color(0xFF34D399).withAlpha(200),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF34D399).withAlpha(100), blurRadius: 10, spreadRadius: 2),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Bounding boxes
                  Positioned(
                    top: 50, left: 60,
                    child: Container(
                      width: 70, height: 50,
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF10B981), width: 1.5), color: const Color(0xFF10B981).withAlpha(25), borderRadius: BorderRadius.circular(2)),
                      child: const Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(2), child: Text('VEHICLE 98%', style: TextStyle(color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.w800)))),
                    ),
                  ),
                  Positioned(
                    top: 80, left: 160,
                    child: Container(
                      width: 100, height: 60,
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF87171), width: 1.5), color: const Color(0xFFF87171).withAlpha(40), borderRadius: BorderRadius.circular(2)),
                      child: const Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(2), child: Text('⚠ ANOMALY', style: TextStyle(color: Color(0xFFF87171), fontSize: 8, fontWeight: FontWeight.w800)))),
                    ),
                  ),
                  // Terminal log
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: const Color(0xFF0F172A).withAlpha(230),
                      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('> [14:02:11] Memindai Sektor Sudirman...', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF34D399), fontSize: 9)),
                        Text('> [14:02:15] PERINGATAN: Rintangan terdeteksi di jalur kiri.', style: TextStyle(fontFamily: 'monospace', color: Color(0xFFF87171), fontSize: 9, fontWeight: FontWeight.w700)),
                        Text('> [14:02:18] Cocok dengan laporan LAP-001.', style: TextStyle(fontFamily: 'monospace', color: Colors.white70, fontSize: 9)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
            ? (auth.adminKecamatan == 'SEMUA WILAYAH' || auth.adminKecamatan == null
                ? controller.reports
                : controller.reports
                    .where((r) => r.kecamatan == auth.adminKecamatan)
                    .toList())
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
            // RADAR SENTIMEN PUBLIK — PETUGAS ONLY
            if (auth.isAdmin) ...[
              _RadarSentimenPanel(reportCount: total, urgentCount: visible.where((r) => r.severity >= 4).length),
              const SizedBox(height: 16),
              const _CctvAiFeedPanel(),
              const SizedBox(height: 20),
            ],
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAdmin
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF4F46E5), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isAdmin ? const Color(0xFF0F172A) : const Color(0xFF4F46E5)).withAlpha(80),
            blurRadius: 24, offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat Datang, ${userName ?? (isAdmin ? 'Petugas' : 'Warga')} 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(
            isAdmin
                ? 'Kondisi sentimen warga dan laporan aktif hari ini.'
                : 'Ada masalah di fasilitas kota? Laporkan dengan mudah.',
            style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34D399))),
                  const SizedBox(width: 8),
                  Text(userName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  const Text('· Akun Terverifikasi', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
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
    final isSos = report.jenis == 'Darurat SOS';
    final isPengumuman = report.jenis == 'Pengumuman';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSos ? const Color(0xFFFEF2F2) : (isPengumuman ? const Color(0xFFFFFBEB) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isSos ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
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
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(50)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 12),
                      SizedBox(width: 4),
                      Text('Anti-Hoax: 98% Valid', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
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
                onPressed: () => _openNearestNavigation(context),
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

  void _openNearestNavigation(BuildContext context) async {
    if (currentPosition == null || reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi atau laporan belum tersedia. Coba segarkan lokasi terlebih dahulu.'),
        ),
      );
      return;
    }
    final nearest = _nearestReport();
    final lat = nearest.latitude;
    final lng = nearest.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps. Pastikan aplikasi browser atau Google Maps terinstall.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka navigasi: $e')),
        );
      }
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
          if (auth.adminKecamatan != 'SEMUA WILAYAH' && auth.adminKecamatan != null) {
            filtered = filtered.where((r) => r.kecamatan == auth.adminKecamatan);
          }
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
              const SizedBox(height: 12),
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

  // Voice to text states
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  // Vision AI state
  bool _analyzingImage = false;

  Future<void> _analyzeImage() async {
    if (fotoBytes == null && fotoPath == null) return;
    setState(() => _analyzingImage = true);
    
    try {
      final apiKey = const String.fromEnvironment('LLAMA_API_KEY', defaultValue: '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');
      final apiUrl = const String.fromEnvironment('LLAMA_API_URL', defaultValue: 'https://api.openrouter.ai/api/v1/chat/completions');
      if (apiKey == 'YOUR_LLAMA_API_KEY' || apiKey.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          deskripsiController.text = 'Terdapat kerusakan infrastruktur yang cukup parah berdasarkan foto. (Hasil Simulasi Vision AI)';
          jenis = 'Infrastruktur Rusak';
          severity = 4;
        });
      } else {
        Uint8List imageBytes;
        if (fotoBytes != null) {
          imageBytes = fotoBytes!;
        } else {
          imageBytes = await File(fotoPath!).readAsBytes();
        }
        final base64Image = base64Encode(imageBytes);

        final promptText = "Analisis foto ini untuk laporan masalah kota. Tentukan 3 hal: 1. Jenis laporan (Banjir, Infrastruktur Rusak, atau Pohon Tumbang), 2. Tingkat keparahan (angka 1 sampai 5), 3. Deskripsi singkat masalah yang terlihat. Format jawaban: 'Jenis: [jenis]\\nKeparahan: [angka]\\nDeskripsi: [deskripsi]'";

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'temperature': 0.3,
          'max_tokens': 300,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': promptText},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                  }
                ]
              }
            ],
          }),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['choices'][0]['message']['content'] ?? '';
          if (text.isNotEmpty) {
          // Parse results simple
          final lines = text.split('\n');
          String newJenis = jenis;
          double newSeverity = severity;
          String newDesc = deskripsiController.text;

          for (final line in lines) {
            if (line.toLowerCase().startsWith('jenis:')) {
              final val = line.split(':')[1].trim();
              if (['Banjir', 'Infrastruktur Rusak', 'Pohon Tumbang'].contains(val)) {
                newJenis = val;
              }
            } else if (line.toLowerCase().startsWith('keparahan:')) {
              final val = double.tryParse(line.split(':')[1].trim());
              if (val != null && val >= 1 && val <= 5) newSeverity = val;
            } else if (line.toLowerCase().startsWith('deskripsi:')) {
              newDesc = line.split(':')[1].trim();
            }
          }
          setState(() {
            jenis = newJenis;
            severity = newSeverity;
            if (deskripsiController.text.isEmpty) {
              deskripsiController.text = newDesc;
            } else {
              deskripsiController.text += '\n(AI Analysis): $newDesc';
            }
          });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menganalisis foto. Error: ${response.statusCode}')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menganalisis foto: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _analyzingImage = false);
      }
    }
  }

  @override
  void dispose() {
    namaController.dispose();
    deskripsiController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initSpeech();
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

  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (e) => debugPrint("Speech Error: $e"),
        onStatus: (s) => debugPrint("Speech Status: $s"),
      );
      setState(() {});
    } catch (e) {
      debugPrint("Speech Init Error: $e");
    }
  }

  void _startListening() async {
    await _speech.listen(onResult: _onSpeechResult);
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(dynamic result) {
    setState(() {
      // Perbarui controller deskripsi secara real-time
      deskripsiController.text = result.recognizedWords;
    });
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
                decoration: InputDecoration(
                  labelText: 'Deskripsi',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : null,
                    ),
                    onPressed: () {
                      if (!_speechEnabled) {
                        _initSpeech(); // Coba inisialisasi ulang jika gagal
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fitur suara belum siap atau izin mikrofon ditolak. Pastikan izin diberikan.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      if (_isListening) {
                        _stopListening();
                      } else {
                        _startListening();
                      }
                    },
                  ),
                ),
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _analyzingImage ? null : _analyzeImage,
                    icon: _analyzingImage 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                    label: Text(_analyzingImage ? 'Menganalisis...' : 'Analisis Foto dengan AI (Magic Autofill)'),
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
