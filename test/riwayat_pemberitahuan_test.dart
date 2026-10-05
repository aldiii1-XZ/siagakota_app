import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siagakota/controllers/index.dart';
import 'package:siagakota/models/index.dart';
import 'package:siagakota/widgets/pemberitahuan_panel.dart';
import 'package:siagakota/widgets/riwayat_status.dart';

Report _laporan({List<StatusLog>? riwayat, ReportStatus status = ReportStatus.diterima}) =>
    Report(
      id: 'LAP-1',
      nama: 'Aldi',
      jenis: 'Banjir',
      deskripsi: 'Air meluap',
      latitude: -2.98,
      longitude: 104.77,
      severity: 4,
      kecamatan: 'Sukarami',
      fotoPath: null,
      fotoBytes: null,
      accuracyMeters: null,
      createdAt: DateTime(2026, 10, 5, 10, 0),
      owner: 'Aldi',
      status: status,
      riwayat: riwayat,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Riwayat status laporan', () {
    test('Report menyimpan riwayat & ikut tersimpan di JSON', () {
      final r = _laporan(riwayat: [
        StatusLog(
            status: ReportStatus.diterima,
            waktu: DateTime(2026, 10, 5, 10, 0),
            oleh: 'Aldi'),
        StatusLog(
            status: ReportStatus.proses,
            waktu: DateTime(2026, 10, 5, 11, 0),
            oleh: 'Petugas'),
      ]);
      final lagi = Report.fromJson(r.toJson());
      expect(lagi.riwayat.length, 2);
      expect(lagi.riwayat.first.status, ReportStatus.diterima);
      expect(lagi.riwayat.last.status, ReportStatus.proses);
      expect(lagi.riwayat.last.oleh, 'Petugas');
    });

    test('Report lama tanpa riwayat tidak error (riwayat kosong)', () {
      final json = _laporan().toJson()..remove('riwayat');
      final r = Report.fromJson(json);
      expect(r.riwayat, isEmpty);
    });

    testWidgets('Menampilkan jejak status secara berurutan', (tester) async {
      final r = _laporan(status: ReportStatus.selesai, riwayat: [
        StatusLog(
            status: ReportStatus.diterima,
            waktu: DateTime(2026, 10, 5, 10, 0),
            oleh: 'Aldi'),
        StatusLog(
            status: ReportStatus.proses,
            waktu: DateTime(2026, 10, 5, 11, 0),
            oleh: 'Petugas'),
        StatusLog(
            status: ReportStatus.selesai,
            waktu: DateTime(2026, 10, 5, 14, 0),
            oleh: 'Petugas'),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: RiwayatStatusPanel(report: r))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Proses'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.textContaining('Aldi'), findsOneWidget);
      expect(find.textContaining('Petugas'), findsNWidgets(2));
    });

    testWidgets('Jujur saat belum ada riwayat', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RiwayatStatusPanel(report: _laporan())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada riwayat penanganan.'), findsOneWidget);
    });
  });

  group('Pemberitahuan dalam aplikasi', () {
    test('Perubahan status membuat pemberitahuan & menambah lencana', () async {
      final ctrl = PemberitahuanController();
      await ctrl.muat();
      expect(ctrl.jumlahBelumDibaca, 0);

      await ctrl.tambahPerubahanStatus(
        report: _laporan(),
        status: ReportStatus.proses,
      );

      expect(ctrl.items.length, 1);
      expect(ctrl.jumlahBelumDibaca, 1);
      expect(ctrl.items.first.pesan, contains('Banjir'));
      expect(ctrl.items.first.pesan, contains('Proses'));
      expect(ctrl.items.first.dibaca, isFalse);
    });

    test('Tandai dibaca mengurangi lencana', () async {
      final ctrl = PemberitahuanController();
      await ctrl.muat();
      await ctrl.tambahPerubahanStatus(
          report: _laporan(), status: ReportStatus.proses);
      await ctrl.tambahPerubahanStatus(
          report: _laporan(), status: ReportStatus.selesai);
      expect(ctrl.jumlahBelumDibaca, 2);

      await ctrl.tandaiDibaca(ctrl.items.first.id);
      expect(ctrl.jumlahBelumDibaca, 1);

      await ctrl.tandaiSemuaDibaca();
      expect(ctrl.jumlahBelumDibaca, 0);
    });

    test('Pemberitahuan bertahan setelah dimuat ulang', () async {
      final ctrl = PemberitahuanController();
      await ctrl.muat();
      await ctrl.tambahPerubahanStatus(
          report: _laporan(), status: ReportStatus.selesai);

      // Controller baru membaca dari penyimpanan yang sama.
      final ctrl2 = PemberitahuanController();
      await ctrl2.muat();
      expect(ctrl2.items.length, 1);
      expect(ctrl2.items.first.pesan, contains('Selesai'));
    });

    testWidgets('Panel menampilkan pesan kosong yang jelas', (tester) async {
      final ctrl = PemberitahuanController();
      await ctrl.muat();
      await tester.pumpWidget(
        ChangeNotifierProvider<PemberitahuanController>.value(
          value: ctrl,
          child: const MaterialApp(
            home: Scaffold(body: PanelPemberitahuan()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pemberitahuan'), findsOneWidget);
      expect(find.text('Belum ada pemberitahuan.'), findsOneWidget);
    });

    testWidgets('Panel menampilkan isi pemberitahuan', (tester) async {
      final ctrl = PemberitahuanController();
      await ctrl.muat();
      await ctrl.tambahPerubahanStatus(
          report: _laporan(), status: ReportStatus.proses);

      await tester.pumpWidget(
        ChangeNotifierProvider<PemberitahuanController>.value(
          value: ctrl,
          child: const MaterialApp(
            home: Scaffold(body: PanelPemberitahuan()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Status laporan berubah'), findsOneWidget);
      expect(find.textContaining('kini Proses'), findsOneWidget);
    });
  });
}
