import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:siagakota/main.dart';

void main() {
  testWidgets('Menampilkan daftar laporan kosong', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ReportController(),
        child: const SiagaKotaApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('SiagaKota'), findsOneWidget);
    expect(find.text('Belum ada laporan'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
