import 'dart:convert';
import 'dart:typed_data';
import 'constants.dart';

class Report {
  final String id;
  final String nama;
  final String jenis;
  final String deskripsi;
  final double latitude;
  final double longitude;
  final double severity; // 1..5
  final String kecamatan;
  final String? fotoPath;
  final Uint8List? fotoBytes;
  final String? photoUrl; // URL to image in Supabase Storage
  final double? accuracyMeters;
  final DateTime createdAt;
  final String owner; // nama akun yang membuat
  ReportStatus status;
  int votes;
  String? duplicateOf;
  double weatherRisk;

  Report({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.deskripsi,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.kecamatan,
    required this.fotoPath,
    required this.fotoBytes,
    required this.accuracyMeters,
    required this.createdAt,
    required this.owner,
    this.photoUrl,
    this.status = ReportStatus.diterima,
    this.votes = 0,
    this.duplicateOf,
    this.weatherRisk = 0,
  });

  double get priorityScore => severity * 2 + votes + weatherRisk;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'jenis': jenis,
        'deskripsi': deskripsi,
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity,
        'kecamatan': kecamatan,
        'fotoPath': fotoPath,
        'fotoBytes': fotoBytes != null ? base64Encode(fotoBytes!) : null,
        'photoUrl': photoUrl,
        'accuracyMeters': accuracyMeters,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'votes': votes,
        'duplicateOf': duplicateOf,
        'weatherRisk': weatherRisk,
        'owner': owner,
      };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as String,
        nama: json['nama'] as String? ?? '-',
        jenis: json['jenis'] as String? ?? 'Banjir',
        deskripsi: json['deskripsi'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        severity: (json['severity'] as num).toDouble(),
        kecamatan: json['kecamatan'] as String? ?? kecamatanPalembang.first,
        fotoPath: json['fotoPath'] as String?,
        fotoBytes: json['fotoBytes'] != null
            ? base64Decode(json['fotoBytes'] as String)
            : null,
        photoUrl: json['photoUrl'] as String?,
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        status: ReportStatus.values.firstWhere((e) => e.name == json['status'],
            orElse: () => ReportStatus.diterima),
        votes: json['votes'] as int? ?? 0,
        duplicateOf: json['duplicateOf'] as String?,
        weatherRisk: (json['weatherRisk'] as num?)?.toDouble() ?? 0,
        owner: json['owner'] as String? ?? '-',
      );
}

class ReportDraft {
  final String nama;
  final String jenis;
  final String deskripsi;
  final double severity;
  final String kecamatan;
  final String? fotoPath;
  final String? fotoBase64;

  ReportDraft({
    required this.nama,
    required this.jenis,
    required this.deskripsi,
    required this.severity,
    required this.kecamatan,
    this.fotoPath,
    this.fotoBase64,
  });

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'jenis': jenis,
        'deskripsi': deskripsi,
        'severity': severity,
        'kecamatan': kecamatan,
        'fotoPath': fotoPath,
        'fotoBase64': fotoBase64,
      };

  factory ReportDraft.fromJson(Map<String, dynamic> json) => ReportDraft(
        nama: json['nama'] as String,
        jenis: json['jenis'] as String? ?? 'Banjir',
        deskripsi: json['deskripsi'] as String? ?? '',
        severity: (json['severity'] as num?)?.toDouble() ?? 3,
        kecamatan: json['kecamatan'] as String? ?? kecamatanPalembang.first,
        fotoPath: json['fotoPath'] as String?,
        fotoBase64: json['fotoBase64'] as String?,
      );
}
