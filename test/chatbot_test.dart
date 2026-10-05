import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siagakota/controllers/index.dart';
import 'package:siagakota/models/index.dart';
import 'package:siagakota/services/index.dart';
import 'package:siagakota/widgets/chatbot.dart';

/// Layanan lingkungan tiruan yang mengembalikan data tetap, supaya jawaban
/// bot bisa diuji tanpa jaringan. Dipakai untuk memastikan bot menyusun
/// kalimat yang wajar dari data nyata.
class LayananUji extends EnvironmentService {
  @override
  Future<DataCuaca?> ambilCuaca(double lat, double lon) async =>
      DataCuaca.fromJson({
        'current': {
          'time': '2026-10-05T20:30',
          'temperature_2m': 28.1,
          'apparent_temperature': 30.8,
          'relative_humidity_2m': 68,
          'precipitation': 0.0,
          'weather_code': 3,
          'wind_speed_10m': 14.0,
          'wind_direction_10m': 110,
          'cloud_cover': 75,
          'pressure_msl': 1012.0,
        },
        'daily': {
          'time': ['2026-10-05', '2026-10-06'],
          'weather_code': [3, 80],
          'temperature_2m_max': [37.0, 36.0],
          'temperature_2m_min': [25.0, 24.0],
          'precipitation_sum': [0.0, 30.0],
          'precipitation_probability_max': [10, 70],
        },
      });

  @override
  Future<KualitasUdara?> ambilKualitasUdara(double lat, double lon) async =>
      KualitasUdara.fromJson({
        'current': {
          'time': '2026-10-05T20:00',
          'pm10': 91.7,
          'pm2_5': 86.1,
          'carbon_monoxide': 800.0,
          'nitrogen_dioxide': 11.0,
          'sulphur_dioxide': 29.0,
          'ozone': 200.0,
          'us_aqi': 196,
          'european_aqi': 124,
          'uv_index': 0.0,
        },
      });

  @override
  Future<GempaTerkini?> ambilGempaTerkini() async => GempaTerkini.fromJson({
        'Infogempa': {
          'gempa': {
            'Tanggal': '05 Okt 2026',
            'Jam': '20:06:22 WIB',
            'Magnitude': '3.8',
            'Kedalaman': '8 km',
            'Wilayah':
                'Pusat gempa berada di darat 42 km timur laut Ruteng, Manggarai',
            'Potensi': 'Gempa ini dirasakan untuk diteruskan pada masyarakat',
            'Lintang': '8.27 LS',
            'Bujur': '120.62 BT',
          },
        },
      });
}

void main() {
  // ReportController membaca SharedPreferences saat dibuat; di lingkungan tes
  // plugin itu tidak ada, jadi perlu nilai tiruan agar tidak melempar galat.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget bungkus(EnvironmentController env, ReportController rep) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ReportController>.value(value: rep),
          ChangeNotifierProvider<EnvironmentController>.value(value: env),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(right: 16, bottom: 16, child: SiagaBotWidget()),
              ],
            ),
          ),
        ),
      );

  Future<void> bukaBot(WidgetTester tester, EnvironmentController env,
      ReportController rep) async {
    await tester.pumpWidget(bungkus(env, rep));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  Future<void> tanya(WidgetTester tester, String teks) async {
    await tester.enterText(find.byType(TextField), teks);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    // Balasan bot disusun secara asinkron; beri jeda waktu nyata agar
    // gelembung jawaban sempat muncul sebelum diperiksa.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('Chatbot — dasar', () {
    late EnvironmentController env;
    late ReportController rep;

    setUp(() {
      env = EnvironmentController(service: LayananUji());
      rep = ReportController();
    });

    testWidgets('Jendela obrolan terbuka dengan sapaan awal', (tester) async {
      await bukaBot(tester, env, rep);
      expect(find.text('Asisten Laporan Warga'), findsOneWidget);
      expect(find.textContaining('Halo!'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Pertanyaan cuaca dijawab tanpa pesan error', (tester) async {
      await bukaBot(tester, env, rep);
      await tanya(tester, 'bagaimana cuaca hari ini?');
      expect(find.text('bagaimana cuaca hari ini?'), findsOneWidget);
      expect(find.textContaining('Code:'), findsNothing);
      expect(find.textContaining('kesalahan koneksi'), findsNothing);
      expect(find.textContaining('simulasi'), findsNothing);
    });

    testWidgets('Tombol kirim tidak mengirim pesan kosong', (tester) async {
      await bukaBot(tester, env, rep);
      final sebelum = tester.widgetList(find.byType(Container)).length;
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(tester.widgetList(find.byType(Container)).length, sebelum);
    });
  });

  group('Chatbot — kalimat jawaban enak dibaca', () {
    late EnvironmentController env;
    late ReportController rep;

    setUp(() async {
      env = EnvironmentController(service: LayananUji());
      rep = ReportController();
      // Muat data tiruan supaya jawaban memakai angka nyata.
      await env.muatSemua(lat: -2.9761, lon: 104.7754);
    });

    testWidgets('Jawaban cuaca berupa kalimat, bukan tempelan data',
        (tester) async {
      await bukaBot(tester, env, rep);
      await tanya(tester, 'cuaca hari ini bagaimana?');

      // Harus memakai kata satuan yang wajar...
      expect(find.textContaining('derajat Celsius'), findsOneWidget);
      expect(find.textContaining('kilometer per jam'), findsOneWidget);
      // ...dan bukan simbol/label mentah dari data API.
      expect(find.textContaining('28.1°C'), findsNothing);
      expect(find.textContaining('km/j dari'), findsNothing);
    });

    testWidgets('Jawaban kualitas udara memakai kalimat & saran',
        (tester) async {
      await bukaBot(tester, env, rep);
      await tanya(tester, 'udara di sini bagaimana?');

      expect(find.textContaining('Kualitas udara saat ini tergolong'),
          findsOneWidget);
      expect(find.textContaining('mikrogram per meter kubik'), findsOneWidget);
      expect(find.textContaining('AQI 196'), findsOneWidget);
    });

    testWidgets('Jawaban gempa menyebut magnitudo & wilayah', (tester) async {
      await bukaBot(tester, env, rep);
      await tanya(tester, 'ada gempa terbaru?');

      expect(find.textContaining('magnitudo 3.8'), findsOneWidget);
      expect(find.textContaining('Ruteng'), findsOneWidget);
      // Nama tempat tidak boleh dihuruf-kecilkan.
      expect(find.textContaining('ruteng'), findsNothing);
      // Teks mentah BMKG yang membingungkan tidak boleh muncul apa adanya.
      expect(find.textContaining('untuk diteruskan pada masyarakat'),
          findsNothing);
      expect(find.textContaining('dirasakan warga'), findsOneWidget);
    });

    testWidgets('Tanpa laporan, bot mengarahkan membuat laporan',
        (tester) async {
      await bukaBot(tester, env, rep);
      await tanya(tester, 'ada laporan apa saja?');

      expect(find.textContaining('belum ada laporan'), findsOneWidget);
      expect(find.textContaining('Buat Laporan'), findsOneWidget);
    });

    testWidgets('Pertanyaan bebas tetap dijawab, tidak menggantung',
        (tester) async {
      await bukaBot(tester, env, rep);
      await tanya(tester, 'apa kabar hari ini');
      expect(find.textContaining('Code:'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
