/// SiagaKota — dasbor.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/index.dart';
import '../layar/laporan.dart';
import '../models/index.dart';
import '../theme.dart';
import '../widgets/lingkungan_panel.dart';
import '../widgets/papan_petugas.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (ctx, controller, child) {
        final auth = ctx.watch<AuthController>();
        final visible = auth.isAdmin
            ? (auth.adminKecamatan == 'SEMUA WILAYAH' || auth.adminKecamatan == null
                ? controller.reports
                : controller.reports
                    .where((r) => r.kecamatan == auth.adminKecamatan)
                    .toList())
            : controller.reports
                .where((r) => r.owner == auth.userName)
                .toList();
        final total = visible.length;
        final selesai =
            visible.where((r) => r.status == ReportStatus.selesai).length;
        final proses =
            visible.where((r) => r.status == ReportStatus.proses).length;
        final diterima = total - selesai - proses;

        Map<String, int> perJenis = {};
        for (final r in visible) {
          perJenis[r.jenis] = (perJenis[r.jenis] ?? 0) + 1;
        }
        final hotspots = auth.isAdmin
            ? controller.computeHotspots(minCount: 3)
            : controller.computeHotspots(
                source: visible,
                minCount: 3,
              );

        final recentReports = [...visible]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _DashboardHero(
              isAdmin: auth.isAdmin,
              userName: auth.userName,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  title: 'Total Laporan',
                  value: '$total',
                  icon: Icons.assignment_outlined,
                  iconColor: const Color(0xFF2563EB),
                  background: const Color(0xFFEFF6FF),
                ),
                _MetricCard(
                  title: 'Diterima',
                  value: '$diterima',
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFFD97706),
                  background: const Color(0xFFFFF7ED),
                ),
                _MetricCard(
                  title: 'Diproses',
                  value: '$proses',
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  background: const Color(0xFFF5F3FF),
                ),
                _MetricCard(
                  title: 'Selesai',
                  value: '$selesai',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF059669),
                  background: const Color(0xFFECFDF5),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const PanelLingkungan(),
            const SizedBox(height: 20),
            // PANEL PETUGAS — dihitung dari data laporan nyata
            if (auth.isAdmin) ...[
              PantauanLaporanPanel(reports: visible),
              const SizedBox(height: 16),
              PapanTindakLanjutPanel(reports: visible),
              const SizedBox(height: 20),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                final leftPanel = _DashboardReportsPanel(
                  auth: auth,
                  reports: recentReports,
                );
                final rightPanel = Column(
                  children: [
                    _DashboardSummaryPanel(
                      perJenis: perJenis,
                      hotspots: hotspots,
                    ),
                    const SizedBox(height: 16),
                    _DashboardActionsPanel(
                      isAdmin: auth.isAdmin,
                      onExport: () => _showExportSheet(context),
                    ),
                  ],
                );

                if (!isWide) {
                  return Column(
                    children: [
                      leftPanel,
                      const SizedBox(height: 16),
                      rightPanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: leftPanel),
                    const SizedBox(width: 20),
                    Expanded(child: rightPanel),
                  ],
                );
              },
            ),
            if (hotspots.isNotEmpty) ...[
              Text(
                'Wilayah rawan (≥3 laporan dalam radius ~1km)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...hotspots.take(5).map(
                    (h) => ListTile(
                      leading:
                          const Icon(Icons.warning_amber, color: Colors.red),
                      title: Text(
                        '${h.latitude.toStringAsFixed(4)}, ${h.longitude.toStringAsFixed(4)}',
                      ),
                      subtitle: Text(
                        '${h.count} laporan • keparahan rata-rata ${h.averageSeverity.toStringAsFixed(1)}',
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_view),
                title: const Text('Export ke CSV / Excel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, ExportFormat.csv);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export ke PDF'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, ExportFormat.pdf);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Export ke Word (.doc)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, ExportFormat.doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Print langsung'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportData(context, ExportFormat.print);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportData(BuildContext context, ExportFormat format) async {
    final controller = context.read<ReportController>();
    final auth = context.read<AuthController>();
    final data = auth.isAdmin
        ? controller.reports
            .where((r) => r.kecamatan == auth.adminKecamatan)
            .toList()
        : controller.reports.where((r) => r.owner == auth.userName).toList();
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data untuk diexport')),
      );
      return;
    }

    try {
      switch (format) {
        case ExportFormat.csv:
          await _exportCsv(data);
          if (!context.mounted) return;
          _toast(context, 'CSV siap dibagikan');
          break;
        case ExportFormat.pdf:
          await _exportPdf(data, share: true);
          if (!context.mounted) return;
          _toast(context, 'PDF siap dibagikan');
          break;
        case ExportFormat.doc:
          await _exportDoc(data);
          if (!context.mounted) return;
          _toast(context, 'Dokumen .doc siap dibagikan');
          break;
        case ExportFormat.print:
          await _exportPdf(data, share: false, printDirect: true);
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, 'Gagal export: $e');
    }
  }

  Future<void> _exportCsv(List<Report> data) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'Jenis,Nama,Deskripsi,Severity,Status,Kecamatan,Latitude,Longitude,Tanggal,Akun',
    );
    for (final r in data) {
      buffer.writeln(
        '${_csv(r.jenis)},${_csv(r.nama)},${_csv(r.deskripsi)},${r.severity},${r.status.label},${_csv(r.kecamatan)},${r.latitude},${r.longitude},${r.createdAt.toIso8601String()},${_csv(r.owner)}',
      );
    }
    final bytes = utf8.encode(buffer.toString());
    final file = XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: 'siagakota_export.csv',
    );
    await Share.shareXFiles([file], text: 'Export data SiagaKota');
  }

  Future<void> _exportDoc(List<Report> data) async {
    final buffer = StringBuffer();
    buffer.writeln('Data Laporan SiagaKota');
    buffer.writeln('=======================');
    for (final r in data) {
      buffer.writeln(
        '- ${r.jenis} | ${r.nama} | ${r.deskripsi} | Severity ${r.severity} | ${r.status.label} | ${r.kecamatan} | ${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)} | ${DateFormat('dd MMM yyyy HH:mm').format(r.createdAt)} | ${r.owner}',
      );
    }
    final bytes = utf8.encode(buffer.toString());
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/msword',
      name: 'siagakota_export.doc',
    );
    await Share.shareXFiles([file], text: 'Export DOC SiagaKota');
  }

  Future<void> _exportPdf(
    List<Report> data, {
    bool share = true,
    bool printDirect = false,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            'Data Laporan SiagaKota',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: [
              'Jenis',
              'Nama',
              'Deskripsi',
              'Severity',
              'Status',
              'Kecamatan',
              'Koordinat',
              'Tanggal',
              'Akun',
            ],
            data: data
                .map(
                  (r) => [
                    r.jenis,
                    r.nama,
                    r.deskripsi,
                    r.severity.toStringAsFixed(1),
                    r.status.label,
                    r.kecamatan,
                    '${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}',
                    DateFormat('dd MMM yyyy HH:mm').format(r.createdAt),
                    r.owner,
                  ],
                )
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
            columnWidths: {2: const pw.FixedColumnWidth(160)},
          ),
        ],
      ),
    );

    final bytes = await doc.save();

    if (printDirect) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
      return;
    }

    final file = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: 'siagakota_export.pdf',
    );
    await Share.shareXFiles([file], text: 'Export PDF SiagaKota');
  }

  String _csv(String value) {
    final v = value.replaceAll('"', '""');
    return '"$v"';
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.isAdmin,
    required this.userName,
  });

  final bool isAdmin;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAdmin
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF4F46E5), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isAdmin ? const Color(0xFF0F172A) : const Color(0xFF4F46E5)).withAlpha(80),
            blurRadius: 24, offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat Datang, ${userName ?? (isAdmin ? 'Petugas' : 'Warga')} 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(
            isAdmin
                ? 'Kondisi sentimen warga dan laporan aktif hari ini.'
                : 'Ada masalah di fasilitas kota? Laporkan dengan mudah.',
            style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34D399))),
                  const SizedBox(width: 8),
                  Text(userName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  const Text('· Akun Terverifikasi', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.background,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width < 720 ? (width - 44) / 2 : 220.0;
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardReportsPanel extends StatelessWidget {
  const _DashboardReportsPanel({
    required this.auth,
    required this.reports,
  });

  final AuthController auth;
  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  auth.isAdmin
                      ? 'Antrean Laporan Masyarakat'
                      : 'Daftar Laporan Anda',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                ),
              ),
              const Icon(Icons.tune_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada laporan')),
            )
          else
            ...reports.take(3).map((report) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DashboardReportTile(
                    report: report,
                    isAdmin: auth.isAdmin,
                  ),
                )),
        ],
      ),
    );
  }
}

