import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/index.dart';
import '../theme.dart';

/// Panel khusus petugas yang menampilkan ringkasan laporan warga.
///
/// Seluruh angka dihitung dari data laporan yang benar-benar ada — tidak ada
/// nilai contoh, simulasi, atau karangan. Bila belum ada laporan, panel
/// menampilkan keterangan kosong yang jujur.
class PantauanLaporanPanel extends StatelessWidget {
  const PantauanLaporanPanel({super.key, required this.reports});

  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    final total = reports.length;
    final urgensiTinggi = reports.where((r) => r.severity >= 4).length;
    final proses =
        reports.where((r) => r.status == ReportStatus.proses).length;
    final selesai =
        reports.where((r) => r.status == ReportStatus.selesai).length;
    final diterima = total - proses - selesai;

    final perJenis = <String, int>{};
    for (final r in reports) {
      perJenis[r.jenis] = (perJenis[r.jenis] ?? 0) + 1;
    }
    final jenisUrut = perJenis.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxJenis = jenisUrut.isEmpty ? 1 : jenisUrut.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Color(0xFF60A5FA), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Pantauan Laporan Warga',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$total laporan',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _RingkasanAngka(
                  label: 'Diterima',
                  nilai: diterima,
                  warna: const Color(0xFFFB923C)),
              _RingkasanAngka(
                  label: 'Diproses',
                  nilai: proses,
                  warna: const Color(0xFF818CF8)),
              _RingkasanAngka(
                  label: 'Selesai',
                  nilai: selesai,
                  warna: const Color(0xFF34D399)),
              _RingkasanAngka(
                  label: 'Urgensi ≥4',
                  nilai: urgensiTinggi,
                  warna: const Color(0xFFF87171)),
            ],
          ),
          const SizedBox(height: 18),
          const Text('JENIS LAPORAN TERBANYAK',
              style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          if (jenisUrut.isEmpty)
            const Text('Belum ada laporan masuk.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
          else
            ...jenisUrut.take(4).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Text('${e.value}',
                                style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.value / maxJenis,
                            minHeight: 6,
                            backgroundColor: const Color(0xFF1E293B),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF60A5FA)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _RingkasanAngka extends StatelessWidget {
  const _RingkasanAngka({
    required this.label,
    required this.nilai,
    required this.warna,
  });

  final String label;
  final int nilai;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$nilai',
              style: TextStyle(
                  color: warna, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Papan tindak lanjut petugas: menampilkan laporan dengan prioritas tertinggi
/// dan catatan aktivitas terbaru.
///
/// Sebelumnya panel ini bernama "CCTV AI Live Feed" dan menampilkan kotak
/// deteksi ("VEHICLE 98%", "ANOMALY") serta catatan waktu yang seluruhnya
/// dikarang. Kini isinya diambil dari data laporan nyata.
class PapanTindakLanjutPanel extends StatelessWidget {
  const PapanTindakLanjutPanel({super.key, required this.reports});

  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    final urutPrioritas = [...reports]
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    final prioritas = urutPrioritas.isEmpty ? null : urutPrioritas.first;

    final terbaru = [...reports]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final log = terbaru.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.rule_folder_outlined,
                      color: Color(0xFF818CF8), size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Papan Tindak Lanjut',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle,
                        color: Color(0xFF34D399), size: 10),
                    SizedBox(width: 5),
                    Text('DATA NYATA',
                        style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PRIORITAS PENANGANAN',
                    style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                if (prioritas == null)
                  const Text('Belum ada laporan yang perlu ditangani.',
                      style: TextStyle(
                          color: Color(0xFF64748B), fontSize: 12))
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020817),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: severityColor(prioritas.severity)
                              .withAlpha(90)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 42,
                          decoration: BoxDecoration(
                            color: severityColor(prioritas.severity),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${prioritas.jenis} • ${prioritas.kecamatan}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                  'Severity ${prioritas.severity.toStringAsFixed(1)} • '
                                  '${prioritas.votes} dukungan • '
                                  '${prioritas.status.label}',
                                  style: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('AKTIVITAS TERBARU',
                    style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                if (log.isEmpty)
                  const Text('> Belum ada aktivitas.',
                      style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFF34D399),
                          fontSize: 10))
                else
                  ...log.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '> [${DateFormat('dd/MM HH:mm').format(r.createdAt)}] '
                        '${r.jenis} di ${r.kecamatan} (${r.status.label})',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF34D399),
                            fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
