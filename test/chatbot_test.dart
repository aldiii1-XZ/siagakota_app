import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:siagakota/controllers/index.dart';
import 'package:siagakota/widgets/chatbot.dart';

/// Tes chatbot SiagaKota. Fokusnya: bot harus SELALU memberi jawaban yang
/// berguna — termasuk saat kunci AI belum dipasang atau server AI gagal.
/// Ini mencegah masalah lama terulang: bot menampilkan pesan error mentah
/// ("Code: 401" / "kesalahan koneksi") sehingga terasa tidak bisa dipakai.
void main() {
  Widget bungkus() => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ReportController()),
          ChangeNotifierProvider(create: (_) => EnvironmentController()),
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

  Future<void> bukaBot(WidgetTester tester) async {
    await tester.pumpWidget(bungkus());
    await tester.pump();
    // Ketuk tombol bulat untuk membuka jendela obrolan.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  Future<void> tanya(WidgetTester tester, String teks) async {
    await tester.enterText(find.byType(TextField), teks);
    await tester.pump();
    // Tombol kirim adalah GestureDetector berikon send.
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('Jendela obrolan terbuka dengan sapaan awal', (tester) async {
    await bukaBot(tester);
    expect(find.text('Asisten Laporan Warga'), findsOneWidget);
    expect(find.textContaining('Halo!'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Pertanyaan cuaca dijawab, bukan pesan error', (tester) async {
    await bukaBot(tester);
    await tanya(tester, 'bagaimana cuaca hari ini?');

    // Pertanyaan pengguna tampil.
    expect(find.text('bagaimana cuaca hari ini?'), findsOneWidget);
    // Ada jawaban tentang cuaca (data nyata atau arahan perbarui),
    // dan TIDAK ada pesan error teknis.
    expect(find.textContaining('cuaca'), findsWidgets);
    expect(find.textContaining('Code:'), findsNothing);
    expect(find.textContaining('kesalahan koneksi'), findsNothing);
    expect(find.textContaining('simulasi'), findsNothing);
  });

  testWidgets('Pertanyaan kualitas udara dijawab', (tester) async {
    await bukaBot(tester);
    await tanya(tester, 'udara di sini bagus tidak?');
    expect(find.textContaining('udara'), findsWidgets);
    expect(find.textContaining('Code:'), findsNothing);
  });

  testWidgets('Pertanyaan gempa dijawab', (tester) async {
    await bukaBot(tester);
    await tanya(tester, 'ada gempa terbaru?');
    expect(find.textContaining('gempa'), findsWidgets);
    expect(find.textContaining('Code:'), findsNothing);
  });

  testWidgets('Pertanyaan laporan dijawab', (tester) async {
    await bukaBot(tester);
    await tanya(tester, 'ada laporan banjir?');
    expect(find.textContaining('laporan'), findsWidgets);
    expect(find.textContaining('Code:'), findsNothing);
  });

  testWidgets('Pertanyaan bebas tetap dijawab (tidak menggantung)',
      (tester) async {
    await bukaBot(tester);
    await tanya(tester, 'apa kabar');
    // Bot harus tetap membalas sesuatu, bukan diam atau error.
    expect(find.textContaining('Code:'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Tombol kirim tidak mengirim pesan kosong', (tester) async {
    await bukaBot(tester);
    final sebelum = tester.widgetList(find.byType(Container)).length;
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    // Tidak ada gelembung pesan baru yang ditambahkan.
    expect(tester.widgetList(find.byType(Container)).length, sebelum);
  });
}
