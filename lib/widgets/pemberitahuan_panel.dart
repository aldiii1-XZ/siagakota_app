import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/index.dart';

/// Ikon lonceng dengan lencana jumlah pemberitahuan yang belum dibaca.
///
/// Ketuk untuk membuka daftar pemberitahuan dalam aplikasi. Dipakai agar
/// warga tetap tahu kabar laporannya tanpa bergantung pada izin notifikasi
/// sistem.
class LoncengPemberitahuan extends StatelessWidget {
  const LoncengPemberitahuan({super.key});

  @override
  Widget build(BuildContext context) {
    final jumlah = context.watch<PemberitahuanController>().jumlahBelumDibaca;

    return IconButton(
      tooltip: 'Pemberitahuan',
      onPressed: () => _bukaDaftar(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded),
          if (jumlah > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  jumlah > 99 ? '99+' : '$jumlah',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _bukaDaftar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const PanelPemberitahuan(),
    );
  }
}

/// Daftar pemberitahuan dalam aplikasi.
class PanelPemberitahuan extends StatelessWidget {
  const PanelPemberitahuan({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<PemberitahuanController>();
    final items = ctrl.items;
    final fmt = DateFormat('dd MMM, HH:mm');

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  const Text(
                    'Pemberitahuan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: ctrl.tandaiSemuaDibaca,
                      child: const Text('Tandai semua dibaca'),
                    ),
                ],
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 40, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 10),
                    Text(
                      'Belum ada pemberitahuan.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kabar perubahan status laporanmu akan muncul di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return ListTile(
                      leading: Icon(
                        p.dibaca
                            ? Icons.mark_email_read_outlined
                            : Icons.circle,
                        color: p.dibaca
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF2563EB),
                        size: p.dibaca ? 22 : 12,
                      ),
                      title: Text(
                        p.judul,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              p.dibaca ? FontWeight.w500 : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${p.pesan}\n${fmt.format(p.waktu)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                      onTap: () => ctrl.tandaiDibaca(p.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
