import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  static String? _token;

  static void setToken(String token) {
    _token = token;
  }

  static Map<String, String> get _headers {
    final h = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  static Future<Map<String, dynamic>> register(String nama) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: _headers,
      body: jsonEncode({'nama': nama}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 201 && body['token'] != null) {
      setToken(body['token']);
    }
    return body;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['token'] != null) {
      setToken(body['token']);
    }
    return body;
  }

  static Future<List<dynamic>> fetchReports({String? kecamatan, String? status, String? owner}) async {
    final query = <String, String>{};
    if (kecamatan != null) query['kecamatan'] = kecamatan;
    if (status != null) query['status'] = status;
    if (owner != null) query['owner'] = owner;

    final uri = Uri.parse('$baseUrl/reports').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> createReport({
    required String nama,
    required String jenis,
    required String deskripsi,
    required double latitude,
    required double longitude,
    required double severity,
    required String kecamatan,
    required String owner,
    double? accuracyMeters,
    String? fotoBase64,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/reports'));
    request.headers.addAll(_headers);
    request.fields.addAll({
      'nama': nama,
      'jenis': jenis,
      'deskripsi': deskripsi,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'severity': severity.toString(),
      'kecamatan': kecamatan,
      'owner': owner,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters.toString(),
      if (fotoBase64 != null) 'foto_base64': fotoBase64,
    });

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateReportStatus(String id, String status) async {
    final res = await http.put(
      Uri.parse('$baseUrl/reports/$id/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> upvoteReport(String id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/reports/$id/upvote'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  static Future<bool> deleteReport(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/reports/$id'),
      headers: _headers,
    );
    return res.statusCode == 200;
  }

  static Future<Map<String, dynamic>> fetchMeta() async {
    final res = await http.get(
      Uri.parse('$baseUrl/meta'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {};
  }
}

