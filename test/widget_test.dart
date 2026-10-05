import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:siagakota/controllers/index.dart';
import 'package:siagakota/widgets/lingkungan_panel.dart';

void main() {
  testWidgets('Panel lingkungan menampilkan judul & status awal',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EnvironmentController(),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PanelLingkungan()),
          ),
        ),
      ),
    );
    await tester.pump();

    // Ketiga kartu harus tampil walau data belum dimuat.
    expect(find.text('KONDISI KOTA HARI INI'), findsOneWidget);
    expect(find.text('Cuaca'), findsOneWidget);
    expect(find.text('Kualitas Udara'), findsOneWidget);
    expect(find.text('Gempa Terkini (BMKG)'), findsOneWidget);
    expect(find.text('Perbarui'), findsOneWidget);
  });

  testWidgets('Panel menampilkan pesan jelas saat data tidak tersedia',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EnvironmentController(),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PanelLingkungan()),
          ),
        ),
      ),
    );
    await tester.pump();

    // Sebelum data dimuat, kartu menampilkan arahan, bukan data palsu.
    expect(
      find.textContaining('Data tidak tersedia'),
      findsWidgets,
    );
  });
}
