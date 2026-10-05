import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/index.dart';

/// Menyimpan pemberitahuan dalam aplikasi (mis. perubahan status laporan).
///
/// Data disimpan di SharedPreferences supaya tetap ada setelah aplikasi
/// ditutup. Setiap perubahan diberitahukan lewat [notifyListeners] agar
/// lencana jumlah belum dibaca ikut diperbarui.
class PemberitahuanController extends ChangeNotifier {
  static const _kunci = 'pemberitahuan';

  final List<Pemberitahuan> _items = [];
  bool _dimuat = false;

  PemberitahuanController() {
    muat();
  }

  List<Pemberitahuan> get items => List.unmodifiable(_items);

  /// Jumlah pemberitahuan yang belum dibaca.
  int get jumlahBelumDibaca => _items.where((p) => !p.dibaca).length;

  bool get siap => _dimuat;

  Future<void> muat() async {
    if (_dimuat) return;
    _dimuat = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kunci);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => Pemberitahuan.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _items
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {
      // Abaikan data rusak agar aplikasi tidak macet.
    }
  }

  Future<void> _simpan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kunci,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Abaikan kegagalan simpan.
    }
  }

  /// Menambah pemberitahuan baru (paling atas).
  Future<void> tambah(Pemberitahuan p) async {
    _items.insert(0, p);
    // Batasi agar tidak menumpuk tanpa batas.
    if (_items.length > 100) {
      _items.removeRange(100, _items.length);
    }
    await _simpan();
    notifyListeners();
  }

  /// Membuat pemberitahuan perubahan status sebuah laporan.
  Future<void> tambahPerubahanStatus({
    required Report report,
    required ReportStatus status,
  }) async {
    await tambah(
      Pemberitahuan(
        id: '${report.id}-${status.name}-${DateTime.now().millisecondsSinceEpoch}',
        judul: 'Status laporan berubah',
        pesan: '${report.jenis} di ${report.kecamatan} kini ${status.label}.',
        waktu: DateTime.now(),
        reportId: report.id,
      ),
    );
  }

  Future<void> tandaiDibaca(String id) async {
    final idx = _items.indexWhere((p) => p.id == id);
    if (idx == -1 || _items[idx].dibaca) return;
    _items[idx].dibaca = true;
    await _simpan();
    notifyListeners();
  }

  Future<void> tandaiSemuaDibaca() async {
    if (jumlahBelumDibaca == 0) return;
    for (final p in _items) {
      p.dibaca = true;
    }
    await _simpan();
    notifyListeners();
  }

  Future<void> bersihkan() async {
    if (_items.isEmpty) return;
    _items.clear();
    await _simpan();
    notifyListeners();
  }
}