class _DashboardReportTile extends StatelessWidget {
  const _DashboardReportTile({
    required this.report,
    required this.isAdmin,
  });

  final Report report;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM • HH:mm');
    final urgencyColor = severityColor(report.severity);
    final isSos = report.jenis == 'Darurat SOS';
    final isPengumuman = report.jenis == 'Pengumuman';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSos ? const Color(0xFFFEF2F2) : (isPengumuman ? const Color(0xFFFFFBEB) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isSos ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  report.jenis == 'Pohon Tumbang'
                      ? Icons.warning_amber_rounded
                      : Icons.place_outlined,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.deskripsi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.id.substring(0, 8)} • ${report.jenis}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                    ),
                  ],
                ),
              ),
              if (report.severity >= 4)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.kecamatan,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    formatter.format(report.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              StatusChip(status: report.status),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(50)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 12),
                      SizedBox(width: 4),
                      Text('Anti-Hoax: 98% Valid', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(
                isAdmin ? 'Proses Laporan' : 'Lihat Detail',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF2563EB),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSummaryPanel extends StatelessWidget {
  const _DashboardSummaryPanel({
    required this.perJenis,
    required this.hotspots,
  });

  final Map<String, int> perJenis;
  final List<Hotspot> hotspots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Kategori',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          ...perJenis.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.label_outline_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key)),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (hotspots.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Text(
              'Titik Rawan',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            ...hotspots.take(3).map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${h.count} laporan • rata-rata ${h.averageSeverity.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _DashboardActionsPanel extends StatelessWidget {
  const _DashboardActionsPanel({
    required this.isAdmin,
    required this.onExport,
  });

  final bool isAdmin;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAdmin ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isAdmin
                      ? Icons.navigation_outlined
                      : Icons.file_download_outlined,
                  color: isAdmin
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isAdmin ? 'Sistem Navigasi Patroli' : 'Ekspor Data Laporan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAdmin
                ? 'Buka panel ekspor atau tindak lanjuti laporan warga dengan alur yang lebih cepat.'
                : 'Unduh ringkasan laporan Anda dalam format CSV, PDF, Word, atau cetak langsung.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Buka Aksi Export'),
            ),
          ),
        ],
      ),
    );
  }
}
