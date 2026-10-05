/// SiagaKota — laporan.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../components.dart';
import '../controllers/index.dart';
import '../layar/form_laporan.dart';
import '../models/index.dart';
import '../theme.dart';

class ReportListView extends StatelessWidget {
  const ReportListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (context, controller, _) {
        final auth = context.watch<AuthController>();
        final items = auth.isAdmin
            ? (auth.adminKecamatan == 'SEMUA WILAYAH' || auth.adminKecamatan == null
                ? controller.sortedReports
                : controller.sortedReports
                    .where((r) => r.kecamatan == auth.adminKecamatan)
                    .toList())
            : controller.sortedReports
                .where((r) => r.owner == auth.userName || r.jenis == 'Pengumuman')
                .toList();
        final drafts = controller.drafts;

        if (items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (drafts.isNotEmpty)
                DraftsBanner(drafts: drafts, controller: controller),
              EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Belum ada laporan',
                subtitle: 'Mulai buat laporan untuk wilayahmu.',
                iconColor: AppTheme.primary,
                action: FilledButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Buat laporan'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportFormPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length + (drafts.isNotEmpty ? 1 : 0),
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (drafts.isNotEmpty) {
              if (index == 0) {
                return DraftsBanner(drafts: drafts, controller: controller);
              }
              final report = items[index - 1];
              return ReportCard(report: report);
            }
            final report = items[index];
            return ReportCard(report: report);
          },
        );
      },
    );
  }
}

class DraftsBanner extends StatelessWidget {
  const DraftsBanner({
    super.key,
    required this.drafts,
    required this.controller,
  });

  final List<ReportDraft> drafts;
  final ReportController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Draft laporan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: drafts
                  .map(
                    (d) => InputChip(
                      label: Text(d.jenis),
                      avatar: const Icon(Icons.drafts, size: 18),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportFormPage(draft: d),
                          ),
                        );
                        await controller.removeDraft(d);
                      },
                      onDeleted: () => controller.removeDraft(d),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ReportController>();
    final auth = context.watch<AuthController>();
    final formatter = DateFormat('dd MMM HH:mm');
    
    final isSos = report.jenis == 'Darurat SOS';
    final isPengumuman = report.jenis == 'Pengumuman';

    return Card(
      color: isSos ? const Color(0xFFFEF2F2) : (isPengumuman ? const Color(0xFFFFFBEB) : Colors.white),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isSos ? const BorderSide(color: Color(0xFFFECACA), width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: severityColor(
                      report.severity,
                    ).withAlpha((0.15 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    report.severity.toStringAsFixed(1),
                    style: TextStyle(
                      color: severityColor(report.severity),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.jenis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatter.format(report.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: report.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.deskripsi,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF334155),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoChip(icon: Icons.map, label: report.kecamatan),
                InfoChip(icon: Icons.place, label: _coordLabel(report)),
                if (report.duplicateOf != null)
                  InfoChip(icon: Icons.link, label: 'Duplikasi'),
                InfoChip(
                  icon: Icons.how_to_vote,
                  label: '${report.votes} dukungan',
                ),
              ],
            ),
            if (report.photoUrl != null || report.fotoBytes != null || report.fotoPath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: report.photoUrl != null
                      ? Image.network(
                          report.photoUrl!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _imageError(),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 220,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        )
                      : report.fotoBytes != null
                          ? Image.memory(
                              report.fotoBytes!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _imageError(),
                            )
                          : Image.file(
                              File(report.fotoPath!),
                              height: 220,
                              width: double.infinity,
                              cacheHeight: 1080,
                              cacheWidth: 1920,
                              filterQuality: FilterQuality.high,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _imageError(),
                            ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () => controller.upvote(report.id),
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                  color: Colors.indigo,
                ),
                Text('${report.votes}'),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Bagikan laporan',
                  onPressed: () {
                    final shareText = '🚨 [Info Warga] Laporan ${report.jenis} di ${report.kecamatan}!\n\n'
                        'Detail: ${report.deskripsi}\n'
                        'Lokasi: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}\n\n'
                        'Bantu upvote laporan ini di aplikasi SiagaKota agar segera ditangani!\n'
                        'Cek detailnya di: https://siagakota.id/report/${report.id}';
                    Share.share(shareText);
                  },
                  icon: const Icon(Icons.share_outlined),
                  color: Colors.blueGrey,
                ),
                const Spacer(),
                IconButton(
                  tooltip: auth.isAdmin ? 'Hapus laporan' : 'Tarik laporan',
                  onPressed: () => _confirmDelete(context, controller, auth),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade500,
                ),
                if (auth.isAdmin)
                  PopupMenuButton<ReportStatus>(
                    tooltip: 'Ubah status',
                    onSelected: (val) =>
                        controller.updateStatus(report.id, val),
                    itemBuilder: (_) => ReportStatus.values
                        .map(
                          (s) => PopupMenuItem(
                            value: s,
                            child: Text(s.label),
                          ),
                        )
                        .toList(),
                    child: const Icon(Icons.more_vert),
                  )
                else
                  Tooltip(
                    message: 'Hanya admin yang dapat mengubah status',
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _coordLabel(Report r) =>
      '${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}';

  Future<void> _confirmDelete(
    BuildContext context,
    ReportController controller,
    AuthController auth,
  ) async {
    final isAdmin = auth.isAdmin;
    final title = isAdmin ? 'Hapus laporan?' : 'Tarik laporan?';
    final message = isAdmin
        ? 'Laporan akan dihapus permanen.'
        : 'Laporan akan ditarik dan tidak tampil lagi.';
    final actionLabel = isAdmin ? 'Hapus' : 'Tarik';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await controller.deleteReport(
      id: report.id,
      isAdmin: isAdmin,
      requester: auth.userName,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Laporan berhasil ${isAdmin ? 'dihapus' : 'ditarik'}'
              : 'Gagal menghapus laporan',
        ),
      ),
    );
  }

  Widget _imageError() => Container(
        height: 220,
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.blueGrey.shade300),
            const SizedBox(height: 8),
            Text('Foto tidak tersedia', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12)),
          ],
        ),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: status.color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
