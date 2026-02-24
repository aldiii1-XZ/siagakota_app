import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  String? get userName => _userName;
  List<String> get accounts => List.unmodifiable(_accounts);
  bool get isReady => _ready;
  bool get isLoggedIn => _userName != null;

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

  void logout() {
    _userName = null;
    _persistLastUser();
    notifyListeners();
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

class Report {
  final String id;
  final String nama;
  final String jenis;
  final String deskripsi;
  final double latitude;
  final double longitude;
  final double severity; // 1..5
  final String? fotoPath;
  final DateTime createdAt;
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
    required this.fotoPath,
    required this.createdAt,
    this.status = ReportStatus.diterima,
    this.votes = 0,
    this.duplicateOf,
    this.weatherRisk = 0,
  });

  double get priorityScore => severity * 2 + votes + weatherRisk;
}

class ReportController extends ChangeNotifier {
  final List<Report> _reports = [];
  final _uuid = const Uuid();
  final List<Report> _sortedCache = [];
  bool _sortedDirty = true;

  List<Report> get reports => List.unmodifiable(_reports);
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
    required Position position,
    String? fotoPath,
  }) async {
    final newReport = Report(
      id: _uuid.v4(),
      nama: nama,
      jenis: jenis,
      deskripsi: deskripsi,
      latitude: position.latitude,
      longitude: position.longitude,
      severity: severity,
      fotoPath: fotoPath,
      createdAt: DateTime.now(),
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
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(
        title: Text('SiagaKota • ${auth.userName ?? 'Pengguna'}'),
        actions: [
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ReportListView(), DashboardView()],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportFormPage()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Buat Laporan'),
            )
          : null,
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

  @override
  void dispose() {
    controller.dispose();
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
                                  if (!mounted) return;
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
}

class ReportListView extends StatelessWidget {
  const ReportListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (context, controller, _) {
        final items = controller.sortedReports;

        if (items.isEmpty) {
          return const Center(child: Text('Belum ada laporan'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final report = items[index];
            return ReportCard(report: report);
          },
        );
      },
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ReportController>();
    final formatter = DateFormat('dd MMM HH:mm');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.jenis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(report.deskripsi),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _InfoChip(icon: Icons.place, label: _coordLabel(report)),
                _InfoChip(
                  icon: Icons.schedule,
                  label: formatter.format(report.createdAt),
                ),
                _InfoChip(
                  icon: Icons.emergency,
                  label: 'Severity ${report.severity.toStringAsFixed(1)}',
                ),
                if (report.duplicateOf != null)
                  _InfoChip(icon: Icons.link, label: 'Duplikasi'),
              ],
            ),
            if (report.fotoPath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(report.fotoPath!),
                  height: 140,
                  width: double.infinity,
                  cacheHeight: 720,
                  cacheWidth: 1280,
                  filterQuality: FilterQuality.medium,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    height: 140,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Text('Foto tidak dapat dimuat'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => controller.upvote(report.id),
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                ),
                Text('${report.votes}'),
                const Spacer(),
                PopupMenuButton<ReportStatus>(
                  tooltip: 'Ubah status',
                  onSelected: (val) => controller.updateStatus(report.id, val),
                  itemBuilder: (_) => ReportStatus.values
                      .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  child: const Icon(Icons.more_vert),
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

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (_, controller, child) {
        final total = controller.reports.length;
        final selesai = controller.reports
            .where((r) => r.status == ReportStatus.selesai)
            .length;
        final proses = controller.reports
            .where((r) => r.status == ReportStatus.proses)
            .length;
        final diterima = total - selesai - proses;

        Map<String, int> perJenis = {};
        for (final r in controller.reports) {
          perJenis[r.jenis] = (perJenis[r.jenis] ?? 0) + 1;
        }

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
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export CSV (mock) berhasil disiapkan'),
                  ),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Export data'),
            ),
          ],
        );
      },
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

class ReportFormPage extends StatefulWidget {
  const ReportFormPage({super.key});

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final deskripsiController = TextEditingController();
  String jenis = 'Banjir';
  double severity = 3;
  Position? position;
  String? fotoPath;
  bool loadingLocation = false;

  @override
  void dispose() {
    namaController.dispose();
    deskripsiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Laporan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
              ],
            ),
            if (position != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Lokasi: ${position!.latitude.toStringAsFixed(4)}, ${position!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.green),
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
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Kirim laporan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ambilLokasi() async {
    setState(() => loadingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktifkan layanan lokasi')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() => position = pos);
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

  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
    );
    if (file != null) {
      setState(() => fotoPath = file.path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (position == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ambil lokasi GPS dulu')));
      return;
    }

    final controller = context.read<ReportController>();
    await controller.addReport(
      nama: namaController.text,
      jenis: jenis,
      deskripsi: deskripsiController.text,
      severity: severity,
      position: position!,
      fotoPath: fotoPath,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }
}
