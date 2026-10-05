import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siagakota/models/index.dart';

/// Tes parsing data lingkungan memakai contoh respons API yang sudah
/// disimpan di test/fixtures/ (diambil langsung dari API asli). Tujuannya
/// memastikan pemetaan kolom JSON benar, sehingga UI tidak menampilkan
/// data kosong atau salah saat aplikasi berjalan.
void main() {
  Map<String, dynamic> bacaFixture(String nama) {
    final file = File('test/fixtures/$nama');
    // Buang BOM (byte order mark) bila ada, agar jsonDecode tidak gagal.
    final teks = file.readAsStringSync().replaceFirst('\uFEFF', '');
    return jsonDecode(teks) as Map<String, dynamic>;
  }

  group('Cuaca (Open-Meteo)', () {
    late DataCuaca cuaca;

    setUpAll(() {
      cuaca = DataCuaca.fromJson(bacaFixture('cuaca.json'));
    });

    test('membaca kondisi saat ini dengan benar', () {
      final s = cuaca.sekarang;
      expect(s.suhu, greaterThan(-50));
      expect(s.suhu, lessThan(60));
      expect(s.kelembapan, inInclusiveRange(0, 100));
      expect(s.kecepatanAngin, greaterThanOrEqualTo(0));
      expect(s.tutupanAwan, inInclusiveRange(0, 100));
      expect(s.kodeCuaca, isNotNull);
      expect(s.kondisi, isNotEmpty);
    });

    test('menerjemahkan kode cuaca WMO ke bahasa Indonesia', () {
      // Kode 0 = cerah, 3 = mendung, 65 = hujan lebat, 95 = badai petir.
      expect(KodeCuaca.label(0), 'Cerah');
      expect(KodeCuaca.label(3), 'Mendung');
      expect(KodeCuaca.label(65), 'Hujan Lebat');
      expect(KodeCuaca.label(95), 'Badai Petir');
    });

    test('mengenali kode cuaca yang menandakan hujan', () {
      expect(KodeCuaca.hujan(0), isFalse);
      expect(KodeCuaca.hujan(3), isFalse);
      expect(KodeCuaca.hujan(61), isTrue);
      expect(KodeCuaca.hujan(80), isTrue);
      expect(KodeCuaca.hujan(95), isTrue);
    });

    test('mengubah derajat angin menjadi mata angin', () {
      expect(KodeCuaca.mataAngin(0), 'Utara');
      expect(KodeCuaca.mataAngin(90), 'Timur');
      expect(KodeCuaca.mataAngin(180), 'Selatan');
      expect(KodeCuaca.mataAngin(270), 'Barat');
      expect(KodeCuaca.mataAngin(360), 'Utara');
    });

    test('membaca prakiraan harian', () {
      expect(cuaca.prakiraan, isNotEmpty);
      expect(cuaca.prakiraan.length, lessThanOrEqualTo(5));
      for (final p in cuaca.prakiraan) {
        expect(p.suhuMax, greaterThanOrEqualTo(p.suhuMin));
        expect(p.kondisi, isNotEmpty);
      }
    });

    test('menghitung risiko banjir dari curah hujan 24 jam', () {
      expect(cuaca.risikoBanjir, inInclusiveRange(0, 5));
      expect(cuaca.curahHujan24Jam, greaterThanOrEqualTo(0));
    });
  });

  group('Risiko banjir berdasarkan curah hujan', () {
    DataCuaca buat(double mm) => DataCuaca.fromJson({
          'current': {'time': '2026-01-01T00:00', 'weather_code': 61},
          'daily': {
            'time': ['2026-01-01'],
            'weather_code': [61],
            'temperature_2m_max': [30.0],
            'temperature_2m_min': [24.0],
            'precipitation_sum': [mm],
            'precipitation_probability_max': [80],
          },
        });

    test('hujan ringan memberi risiko rendah', () {
      expect(buat(2).risikoBanjir, 1);
    });

    test('hujan sedang menaikkan risiko', () {
      expect(buat(25).risikoBanjir, 3);
    });

    test('hujan sangat lebat memberi risiko maksimum', () {
      expect(buat(120).risikoBanjir, 5);
    });

    test('tanpa hujan tidak ada risiko', () {
      expect(buat(0).risikoBanjir, 0);
    });
  });

  group('Kualitas udara (Open-Meteo Air Quality)', () {
    late KualitasUdara udara;

    setUpAll(() {
      udara = KualitasUdara.fromJson(bacaFixture('udara.json'));
    });

    test('membaca polutan utama', () {
      expect(udara.pm25, greaterThanOrEqualTo(0));
      expect(udara.pm10, greaterThanOrEqualTo(0));
      expect(udara.aqi, greaterThanOrEqualTo(0));
      expect(udara.indeksUv, greaterThanOrEqualTo(0));
    });

    test('menentukan kategori AQI sesuai skala US EPA', () {
      expect(KategoriAqi.dari(30), KategoriAqi.baik);
      expect(KategoriAqi.dari(80), KategoriAqi.sedang);
      expect(KategoriAqi.dari(120), KategoriAqi.sensitif);
      expect(KategoriAqi.dari(180), KategoriAqi.tidakSehat);
      expect(KategoriAqi.dari(250), KategoriAqi.sangatTidakSehat);
      expect(KategoriAqi.dari(350), KategoriAqi.berbahaya);
    });

    test('memberi saran sesuai kategori', () {
      expect(udara.saran, isNotEmpty);
      expect(udara.kategori.label, isNotEmpty);
      expect(udara.kategoriUv, isNotEmpty);
    });

    test('kategori AQI punya warna berbeda', () {
      final warna = KategoriAqi.values.map((k) => k.warna).toSet();
      expect(warna.length, KategoriAqi.values.length);
    });
  });

  group('Gempa (BMKG)', () {
    late GempaTerkini gempa;

    setUpAll(() {
      gempa = GempaTerkini.fromJson(bacaFixture('gempa.json'));
    });

    test('membaca data gempa terkini', () {
      expect(gempa.magnitude, greaterThan(0));
      expect(gempa.kedalaman, isNotEmpty);
      expect(gempa.wilayah, isNotEmpty);
      expect(gempa.tanggal, isNotEmpty);
      expect(gempa.jam, isNotEmpty);
    });

    test('menandai gempa kuat dengan warna bahaya', () {
      // Gempa M>=6 harus berwarna merah (bahaya).
      final kuat = GempaTerkini(
        tanggal: '-',
        jam: '-',
        magnitude: 6.5,
        kedalaman: '10 km',
        wilayah: 'uji',
        potensi: 'uji',
        lintang: 0,
        bujur: 0,
      );
      expect(kuat.warna, const Color(0xFFEF4444));
    });
  });
}
