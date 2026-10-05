/// SiagaKota — chatbot.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/index.dart';
import '../models/index.dart';

/// Model & titik layanan AI yang dipakai chatbot.
///
/// Kunci TIDAK ditulis di kode (pernah terjadi sebelumnya: kunci Groq
/// di-hardcode, lalu dihapus sehingga bot mati). Kunci diberikan saat
/// build/run lewat --dart-define=LLAMA_API_KEY=... dan tidak masuk repo.
/// Bila kunci belum dipasang, bot menjawab dari data nyata di aplikasi
/// (lihat _jawabLokal) sehingga tetap berguna.
const String _titikAiDefault = 'https://router.bynara.id/v1/chat/completions';
const String _modelAiDefault = 'glm-5.3-flash';

class SiagaBotWidget extends StatefulWidget {
  const SiagaBotWidget({super.key});
  @override
  State<SiagaBotWidget> createState() => _SiagaBotWidgetState();
}

class _SiagaBotWidgetState extends State<SiagaBotWidget> {
  bool _isOpen = false;
  final _inputCtrl = TextEditingController();
  bool _loading = false;
  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Halo! Saya Asisten Laporan Warga 🤖. Ada yang bisa saya bantu terkait informasi laporan infrastruktur atau kondisi kota hari ini?'},
  ];
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _inputCtrl.clear();
      _loading = true;
    });
    _scrollToBottom();
    
    // Ambil data laporan dari ReportController sebagai context (pengganti tools query database)
    final reportCtrl = context.read<ReportController>();
    final reportsContext = reportCtrl.reports.map((r) => 
      "- Jenis: ${r.jenis}, Waktu: ${DateFormat('dd MMM HH:mm').format(r.createdAt)}, Lokasi: ${r.kecamatan} (${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}), Status: ${r.status.label}, Detail: ${r.deskripsi}"
    ).join('\n');

    // Sertakan data lingkungan nyata (cuaca, kualitas udara, gempa) bila ada.
    final env = context.read<EnvironmentController>();
    final envContext = _bangunKonteksLingkungan(env);

    final reply = await _callLlama(text, reportsContext, envContext);
    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'text': reply ?? 'Maaf, tidak bisa memproses permintaan.'});
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  /// Susun ringkasan kondisi lingkungan untuk diberikan ke AI sebagai konteks.
  String _bangunKonteksLingkungan(EnvironmentController env) {
    final baris = <String>[];
    final c = env.cuaca;
    if (c != null) {
      baris.add(
        'Cuaca saat ini: ${c.sekarang.kondisi}, suhu ${c.sekarang.suhu.toStringAsFixed(1)}°C '
        '(terasa ${c.sekarang.suhuTerasa.toStringAsFixed(1)}°C), kelembapan ${c.sekarang.kelembapan}%, '
        'angin ${c.sekarang.kecepatanAngin.toStringAsFixed(0)} km/j dari ${c.sekarang.arahMataAngin}, '
        'curah hujan 24 jam ke depan ${c.curahHujan24Jam.toStringAsFixed(1)} mm '
        '(risiko banjir ${c.risikoBanjir.toStringAsFixed(0)}/5).',
      );
    }
    final u = env.udara;
    if (u != null) {
      baris.add(
        'Kualitas udara: AQI ${u.aqi} (${u.kategori.label}), PM2.5 ${u.pm25.toStringAsFixed(1)} µg/m³, '
        'PM10 ${u.pm10.toStringAsFixed(1)} µg/m³, indeks UV ${u.indeksUv.toStringAsFixed(1)} (${u.kategoriUv}).',
      );
    }
    final g = env.gempa;
    if (g != null) {
      baris.add(
        'Gempa terkini (BMKG): M${g.magnitude.toStringAsFixed(1)}, kedalaman ${g.kedalaman}, '
        '${g.wilayah}, ${g.tanggal} ${g.jam}, potensi: ${g.potensi}.',
      );
    }
    if (baris.isEmpty) return '';
    return 'Kondisi Kota Saat Ini (data resmi):\n${baris.join('\n')}';
  }

  Future<String?> _callLlama(String userMessage, String reportsContext, String envContext) async {
    const apiKey = String.fromEnvironment('LLAMA_API_KEY', defaultValue: '');
    const apiUrl = String.fromEnvironment('LLAMA_API_URL', defaultValue: _titikAiDefault);
    const apiModel = String.fromEnvironment('LLAMA_API_MODEL', defaultValue: _modelAiDefault);
    
    // Bila kunci AI belum dipasang, jawab memakai data nyata yang sudah
    // tersedia di aplikasi (cuaca, kualitas udara, gempa, laporan) supaya
    // pengguna tetap mendapat informasi yang benar — bukan jawaban simulasi.
    if (apiKey.isEmpty || apiKey == 'YOUR_LLAMA_API_KEY') {
       return _jawabLokal(userMessage, reportsContext, envContext);
    }

    try {
      final systemInstruction = '''Anda adalah "Asisten Laporan Warga", bot AI resmi untuk aplikasi pelaporan banjir dan kerusakan infrastruktur. 
Tugas utama Anda adalah memberikan informasi yang akurat dan *real-time* kepada pengguna berdasarkan laporan yang ada di database sistem.

PANDUAN UTAMA & BATASAN (SANGAT PENTING):
1. SUMBER KEBENARAN TUNGGAL: Anda TIDAK BOLEH mengarang, menebak, atau memprediksi kejadian banjir, cuaca, atau kerusakan infrastruktur. Anda HANYA boleh menjawab berdasarkan data laporan yang diberikan pada konteks.
2. ANTI-HALUSINASI: Jika data mengembalikan hasil kosong (tidak ada laporan relevan), Anda harus menjawab bahwa tidak ada laporan yang masuk. (Contoh: "Berdasarkan data kami, saat ini tidak ada laporan banjir di [Lokasi] untuk hari ini.").
3. JANGAN MENJAMIN KESELAMATAN: Jika tidak ada laporan, jangan pernah menyatakan bahwa area tersebut "100% aman". Cukup nyatakan bahwa "tidak ada laporan yang tercatat di sistem".
4. FORMAT JAWABAN (JIKA ADA DATA): Jika data ditemukan, berikan informasi secara ringkas dan terstruktur. Wajib mencakup:
   - Jenis Kejadian (Banjir/Jalan Rusak/dll)
   - Lokasi Spesifik
   - Waktu Laporan Masuk
   - Detail/Status (misal: "tinggi air 50cm" atau "sedang ditangani")
5. NADA BICARA: Profesional, sopan, empati, dan efisien. Jangan gunakan kalimat berbunga-bunga. Pengguna mungkin dalam kondisi darurat, jadi berikan jawaban yang langsung pada intinya.

ALUR KERJA:
- Saat pengguna bertanya, segera identifikasi parameter (kategori kejadian, lokasi, tanggal/waktu).
- Cocokkan dengan "Data Laporan Saat Ini" yang dilampirkan bersama pertanyaan.
- Terjemahkan data mentah dari konteks menjadi kalimat natural yang mudah dibaca pengguna.''';

      final promptContext = '''Data Laporan Saat Ini:
${reportsContext.isEmpty ? "Tidak ada laporan aktif di sistem." : reportsContext}

${envContext.isEmpty ? "Kondisi Kota Saat Ini: data lingkungan belum tersedia." : envContext}

Pertanyaan Pengguna: "$userMessage"''';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://siagakota.app',
          'X-Title': 'SiagaKota',
        },
        body: jsonEncode({
          'model': apiModel,
          'temperature': 0.7,
          'max_tokens': 800,
          'messages': [
            {'role': 'system', 'content': systemInstruction},
            {'role': 'user', 'content': promptContext},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isi = data['choices'][0]['message']['content'] as String?;
        if (isi != null && isi.trim().isNotEmpty) return isi;
        // Jawaban kosong dari server -> pakai jawaban lokal agar bot tetap guna.
        return _jawabLokal(userMessage, reportsContext, envContext);
      } else {
        // Jangan tampilkan pesan error mentah ke pengguna; jawab dari data
        // nyata yang sudah ada, dan catat penyebabnya untuk pengembang.
        debugPrint('[SiagaBot] AI gagal ${response.statusCode}: ${response.body}');
        return _jawabLokal(userMessage, reportsContext, envContext);
      }
    } catch (e) {
      // Termasuk gagal jaringan / CORS pada web -> tetap jawab dari data nyata.
      debugPrint('[SiagaBot] AI tidak terjangkau: $e');
      return _jawabLokal(userMessage, reportsContext, envContext);
    }
  }

  /// Jawaban berbasis data nyata ketika API AI belum dikonfigurasi.
  /// Menjawab pertanyaan umum memakai konteks lingkungan & laporan yang
  /// sudah tersedia, sehingga bot tidak pernah memberi jawaban kosong.
  String _jawabLokal(String tanya, String reportsContext, String envContext) {
    final t = tanya.toLowerCase();
    final bagian = <String>[];

    final tanyaCuaca = t.contains('cuaca') || t.contains('hujan') ||
        t.contains('panas') || t.contains('suhu') || t.contains('gerimis');
    final tanyaUdara = t.contains('udara') || t.contains('aqi') ||
        t.contains('polusi') || t.contains('pm2') || t.contains('asap');
    final tanyaGempa = t.contains('gempa') || t.contains('lindu');
    final tanyaLaporan = t.contains('laporan') || t.contains('banjir') ||
        t.contains('jalan') || t.contains('rusak');

    if (tanyaCuaca) {
      final cuaca = _ambilBaris(envContext, 'Cuaca saat ini');
      bagian.add(cuaca.isNotEmpty
          ? cuaca
          : 'Data cuaca belum tersedia. Coba tekan Perbarui di kartu Cuaca.');
    }
    if (tanyaUdara) {
      final udara = _ambilBaris(envContext, 'Kualitas udara');
      bagian.add(udara.isNotEmpty
          ? udara
          : 'Data kualitas udara belum tersedia. Coba tekan Perbarui.');
    }
    if (tanyaGempa) {
      final gempa = _ambilBaris(envContext, 'Gempa terkini');
      bagian.add(gempa.isNotEmpty
          ? gempa
          : 'Data gempa terbaru belum tersedia saat ini.');
    }
    if (tanyaLaporan || bagian.isEmpty) {
      bagian.add(reportsContext.isEmpty
          ? 'Saat ini tidak ada laporan warga yang tercatat di sistem.'
          : 'Laporan warga yang tercatat:\n$reportsContext');
    }

    if (bagian.isEmpty) {
      return 'Saya bisa membantu soal cuaca, kualitas udara, gempa, dan laporan warga. Silakan tanya salah satunya.';
    }
    return bagian.join('\n\n');
  }

  /// Ambil satu baris konteks yang diawali penanda tertentu.
  String _ambilBaris(String konteks, String penanda) {
    for (final b in konteks.split('\n')) {
      if (b.startsWith(penanda)) return b;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen)
          Container(
            width: 320,
            height: 400,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF818CF8), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Asisten Laporan Warga', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        Text('Pemantauan Real-Time', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                      ])),
                      GestureDetector(
                        onTap: () => setState(() => _isOpen = false),
                        child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                ),
                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_loading && i == _messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(padding: EdgeInsets.only(bottom: 8), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))),
                        );
                      }
                      final msg = _messages[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 240),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF4F46E5) : Colors.white,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isUser ? const Radius.circular(4) : null,
                              bottomLeft: isUser ? null : const Radius.circular(4),
                            ),
                            border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(msg['text'] ?? '', style: TextStyle(fontSize: 13, color: isUser ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.w500)),
                        ),
                      );
                    },
                  ),
                ),
                // Input
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Tanya informasi kota...',
                            hintStyle: const TextStyle(fontSize: 13),
                            filled: true, fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // FAB button
        FloatingActionButton(
          heroTag: 'chatbot_fab',
          onPressed: () => setState(() => _isOpen = !_isOpen),
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Icon(_isOpen ? Icons.close_rounded : Icons.chat_bubble_rounded, color: Colors.white),
        ),
      ],
    );
  }
}
