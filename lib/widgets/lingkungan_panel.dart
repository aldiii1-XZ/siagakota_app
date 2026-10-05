import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/index.dart';
import '../models/index.dart';

/// Panel informasi lingkungan untuk dashboard SiagaKota.
/// Menampilkan tiga kartu: cuaca & prakiraan, kualitas udara, dan gempa
/// terkini. Seluruh data berasal dari API publik gratis.
class PanelLingkungan extends StatelessWidget {
  const PanelLingkungan({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnvironmentController>(
      builder: (context, env, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded,
                    size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  'KONDISI KOTA HARI INI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                _RefreshButton(
                  loading: env.statusCuaca == StatusData.memuat ||
                      env.statusUdara == StatusData.memuat,
                  onTap: () => _refresh(env),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final lebar = c.maxWidth >= 760;
                final kartuCuaca = _KartuCuaca(
                  status: env.statusCuaca,
                  cuaca: env.cuaca,
                );
                final kartuUdara = _KartuUdara(
                  status: env.statusUdara,
                  udara: env.udara,
                );
                if (lebar) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: kartuCuaca),
                      const SizedBox(width: 14),
                      Expanded(child: kartuUdara),
                    ],
                  );
                }
                return Column(
                  children: [
                    kartuCuaca,
                    const SizedBox(height: 14),
                    kartuUdara,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _KartuGempa(status: env.statusGempa, gempa: env.gempa),
          ],
        );
      },
    );
  }

  /// Perbarui data memakai lokasi perangkat saat ini. Bila lokasi tidak
  /// tersedia, cukup perbarui gempa dan biarkan cuaca/udara apa adanya.
  Future<void> _refresh(EnvironmentController env) async {
    final pos = await env.lokasiSaatIni();
    if (pos != null) {
      await env.muat(lat: pos.latitude, lon: pos.longitude, paksa: true);
    }
    await env.muatGempa(paksa: true);
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded,
                    size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              'Perbarui',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// KARTU CUACA
// ═══════════════════════════════════════════════════════════════════════

class _KartuCuaca extends StatelessWidget {
  const _KartuCuaca({required this.status, required this.cuaca});
  final StatusData status;
  final DataCuaca? cuaca;

  @override
  Widget build(BuildContext context) {
    return _KartuDasar(
      judul: 'Cuaca',
      ikon: Icons.wb_cloudy_rounded,
      warna: const Color(0xFF2563EB),
      status: status,
      anak: cuaca == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(cuaca!.sekarang.ikon,
                        size: 46, color: const Color(0xFF2563EB)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cuaca!.sekarang.suhu.toStringAsFixed(1)}°C',
                            style: GoogleFonts.inter(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cuaca!.sekarang.kondisi,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          Text(
                            'Terasa ${cuaca!.sekarang.suhuTerasa.toStringAsFixed(1)}°C',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChipKecil(
                      ikon: Icons.water_drop_outlined,
                      label: '${cuaca!.sekarang.kelembapan}%',
                    ),
                    _ChipKecil(
                      ikon: Icons.air_rounded,
                      label:
                          '${cuaca!.sekarang.kecepatanAngin.toStringAsFixed(0)} km/j',
                    ),
                    _ChipKecil(
                      ikon: Icons.explore_outlined,
                      label: cuaca!.sekarang.arahMataAngin,
                    ),
                    _ChipKecil(
                      ikon: Icons.cloud_outlined,
                      label: '${cuaca!.sekarang.tutupanAwan}%',
                    ),
                  ],
                ),
                if (cuaca!.sekarang.sedangHujan ||
                    cuaca!.risikoBanjir >= 2) ...[
                  const SizedBox(height: 12),
                  _PeringatanHujan(cuaca: cuaca!),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                Text(
                  'PRAKIRAAN 5 HARI',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: cuaca!.prakiraan
                      .take(5)
                      .map((p) => Expanded(child: _KolomPrakiraan(p: p)))
                      .toList(),
                ),
              ],
            ),
    );
  }
}

class _PeringatanHujan extends StatelessWidget {
  const _PeringatanHujan({required this.cuaca});
  final DataCuaca cuaca;

