/// SiagaKota — admin.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/index.dart';
import '../layar/laporan.dart';
import '../models/index.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  ReportStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.isAdmin) {
      // Jika bukan admin, kembali ke beranda.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          IconButton(
            tooltip: 'Reset filter',
            icon: const Icon(Icons.filter_alt_off),
            onPressed:
                _filter == null ? null : () => setState(() => _filter = null),
          ),
        ],
      ),
      body: Consumer<ReportController>(
        builder: (context, rc, child) {
          final list = [...rc.reports]..sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
            );
          Iterable<Report> filtered = list;
          if (_filter != null) {
            filtered = filtered.where((r) => r.status == _filter);
          }
          if (auth.adminKecamatan != 'SEMUA WILAYAH' && auth.adminKecamatan != null) {
            filtered = filtered.where((r) => r.kecamatan == auth.adminKecamatan);
          }
          final filteredList = filtered.toList();

          final total = rc.reports.length;
          final selesai =
              rc.reports.where((r) => r.status == ReportStatus.selesai).length;
          final proses =
              rc.reports.where((r) => r.status == ReportStatus.proses).length;
          final diterima =
              rc.reports.where((r) => r.status == ReportStatus.diterima).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  _AdminStat(label: 'Total', value: '$total'),
                  const SizedBox(width: 10),
                  _AdminStat(label: 'Diterima', value: '$diterima'),
                  const SizedBox(width: 10),
                  _AdminStat(label: 'Proses', value: '$proses'),
                  const SizedBox(width: 10),
                  _AdminStat(label: 'Selesai', value: '$selesai'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Filter status:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  DropdownButton<ReportStatus?>(
                    value: _filter,
                    hint: const Text('Semua'),
                    onChanged: (val) => setState(() => _filter = val),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Semua'),
                      ),
                      ...ReportStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child:
                      Center(child: Text('Belum ada laporan untuk ditinjau')),
                )
              else
                ...filteredList.map(
                  (r) => _AdminCard(
                    report: r,
                    onSetStatus: (status) => rc.updateStatus(r.id, status),
                    onDelete: () => rc.deleteReport(
                      id: r.id,
                      isAdmin: true,
                      requester: auth.userName,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminStat extends StatelessWidget {
  const _AdminStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.report,
    required this.onSetStatus,
    required this.onDelete,
  });

  final Report report;
  final void Function(ReportStatus) onSetStatus;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy • HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  report.jenis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                StatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatter.format(report.createdAt),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Text(report.deskripsi),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoChip(
                  icon: Icons.person,
                  label: report.nama,
                ),
                InfoChip(
                  icon: Icons.map,
                  label: report.kecamatan,
                ),
                InfoChip(
                  icon: Icons.location_on,
                  label:
                      '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                ),
                InfoChip(
                  icon: Icons.priority_high,
                  label: 'Severity ${report.severity.toStringAsFixed(1)}',
                ),
                InfoChip(
                  icon: Icons.how_to_vote,
                  label: '${report.votes} dukungan',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusButton(
                  target: ReportStatus.diterima,
                  current: report.status,
                  label: 'Diterima',
                  color: Colors.orange,
                  onTap: () => onSetStatus(ReportStatus.diterima),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  target: ReportStatus.proses,
                  current: report.status,
                  label: 'Proses',
                  color: Colors.blue,
                  onTap: () => onSetStatus(ReportStatus.proses),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  target: ReportStatus.selesai,
                  current: report.status,
                  label: 'Selesai',
                  color: Colors.green,
                  onTap: () => onSetStatus(ReportStatus.selesai),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade200),
                ),
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus laporan?'),
        content: const Text('Data laporan akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await onDelete();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(ok ? 'Laporan berhasil dihapus' : 'Gagal menghapus laporan'),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.target,
    required this.current,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final ReportStatus target;
  final ReportStatus current;
  final String label;
  final MaterialColor color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = target == current;
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor: active
              ? color.withAlpha((0.14 * 255).round())
              : Colors.grey.shade100,
          foregroundColor: active ? color.shade700 : Colors.black87,
        ),
        onPressed: active ? null : onTap,
        child: Text(label),
      ),
    );
  }
}
