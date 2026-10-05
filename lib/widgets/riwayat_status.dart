import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/index.dart';

/// Jejak penanganan sebuah laporan: kapan statusnya berubah dan oleh siapa.
///
/// Ditampilkan sebagai garis waktu sederhana dari yang paling lama ke
/// terbaru, sehingga warga bisa melihat proses laporannya.
class RiwayatStatusPanel extends StatelessWidget {
  const RiwayatStatusPanel({super.key, required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final riwayat = report.riwayat;
    if (riwayat.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Belum ada riwayat penanganan.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      );
    }

    final fmt = DateFormat('dd MMM yyyy, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < riwayat.length; i++)
          _BarisRiwayat(
            log: riwayat[i],
            terakhir: i == riwayat.length - 1,
            waktu: fmt.format(riwayat[i].waktu),
          ),
      ],
    );
  }
}

class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({
    required this.log,
    required this.terakhir,
    required this.waktu,
  });

  final StatusLog log;
  final bool terakhir;
  final String waktu;

  @override
  Widget build(BuildContext context) {
    final warna = log.status.color;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garis waktu: titik + garis penghubung.
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: warna,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!terakhir)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFFE2E8F0)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: terakhir ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.status.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: warna,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$waktu • ${log.oleh}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
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
