import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/index.dart';
import '../services/index.dart';

/// Status pemuatan sebuah bagian data lingkungan.
enum StatusData { belum, memuat, siap, gagal }

/// Controller yang menyimpan data lingkungan (cuaca, kualitas udara, gempa)
/// untuk ditampilkan di dashboard. Data diambil dari [EnvironmentService]
/// dan di-cache sesuai lokasi terakhir agar tidak memanggil API berulang.
class EnvironmentController extends ChangeNotifier {
  final EnvironmentService _service;

  EnvironmentController({EnvironmentService? service})
      : _service = service ?? EnvironmentService();

  DataCuaca? _cuaca;
  KualitasUdara? _udara;
  GempaTerkini? _gempa;

  StatusData _statusCuaca = StatusData.belum;
  StatusData _statusUdara = StatusData.belum;
  StatusData _statusGempa = StatusData.belum;

  double? _lat;
  double? _lon;

  DataCuaca? get cuaca => _cuaca;
  KualitasUdara? get udara => _udara;
  GempaTerkini? get gempa => _gempa;

  StatusData get statusCuaca => _statusCuaca;
  StatusData get statusUdara => _statusUdara;
  StatusData get statusGempa => _statusGempa;

  /// Risiko banjir 0..5 dari prakiraan hujan. Dipakai laporan baru bila
  /// data cuaca tersedia; jika belum, pemanggil memakai nilai netral.
  double? get risikoBanjir => _cuaca?.risikoBanjir;

  /// Apakah ada minimal satu data yang sudah siap ditampilkan.
  bool get adaData =>
      _statusCuaca == StatusData.siap ||
      _statusUdara == StatusData.siap ||
      _statusGempa == StatusData.siap;

  /// Muat seluruh data untuk lokasi tertentu. Bila lokasi sama dengan
  /// pemuatan terakhir dan data sudah siap, pemuatan dilewati.
  Future<void> muat({required double lat, required double lon, bool paksa = false}) async {
    final lokasiSama = _lat == lat && _lon == lon;
    if (lokasiSama && adaData && !paksa) return;

    _lat = lat;
    _lon = lon;
    _statusCuaca = StatusData.memuat;
    _statusUdara = StatusData.memuat;
    notifyListeners();

    await Future.wait([
      _muatCuaca(lat, lon),
      _muatUdara(lat, lon),
    ]);
  }

  Future<void> _muatCuaca(double lat, double lon) async {
    final data = await _service.ambilCuaca(lat, lon);
    _cuaca = data;
    _statusCuaca = data == null ? StatusData.gagal : StatusData.siap;
    notifyListeners();
  }

  Future<void> _muatUdara(double lat, double lon) async {
    final data = await _service.ambilKualitasUdara(lat, lon);
    _udara = data;
    _statusUdara = data == null ? StatusData.gagal : StatusData.siap;
    notifyListeners();
  }

  /// Gempa tidak bergantung pada lokasi pengguna (data nasional BMKG),
  /// jadi cukup dimuat sekali.
  Future<void> muatGempa({bool paksa = false}) async {
    if (_statusGempa == StatusData.siap && !paksa) return;
    _statusGempa = StatusData.memuat;
    notifyListeners();
    final data = await _service.ambilGempaTerkini();
    _gempa = data;
    _statusGempa = data == null ? StatusData.gagal : StatusData.siap;
    notifyListeners();
  }

  /// Muat semua (cuaca, udara, gempa) — dipakai saat pertama membuka dashboard.
  Future<void> muatSemua({required double lat, required double lon}) async {
    await Future.wait([
      muat(lat: lat, lon: lon),
      muatGempa(),
    ]);
  }

  /// Ambil koordinat perangkat dengan aman, tanpa meminta izin baru.
  Future<Position?> lokasiSaatIni() async {
    try {
      final izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
          );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
