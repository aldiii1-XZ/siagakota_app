import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siagakota/controllers/index.dart';
import 'package:siagakota/layar/peta.dart';
import 'package:siagakota/models/index.dart';

Report _laporan({
  required String id,
  required String owner,
  required DateTime dibuat,
  String jenis = 'Banjir',
  String kecamatan = 'Sukarami',
  double severity = 3,
}) =>
    Report(
      id: id,
      nama: 'Warga',
      jenis: jenis,
      deskripsi: 'Deskripsi',
      latitude: -2.98,
      longitude: 104.77,
      severity: severity,
      kecamatan: kecamatan,
      fotoPath: null,
      fotoBytes: null,
      accuracyMeters: null,
      createdAt: dibuat,
      owner: owner,
    );

void main() {
  final sekarang = DateTime(2026, 10, 5, 12, 0);

  group('PembatasLaporan — cegah spam', () {
    const pembatas = PembatasLaporan();

    test('Laporan pertama selalu boleh', () {
      final hasil = pembatas.periksa(
        laporan: const [],
        owner: 'Aldi',
        sekarang: sekarang,
      );
      expect(hasil, HasilKirim.berhasil);
    });

    test('Menolak laporan kedua yang terlalu cepat', () {
      final hasil = pembatas.periksa(
        laporan: [
          _laporan(
              id: 'A',
              owner: 'Aldi',
              dibuat: sekarang.subtract(const Duration(seconds: 10))),
        ],
        owner: 'Aldi',
        sekarang: sekarang,
      );
      expect(hasil, HasilKirim.terlaluSering);
    });

    test('Boleh kirim lagi setelah jeda terlewati', () {
      final hasil = pembatas.periksa(
        laporan: [
          _laporan(
              id: 'A',
              owner: 'Aldi',
              dibuat: sekarang.subtract(const Duration(minutes: 5))),
        ],
        owner: 'Aldi',
        sekarang: sekarang,
      );
      expect(hasil, HasilKirim.berhasil);
    });

    test('Menolak saat kuota per jam tercapai', () {
      // 5 laporan dalam satu jam = batas tercapai.
      final laporan = List.generate(
        5,
        (i) => _laporan(
          id: 'L$i',
          owner: 'Aldi',
          dibuat: sekarang.subtract(Duration(minutes: 50 - i * 8)),
        ),
      );
      final hasil = pembatas.periksa(
        laporan: laporan,
        owner: 'Aldi',
        sekarang: sekarang,
      );
      expect(hasil, HasilKirim.kuotaPenuh);
    });

    test('Laporan akun lain tidak dihitung', () {
      final hasil = pembatas.periksa(
        laporan: List.generate(
          10,
          (i) => _laporan(
            id: 'L$i',
            owner: 'Orang Lain',
            dibuat: sekarang.subtract(const Duration(minutes: 5)),
          ),
        ),
        owner: 'Aldi',
        sekarang: sekarang,
      );
      expect(hasil, HasilKirim.berhasil);
    });

    test('Laporan lama (>1 jam) tidak menghalangi', () {
      final hasil = pembatas.periksa(
        laporan: [
          _laporan(
              id: 'A',
              owner: 'Aldi',
              dibuat: sekarang.subtract(const Duration(hours: 3))),
        ],
        owner: 'Aldi',
        sekarang: sekarang,
      );
      expect(hasil, HasilKirim.berhasil);
    });
  });

  group('LegendaPeta — keterangan warna', () {
    testWidgets('Menampilkan semua tingkat keparahan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LegendaPeta())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keterangan'), findsOneWidget);
      expect(find.textContaining('Ringan'), findsOneWidget);
      expect(find.textContaining('Sedang'), findsOneWidget);
      expect(find.textContaining('Berat'), findsOneWidget);
      expect(find.textContaining('Sangat berat'), findsOneWidget);
      expect(find.text('Lokasi Anda'), findsOneWidget);
    });
  });
}
