import 'constants.dart';

/// Satu catatan perubahan status sebuah laporan.
///
/// Dipakai untuk menampilkan jejak penanganan ("Diterima → Diproses →
/// Selesai") beserta waktu dan siapa yang mengubahnya.
class StatusLog {
  final ReportStatus status;
  final DateTime waktu;

  /// Nama pihak yang mengubah status (mis. "Petugas" atau nama akun).
  final String oleh;

  const StatusLog({
    required this.status,
    required this.waktu,
    required this.oleh,
  });

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'waktu': waktu.toIso8601String(),
        'oleh': oleh,
      };

  factory StatusLog.fromJson(Map<String, dynamic> json) => StatusLog(
        status: ReportStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ReportStatus.diterima,
        ),
        waktu: DateTime.tryParse(json['waktu'] as String? ?? '') ??
            DateTime.now(),
        oleh: json['oleh'] as String? ?? '-',
      );
}
