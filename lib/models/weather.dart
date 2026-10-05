import 'package:flutter/material.dart';

/// Model untuk fitur lingkungan SiagaKota: cuaca, kualitas udara, gempa.
/// Semua data berasal dari API publik gratis (Open-Meteo & BMKG) yang tidak
/// memerlukan API key, sehingga aplikasi tetap berjalan tanpa konfigurasi.

// ═══════════════════════════════════════════════════════════════════════
// CUACA
// ═══════════════════════════════════════════════════════════════════════

/// Cuaca saat ini pada satu titik koordinat.
class CuacaSekarang {
  final double suhu;
  final double suhuTerasa;
  final int kelembapan;
  final double curahHujan;
  final double kecepatanAngin;
  final int arahAngin;
  final int tutupanAwan;
  final double tekananUdara;
  final int kodeCuaca;
  final DateTime waktu;

  const CuacaSekarang({
    required this.suhu,
    required this.suhuTerasa,
    required this.kelembapan,
    required this.curahHujan,
    required this.kecepatanAngin,
    required this.arahAngin,
    required this.tutupanAwan,
    required this.tekananUdara,
    required this.kodeCuaca,
    required this.waktu,
  });

  factory CuacaSekarang.fromJson(Map<String, dynamic> json) {
    final c = json['current'] as Map<String, dynamic>;
    double num_(String k) => (c[k] as num?)?.toDouble() ?? 0;
    int int_(String k) => (c[k] as num?)?.toInt() ?? 0;
    return CuacaSekarang(
      suhu: num_('temperature_2m'),
      suhuTerasa: num_('apparent_temperature'),
      kelembapan: int_('relative_humidity_2m'),
      curahHujan: num_('precipitation'),
      kecepatanAngin: num_('wind_speed_10m'),
      arahAngin: int_('wind_direction_10m'),
      tutupanAwan: int_('cloud_cover'),
      tekananUdara: num_('pressure_msl'),
      kodeCuaca: int_('weather_code'),
      waktu: DateTime.tryParse(c['time'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Label kondisi dalam bahasa Indonesia dari kode WMO.
  String get kondisi => KodeCuaca.label(kodeCuaca);

  /// Ikon Material yang mewakili kondisi cuaca.
  IconData get ikon => KodeCuaca.ikon(kodeCuaca);

  /// Apakah sedang hujan (kode 51 ke atas yang berhubungan dengan hujan).
  bool get sedangHujan => KodeCuaca.hujan(kodeCuaca);

  /// Arah mata angin dalam bahasa Indonesia.
  String get arahMataAngin => KodeCuaca.mataAngin(arahAngin);
}

/// Prakiraan cuaca untuk satu hari.
class PrakiraanHarian {
  final DateTime tanggal;
  final int kodeCuaca;
  final double suhuMin;
  final double suhuMax;
  final double curahHujan;
  final int peluangHujan;

  const PrakiraanHarian({
    required this.tanggal,
    required this.kodeCuaca,
    required this.suhuMin,
    required this.suhuMax,
    required this.curahHujan,
    required this.peluangHujan,
  });

  String get kondisi => KodeCuaca.label(kodeCuaca);
  IconData get ikon => KodeCuaca.ikon(kodeCuaca);
}

/// Data cuaca lengkap: kondisi saat ini + prakiraan beberapa hari.
class DataCuaca {
  final CuacaSekarang sekarang;
  final List<PrakiraanHarian> prakiraan;

  const DataCuaca({required this.sekarang, required this.prakiraan});

  factory DataCuaca.fromJson(Map<String, dynamic> json) {
    final d = json['daily'] as Map<String, dynamic>;
    final tanggal = (d['time'] as List).cast<String>();
    final kode = (d['weather_code'] as List);
    final tmax = (d['temperature_2m_max'] as List);
    final tmin = (d['temperature_2m_min'] as List);
    final hujan = (d['precipitation_sum'] as List);
    final peluang = (d['precipitation_probability_max'] as List);

    final daftar = <PrakiraanHarian>[];
    for (var i = 0; i < tanggal.length; i++) {
      daftar.add(
        PrakiraanHarian(
          tanggal: DateTime.tryParse(tanggal[i]) ?? DateTime.now(),
          kodeCuaca: (kode[i] as num?)?.toInt() ?? 0,
          suhuMin: (tmin[i] as num?)?.toDouble() ?? 0,
          suhuMax: (tmax[i] as num?)?.toDouble() ?? 0,
          curahHujan: (hujan[i] as num?)?.toDouble() ?? 0,
          peluangHujan: (peluang.length > i ? peluang[i] as num? : null)
                  ?.toInt() ??
              0,
        ),
      );
    }

    return DataCuaca(
      sekarang: CuacaSekarang.fromJson(json),
      prakiraan: daftar,
    );
  }

  /// Total curah hujan yang diprediksi dalam 24 jam ke depan (mm).
  double get curahHujan24Jam =>
      prakiraan.isEmpty ? 0 : prakiraan.first.curahHujan;

  /// Risiko banjir 0..5 berdasarkan prakiraan hujan 24 jam ke depan.
  /// Dipakai menggantikan nilai mock pada perhitungan prioritas laporan.
  double get risikoBanjir {
    final mm = curahHujan24Jam;
    if (mm >= 100) return 5;
    if (mm >= 50) return 4;
    if (mm >= 20) return 3;
    if (mm >= 5) return 2;
    if (mm > 0) return 1;
    return 0;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// KUALITAS UDARA
// ═══════════════════════════════════════════════════════════════════════

/// Kualitas udara pada satu titik koordinat.
class KualitasUdara {
  final double pm10;
  final double pm25;
  final double karbonMonoksida;
  final double nitrogenDioksida;
  final double sulfurDioksida;
  final double ozon;
  final int aqi;
  final int aqiEropa;
  final double indeksUv;
  final DateTime waktu;

  const KualitasUdara({
    required this.pm10,
    required this.pm25,
    required this.karbonMonoksida,
    required this.nitrogenDioksida,
    required this.sulfurDioksida,
    required this.ozon,
    required this.aqi,
    required this.aqiEropa,
    required this.indeksUv,
    required this.waktu,
  });

  factory KualitasUdara.fromJson(Map<String, dynamic> json) {
    final c = json['current'] as Map<String, dynamic>;
    double num_(String k) => (c[k] as num?)?.toDouble() ?? 0;
    return KualitasUdara(
      pm10: num_('pm10'),
      pm25: num_('pm2_5'),
      karbonMonoksida: num_('carbon_monoxide'),
      nitrogenDioksida: num_('nitrogen_dioxide'),
      sulfurDioksida: num_('sulphur_dioxide'),
      ozon: num_('ozone'),
      aqi: num_('us_aqi').round(),
      aqiEropa: num_('european_aqi').round(),
      indeksUv: num_('uv_index'),
      waktu: DateTime.tryParse(c['time'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Kategori AQI (skala US EPA).
  KategoriAqi get kategori => KategoriAqi.dari(aqi);

  /// Saran singkat untuk warga berdasarkan tingkat polusi.
  String get saran {
    if (aqi <= 50) return 'Udara bersih. Aman beraktivitas di luar.';
    if (aqi <= 100) return 'Udara sedang. Kelompok sensitif sebaiknya kurangi aktivitas luar.';
    if (aqi <= 150) return 'Tidak sehat bagi kelompok sensitif. Gunakan masker bila keluar.';
    if (aqi <= 200) return 'Udara tidak sehat. Hindari aktivitas luar, pakai masker.';
    if (aqi <= 300) return 'Sangat tidak sehat. Tetap di dalam ruangan, tutup jendela.';
    return 'Berbahaya. Hindari keluar rumah, gunakan penyaring udara.';
  }

  /// Kategori indeks UV.
  String get kategoriUv {
    if (indeksUv < 3) return 'Rendah';
    if (indeksUv < 6) return 'Sedang';
    if (indeksUv < 8) return 'Tinggi';
    if (indeksUv < 11) return 'Sangat Tinggi';
    return 'Ekstrem';
  }
}

/// Kategori kualitas udara berdasarkan nilai AQI (skala US EPA).
enum KategoriAqi {
  baik,
  sedang,
  sensitif,
  tidakSehat,
  sangatTidakSehat,
  berbahaya;

  static KategoriAqi dari(int aqi) {
    if (aqi <= 50) return KategoriAqi.baik;
    if (aqi <= 100) return KategoriAqi.sedang;
    if (aqi <= 150) return KategoriAqi.sensitif;
    if (aqi <= 200) return KategoriAqi.tidakSehat;
    if (aqi <= 300) return KategoriAqi.sangatTidakSehat;
    return KategoriAqi.berbahaya;
  }

  String get label {
    switch (this) {
      case KategoriAqi.baik:
        return 'Baik';
      case KategoriAqi.sedang:
        return 'Sedang';
      case KategoriAqi.sensitif:
        return 'Tidak Sehat (Sensitif)';
      case KategoriAqi.tidakSehat:
        return 'Tidak Sehat';
      case KategoriAqi.sangatTidakSehat:
        return 'Sangat Tidak Sehat';
      case KategoriAqi.berbahaya:
        return 'Berbahaya';
    }
  }

  Color get warna {
    switch (this) {
      case KategoriAqi.baik:
        return const Color(0xFF10B981);
      case KategoriAqi.sedang:
        return const Color(0xFFFACC15);
      case KategoriAqi.sensitif:
        return const Color(0xFFFB923C);
      case KategoriAqi.tidakSehat:
        return const Color(0xFFEF4444);
      case KategoriAqi.sangatTidakSehat:
        return const Color(0xFF8B5CF6);
      case KategoriAqi.berbahaya:
        return const Color(0xFF7F1D1D);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// GEMPA (BMKG)
// ═══════════════════════════════════════════════════════════════════════

/// Informasi gempa terkini dari BMKG.
class GempaTerkini {
  final String tanggal;
  final String jam;
  final double magnitude;
  final String kedalaman;
  final String wilayah;
  final String potensi;
  final double lintang;
  final double bujur;

  const GempaTerkini({
    required this.tanggal,
    required this.jam,
    required this.magnitude,
    required this.kedalaman,
    required this.wilayah,
    required this.potensi,
    required this.lintang,
    required this.bujur,
  });

  factory GempaTerkini.fromJson(Map<String, dynamic> json) {
    final g = json['Infogempa']['gempa'] as Map<String, dynamic>;
    return GempaTerkini(
      tanggal: g['Tanggal'] as String? ?? '-',
      jam: g['Jam'] as String? ?? '-',
      magnitude: double.tryParse('${g['Magnitude']}') ?? 0,
      kedalaman: g['Kedalaman'] as String? ?? '-',
      wilayah: g['Wilayah'] as String? ?? '-',
      potensi: g['Potensi'] as String? ?? '-',
      lintang: double.tryParse('${g['Lintang']}'.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
      bujur: double.tryParse('${g['Bujur']}'.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
    );
  }

  /// Tingkat bahaya berdasarkan magnitudo.
  Color get warna {
    if (magnitude >= 6) return const Color(0xFFEF4444);
    if (magnitude >= 5) return const Color(0xFFFB923C);
    return const Color(0xFFFACC15);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PEMETAAN KODE CUACA WMO
// ═══════════════════════════════════════════════════════════════════════

/// Pemetaan kode cuaca WMO ke label Indonesia & ikon Material.
class KodeCuaca {
  static String label(int kode) {
    switch (kode) {
      case 0:
        return 'Cerah';
      case 1:
        return 'Cerah Berawan';
      case 2:
        return 'Berawan';
      case 3:
        return 'Mendung';
      case 45:
      case 48:
        return 'Berkabut';
      case 51:
      case 53:
      case 55:
        return 'Gerimis';
      case 56:
      case 57:
        return 'Gerimis Beku';
      case 61:
        return 'Hujan Ringan';
      case 63:
        return 'Hujan Sedang';
      case 65:
        return 'Hujan Lebat';
      case 66:
      case 67:
        return 'Hujan Beku';
      case 71:
      case 73:
      case 75:
        return 'Salju';
      case 77:
        return 'Butiran Salju';
      case 80:
        return 'Hujan Lokal Ringan';
      case 81:
        return 'Hujan Lokal Sedang';
      case 82:
        return 'Hujan Lokal Lebat';
      case 85:
      case 86:
        return 'Hujan Salju';
      case 95:
        return 'Badai Petir';
      case 96:
      case 99:
        return 'Badai Petir Hujan Es';
      default:
        return 'Tidak Diketahui';
    }
  }

  static IconData ikon(int kode) {
    if (kode == 0) return Icons.wb_sunny_rounded;
    if (kode == 1 || kode == 2) return Icons.wb_cloudy_rounded;
    if (kode == 3) return Icons.cloud_rounded;
    if (kode == 45 || kode == 48) return Icons.foggy;
    if (kode >= 51 && kode <= 57) return Icons.grain_rounded;
    if (kode >= 61 && kode <= 67) return Icons.water_drop_rounded;
    if (kode >= 71 && kode <= 77) return Icons.ac_unit_rounded;
    if (kode >= 80 && kode <= 82) return Icons.umbrella_rounded;
    if (kode >= 85 && kode <= 86) return Icons.ac_unit_rounded;
    if (kode >= 95) return Icons.thunderstorm_rounded;
    return Icons.help_outline_rounded;
  }

  /// Kode yang menandakan hujan/gerimis/badai.
  static bool hujan(int kode) =>
      (kode >= 51 && kode <= 67) ||
      (kode >= 80 && kode <= 82) ||
      (kode >= 95 && kode <= 99);

  /// Ubah derajat arah angin menjadi mata angin Indonesia.
  static String mataAngin(int derajat) {
    const arah = [
      'Utara',
      'Timur Laut',
      'Timur',
      'Tenggara',
      'Selatan',
      'Barat Daya',
      'Barat',
      'Barat Laut',
    ];
    final idx = (((derajat % 360) / 45).round()) % 8;
    return arah[idx];
  }
}
