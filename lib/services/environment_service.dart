import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/index.dart';

/// Layanan data lingkungan: cuaca, kualitas udara, dan gempa.
///
/// Memakai API publik gratis tanpa API key (Open-Meteo & BMKG), sehingga
/// tidak ada kredensial yang perlu disimpan di aplikasi. Setiap metode
/// mengembalikan null bila gagal — pemanggil wajib menangani nilai null
/// agar UI menampilkan status "tidak tersedia" alih-alih data palsu.
class EnvironmentService {
  final http.Client _client;

  EnvironmentService({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 12);

  /// Cuaca saat ini + prakiraan harian untuk koordinat tertentu.
  Future<DataCuaca?> ambilCuaca(double lat, double lon) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,'
              'weather_code,wind_speed_10m,wind_direction_10m,cloud_cover,pressure_msl',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,'
              'precipitation_probability_max',
      'timezone': 'Asia/Jakarta',
      'forecast_days': '5',
    });
    return _get(uri, (json) => DataCuaca.fromJson(json));
  }

  /// Kualitas udara (AQI, PM2.5, PM10, UV) untuk koordinat tertentu.
  Future<KualitasUdara?> ambilKualitasUdara(double lat, double lon) async {
    final uri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current':
          'pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,'
              'us_aqi,european_aqi,uv_index',
      'timezone': 'Asia/Jakarta',
    });
    return _get(uri, (json) => KualitasUdara.fromJson(json));
  }

  /// Gempa terkini yang dirasakan di Indonesia (sumber BMKG).
  Future<GempaTerkini?> ambilGempaTerkini() async {
    final uri = Uri.https('data.bmkg.go.id', '/DataMKG/TEWS/autogempa.json');
    return _get(uri, (json) => GempaTerkini.fromJson(json));
  }

  /// Helper: GET, decode JSON, dan parse dengan aman.
  Future<T?> _get<T>(Uri uri, T Function(Map<String, dynamic>) parse) async {
    try {
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode != 200) {
        debugPrint('[Environment] HTTP ${res.statusCode} untuk $uri');
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return parse(json);
    } catch (e) {
      debugPrint('[Environment] Gagal ambil data dari $uri: $e');
      return null;
    }
  }

  void dispose() => _client.close();
}
