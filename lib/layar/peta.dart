/// SiagaKota — peta.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/index.dart';

/// Peta sebaran laporan warga.
///
/// Menampilkan penanda laporan, area rawan (hotspot), kotak pencarian untuk
/// menyaring laporan berdasarkan jenis/kecamatan, dan legenda warna penanda.
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.reports,
    required this.hotspots,
    required this.currentPosition,
    required this.onRefreshLocation,
  });

  final List<Report> reports;
  final List<Hotspot> hotspots;
  final Position? currentPosition;
  final Future<void> Function() onRefreshLocation;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  final TextEditingController _cariController = TextEditingController();
  String _kataKunci = '';

  @override
  void dispose() {
    _cariController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Laporan yang lolos penyaringan kotak pencarian.
  List<Report> get _laporanTampil {
    if (_kataKunci.trim().isEmpty) return widget.reports;
    final k = _kataKunci.toLowerCase();
    return widget.reports
        .where((r) =>
            r.jenis.toLowerCase().contains(k) ||
            r.kecamatan.toLowerCase().contains(k) ||
            r.status.label.toLowerCase().contains(k))
        .toList();
  }

  /// Warna penanda menurut tingkat keparahan laporan.
  Color _warnaPenanda(Report r) {
    if (r.severity >= 4.5) return const Color(0xFFDC2626);
    if (r.severity >= 3.5) return const Color(0xFFEA580C);
    if (r.severity >= 2.5) return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
  }

  /// Pusatkan peta ke sebuah laporan (dipakai saat hasil pencarian diketuk).
  void _fokuskan(Report r) {
    _mapController.move(LatLng(r.latitude, r.longitude), 16);
  }

  @override
  Widget build(BuildContext context) {
    final laporan = _laporanTampil;

    final circles = widget.hotspots
        .map(
          (h) => CircleMarker(
            point: LatLng(h.latitude, h.longitude),
            radius: 80,
            color: Colors.red.withAlpha((0.18 * 255).round()),
            borderColor: Colors.red.shade600,
            borderStrokeWidth: 2,
          ),
        )
        .toList();

    final markers = <Marker>[
      if (widget.currentPosition != null)
        Marker(
          point: LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          ),
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Colors.blue),
        ),
      ...laporan.map(
        (r) => Marker(
          point: LatLng(r.latitude, r.longitude),
          width: 42,
          height: 42,
          child: Tooltip(
            message: '${r.jenis}\n${r.kecamatan}\n${r.status.label} • '
                'keparahan ${r.severity.toStringAsFixed(1)}',
            child: Icon(Icons.location_on, color: _warnaPenanda(r)),
          ),
        ),
      ),
    ];

    // Titik awal peta: lokasi pengguna, lalu laporan pertama, lalu Palembang.
    final center = widget.currentPosition != null
        ? LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          )
        : (laporan.isNotEmpty
            ? LatLng(laporan.first.latitude, laporan.first.longitude)
            : const LatLng(-2.9761, 104.7754));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _cariController,
            onChanged: (v) => setState(() => _kataKunci = v),
            decoration: InputDecoration(
              hintText: 'Cari jenis atau kecamatan…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: _kataKunci.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _cariController.clear();
                        setState(() => _kataKunci = '');
                      },
                    ),
            ),
          ),
        ),
        if (_kataKunci.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                laporan.isEmpty
                    ? 'Tidak ada laporan yang cocok.'
                    : '${laporan.length} laporan cocok',
                style: TextStyle(
                  fontSize: 12,
                  color: laporan.isEmpty
                      ? Colors.red.shade700
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: widget.onRefreshLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Segarkan lokasi'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openNearestNavigation(context),
                icon: const Icon(Icons.directions),
                label: const Text('Laporan terdekat'),
              ),
              const Spacer(),
              if (widget.hotspots.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.hotspots.length} titik rawan',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  minZoom: 3,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'id.siagakota.siagakota',
                    maxZoom: 19,
                  ),
                  if (circles.isNotEmpty) CircleLayer(circles: circles),
                  MarkerLayer(markers: markers),
                ],
              ),
              // Legenda warna penanda — supaya warna pin tidak jadi teka-teki.
              const Positioned(left: 12, bottom: 12, child: LegendaPeta()),
              // Daftar hasil pencarian — ketuk untuk menyorot di peta.
              if (_kataKunci.isNotEmpty && laporan.isNotEmpty)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 220,
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: laporan.length,
                      itemBuilder: (ctx, i) {
                        final r = laporan[i];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: Icon(Icons.location_on,
                              size: 18, color: _warnaPenanda(r)),
                          title: Text(r.jenis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          subtitle: Text(r.kecamatan,
                              style: const TextStyle(fontSize: 11)),
                          onTap: () => _fokuskan(r),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openNearestNavigation(BuildContext context) async {
    if (widget.currentPosition == null || widget.reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Lokasi atau laporan belum tersedia. Coba segarkan lokasi terlebih dahulu.'),
        ),
      );
      return;
    }
    final nearest = _nearestReport();
    final lat = nearest.latitude;
    final lng = nearest.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Tidak dapat membuka Google Maps. Pastikan aplikasi browser atau Google Maps terinstall.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka navigasi: $e')),
        );
      }
    }
  }

  Report _nearestReport() {
    final d = Distance();
    final origin = LatLng(
      widget.currentPosition!.latitude,
      widget.currentPosition!.longitude,
    );
    Report? nearest;
    double best = double.infinity;
    for (final r in widget.reports) {
      final dist = d(origin, LatLng(r.latitude, r.longitude));
      if (dist < best) {
        best = dist;
        nearest = r;
      }
    }
    return nearest ?? widget.reports.first;
  }
}

/// Keterangan warna penanda peta.
///
/// Dibuat publik agar bisa diuji langsung tanpa membangun seluruh peta.
class LegendaPeta extends StatelessWidget {
  const LegendaPeta({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('Keterangan',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          BarisLegenda(warna: Color(0xFF16A34A), teks: 'Ringan (1–2,4)'),
          BarisLegenda(warna: Color(0xFFD97706), teks: 'Sedang (2,5–3,4)'),
          BarisLegenda(warna: Color(0xFFEA580C), teks: 'Berat (3,5–4,4)'),
          BarisLegenda(warna: Color(0xFFDC2626), teks: 'Sangat berat (≥4,5)'),
          SizedBox(height: 4),
          BarisLegenda(
              warna: Color(0xFF2563EB),
              teks: 'Lokasi Anda',
              ikon: Icons.my_location),
        ],
      ),
    );
  }
}

class BarisLegenda extends StatelessWidget {
  const BarisLegenda({
    super.key,
    required this.warna,
    required this.teks,
    this.ikon = Icons.location_on,
  });

  final Color warna;
  final String teks;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: warna),
          const SizedBox(width: 6),
          Text(teks, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
