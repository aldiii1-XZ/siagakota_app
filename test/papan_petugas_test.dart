import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siagakota/models/index.dart';
import 'package:siagakota/widgets/papan_petugas.dart';

/// Membuat laporan contoh dengan data yang bisa dilacak, supaya tes dapat
/// memastikan panel benar-benar menampilkan angka dari data — bukan karangan.
Report buatLaporan({
  required String id,
  String jenis = 'Banjir',
  String kecamatan = 'Sukarami',
  double severity = 3,
  ReportStatus status = ReportStatus.diterima,
  int votes = 0,
  DateTime? dibuat,
}) {
  return Report(
    id: id,
    nama: 'Warga $id',
    jenis: jenis,
    deskripsi: 'Deskripsi $id',
    latitude: -2.98,
    longitude: 104.77,
    severity: severity,
    kecamatan: kecamatan,
    fotoPath: null,
    fotoBytes: null,
    accuracyMeters: null,
    createdAt: dibuat ?? DateTime(2026, 10, 5, 14, 2, 11),
    owner: 'Aldi',
    status: status,
    votes: votes,
  );
}

Widget bungkus(Widget anak) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: anak)),
    );

void main() {
  group('PantauanLaporanPanel', () {
    testWidgets('Menampilkan angka sesuai data, bukan karangan',
        (tester) async {
      final laporan = [
        buatLaporan(id: 'A', severity: 5),
        buatLaporan(id: 'B', severity: 4, status: ReportStatus.proses),
        buatLaporan(id: 'C', severity: 2, status: ReportStatus.selesai),
        buatLaporan(id: 'D', jenis: 'Sampah', severity: 1),
      ];

      await tester.pumpWidget(
        bungkus(PantauanLaporanPanel(reports: laporan)),
      );
      await tester.pumpAndSettle();

      // 4 laporan: 1 selesai, 1 diproses, 2 diterima, 2 urgensi >= 4.
      expect(find.text('Pantauan Laporan Warga'), findsOneWidget);
      expect(find.text('4 laporan'), findsOneWidget);
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Urgensi ≥4'), findsOneWidget);
      // Banjir 3, Sampah 1 — jenis terbanyak harus tampil.
      expect(find.text('Banjir'), findsOneWidget);
      expect(find.text('Sampah'), findsOneWidget);
    });

    testWidgets('Jujur saat belum ada laporan', (tester) async {
      await tester.pumpWidget(
        bungkus(const PantauanLaporanPanel(reports: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 laporan'), findsOneWidget);
      expect(find.text('Belum ada laporan masuk.'), findsOneWidget);
    });

    testWidgets('Tidak lagi memakai label karangan', (tester) async {
      final laporan = [buatLaporan(id: 'A', severity: 5)];
      await tester.pumpWidget(
        bungkus(PantauanLaporanPanel(reports: laporan)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Radar Sentimen'), findsNothing);
      expect(find.textContaining('Kepanikan'), findsNothing);
      expect(find.textContaining('Panik'), findsNothing);
      expect(find.textContaining('Marah'), findsNothing);
    });
  });

  group('PapanTindakLanjutPanel', () {
    testWidgets('Menyorot laporan dengan prioritas tertinggi',
        (tester) async {
      final laporan = [
        buatLaporan(
            id: 'rendah',
            jenis: 'Sampah',
            kecamatan: 'Sako',
            severity: 1),
        buatLaporan(
            id: 'tinggi',
            jenis: 'Banjir',
            kecamatan: 'Sukarami',
            severity: 5,
            votes: 10),
      ];

      await tester.pumpWidget(
        bungkus(PapanTindakLanjutPanel(reports: laporan)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Papan Tindak Lanjut'), findsOneWidget);
      expect(find.text('PRIORITAS PENANGANAN'), findsOneWidget);
      // Prioritas = severity*2 + votes -> Banjir (20) menang atas Sampah (2).
      expect(find.textContaining('Banjir • Sukarami'), findsOneWidget);
      expect(find.textContaining('Severity 5.0'), findsOneWidget);
      expect(find.textContaining('10 dukungan'), findsOneWidget);
    });

    testWidgets('Menampilkan aktivitas terbaru dari waktu laporan',
        (tester) async {
      final laporan = [
        buatLaporan(
            id: 'lama',
            jenis: 'Banjir',
            kecamatan: 'Plaju',
            dibuat: DateTime(2026, 10, 1, 8, 30)),
        buatLaporan(
            id: 'baru',
            jenis: 'Sampah',
            kecamatan: 'Sako',
            dibuat: DateTime(2026, 10, 5, 14, 2)),
      ];

      await tester.pumpWidget(
        bungkus(PapanTindakLanjutPanel(reports: laporan)),
      );
      await tester.pumpAndSettle();

      expect(find.text('AKTIVITAS TERBARU'), findsOneWidget);
      // Waktu diambil dari createdAt laporan, bukan jam karangan.
      expect(find.textContaining('[05/10 14:02] Sampah di Sako'),
          findsOneWidget);
    });

    testWidgets('Tidak lagi memakai feed CCTV palsu', (tester) async {
      await tester.pumpWidget(
        bungkus(PapanTindakLanjutPanel(reports: [buatLaporan(id: 'A')])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('CCTV'), findsNothing);
      expect(find.textContaining('VEHICLE'), findsNothing);
      expect(find.textContaining('ANOMALY'), findsNothing);
      expect(find.textContaining('LAP-001'), findsNothing);
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('Jujur saat belum ada laporan', (tester) async {
      await tester.pumpWidget(
        bungkus(const PapanTindakLanjutPanel(reports: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada laporan yang perlu ditangani.'),
          findsOneWidget);
      expect(find.text('> Belum ada aktivitas.'), findsOneWidget);
    });
  });
}
