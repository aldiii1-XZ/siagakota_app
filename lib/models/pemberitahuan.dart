/// Pemberitahuan di dalam aplikasi (bukan notifikasi sistem).
///
/// Dipakai untuk memberi tahu warga bahwa laporannya berubah status, tanpa
/// bergantung pada izin notifikasi Android yang bisa saja ditolak.
class Pemberitahuan {
  final String id;

  /// Judul singkat, mis. "Status laporan berubah".
  final String judul;

  /// Isi pesan, mis. "Banjir kini Diproses".
  final String pesan;

  final DateTime waktu;

  /// ID laporan terkait (bila ada), agar bisa dibuka dari pemberitahuan.
  final String? reportId;

  bool dibaca;

  Pemberitahuan({
    required this.id,
    required this.judul,
    required this.pesan,
    required this.waktu,
    this.reportId,
    this.dibaca = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'pesan': pesan,
        'waktu': waktu.toIso8601String(),
        'reportId': reportId,
        'dibaca': dibaca,
      };

  factory Pemberitahuan.fromJson(Map<String, dynamic> json) => Pemberitahuan(
        id: json['id'] as String,
        judul: json['judul'] as String? ?? '',
        pesan: json['pesan'] as String? ?? '',
        waktu: DateTime.tryParse(json['waktu'] as String? ?? '') ??
            DateTime.now(),
        reportId: json['reportId'] as String?,
        dibaca: json['dibaca'] as bool? ?? false,
      );
}