  @override
  Widget build(BuildContext context) {
    final risiko = cuaca.risikoBanjir;
    final tinggi = risiko >= 4;
    final warna = tinggi ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final teks = tinggi
        ? 'Waspada banjir: prakiraan hujan ${cuaca.curahHujan24Jam.toStringAsFixed(0)} mm/24 jam.'
        : 'Berpotensi hujan ${cuaca.curahHujan24Jam.toStringAsFixed(0)} mm/24 jam.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: warna.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(tinggi ? Icons.warning_amber_rounded : Icons.umbrella_rounded,
              size: 16, color: warna),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teks,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KolomPrakiraan extends StatelessWidget {
  const _KolomPrakiraan({required this.p});
  final PrakiraanHarian p;

  @override
  Widget build(BuildContext context) {
    const namaHari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final hari = namaHari[(p.tanggal.weekday - 1) % 7];
    return Column(
      children: [
        Text(
          hari,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Icon(p.ikon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(height: 6),
        Text(
          '${p.suhuMax.toStringAsFixed(0)}°',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        Text(
          '${p.suhuMin.toStringAsFixed(0)}°',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// KARTU KUALITAS UDARA
// ═══════════════════════════════════════════════════════════════════════

class _KartuUdara extends StatelessWidget {
  const _KartuUdara({required this.status, required this.udara});
  final StatusData status;
  final KualitasUdara? udara;

  @override
  Widget build(BuildContext context) {
    final u = udara;
    return _KartuDasar(
      judul: 'Kualitas Udara',
      ikon: Icons.eco_rounded,
      warna: u?.kategori.warna ?? const Color(0xFF10B981),
      status: status,
      anak: u == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LingkaranAqi(aqi: u.aqi, warna: u.kategori.warna),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.kategori.label,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Indeks AQI (US EPA)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: u.kategori.warna.withAlpha(22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    u.saran,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Polutan(
                        label: 'PM2.5',
                        nilai: u.pm25.toStringAsFixed(1),
                        satuan: 'µg/m³',
                      ),
                    ),
                    Expanded(
                      child: _Polutan(
                        label: 'PM10',
                        nilai: u.pm10.toStringAsFixed(1),
                        satuan: 'µg/m³',
                      ),
                    ),
                    Expanded(
                      child: _Polutan(
                        label: 'UV',
                        nilai: u.indeksUv.toStringAsFixed(1),
                        satuan: u.kategoriUv,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _LingkaranAqi extends StatelessWidget {
  const _LingkaranAqi({required this.aqi, required this.warna});
  final int aqi;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: warna.withAlpha(28),
        border: Border.all(color: warna, width: 3),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$aqi',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: warna,
              height: 1.0,
            ),
          ),
          Text(
            'AQI',
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: warna,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Polutan extends StatelessWidget {
  const _Polutan({
    required this.label,
    required this.nilai,
    required this.satuan,
  });
  final String label;
  final String nilai;
  final String satuan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          nilai,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            height: 1.0,
          ),
        ),
        Text(
          satuan,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// KARTU GEMPA
// ═══════════════════════════════════════════════════════════════════════

class _KartuGempa extends StatelessWidget {
  const _KartuGempa({required this.status, required this.gempa});
  final StatusData status;
  final GempaTerkini? gempa;

  @override
  Widget build(BuildContext context) {
    final g = gempa;
    return _KartuDasar(
      judul: 'Gempa Terkini (BMKG)',
      ikon: Icons.waves_rounded,
      warna: g?.warna ?? const Color(0xFFF59E0B),
      status: status,
      anak: g == null
          ? null
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: g.warna.withAlpha(28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: g.warna.withAlpha(90)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'M ${g.magnitude.toStringAsFixed(1)}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: g.warna,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        g.kedalaman,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: g.warna,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.wilayah,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Text(
                            '${g.tanggal} • ${g.jam}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              g.potensi,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// KOMPONEN DASAR
// ═══════════════════════════════════════════════════════════════════════

/// Kartu putih dengan judul berikon + penanganan status memuat/gagal.
class _KartuDasar extends StatelessWidget {
  const _KartuDasar({
    required this.judul,
    required this.ikon,
    required this.warna,
    required this.status,
    required this.anak,
  });

  final String judul;
  final IconData ikon;
  final Color warna;
  final StatusData status;
  final Widget? anak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(10),
            blurRadius: 18,
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: warna.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(ikon, size: 16, color: warna),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  judul,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (status == StatusData.memuat)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (anak == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data tidak tersedia. Periksa koneksi lalu tekan Perbarui.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            anak!,
        ],
      ),
    );
  }
}

class _ChipKecil extends StatelessWidget {
  const _ChipKecil({required this.ikon, required this.label});
  final IconData ikon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
