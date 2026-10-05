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
    
    // Siapkan data nyata (laporan warga + kondisi lingkungan) sebagai bahan
    // jawaban. Data diteruskan dalam bentuk objek, bukan teks, supaya bot
    // bisa menyusun kalimat yang enak dibaca.
    final reportCtrl = context.read<ReportController>();
    final env = context.read<EnvironmentController>();

    final reply = await _callLlama(text, reportCtrl.reports, env);
    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'text': reply ?? 'Maaf, saya belum bisa menjawab itu.'});
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

  /// Ringkasan kondisi lingkungan dalam bentuk teks, dipakai sebagai bahan
  /// untuk AI (bukan untuk ditampilkan langsung ke pengguna).
  String _konteksAi(EnvironmentController env) {
    final baris = <String>[];
    final c = env.cuaca;
    if (c != null) {
      baris.add(
        'Cuaca: ${c.sekarang.kondisi}, ${c.sekarang.suhu.toStringAsFixed(1)} derajat C '
        '(terasa ${c.sekarang.suhuTerasa.toStringAsFixed(1)}), kelembapan ${c.sekarang.kelembapan} persen, '
        'angin ${c.sekarang.kecepatanAngin.toStringAsFixed(0)} km/j dari ${c.sekarang.arahMataAngin}, '
        'prakiraan hujan 24 jam ${c.curahHujan24Jam.toStringAsFixed(1)} mm '
        '(risiko banjir ${c.risikoBanjir.toStringAsFixed(0)} dari 5).',
      );
    }
    final u = env.udara;
    if (u != null) {
      baris.add(
        'Kualitas udara: AQI ${u.aqi} (${u.kategori.label}), PM2.5 ${u.pm25.toStringAsFixed(1)} ug/m3, '
        'PM10 ${u.pm10.toStringAsFixed(1)} ug/m3, indeks UV ${u.indeksUv.toStringAsFixed(1)} (${u.kategoriUv}).',
      );
    }
    final g = env.gempa;
    if (g != null) {
      baris.add(
        'Gempa terkini: magnitudo ${g.magnitude.toStringAsFixed(1)}, kedalaman ${g.kedalaman}, '
        '${g.wilayah}, ${g.tanggal} ${g.jam}, ${g.potensi}.',
      );
    }
    if (baris.isEmpty) return '';
    return 'Kondisi Kota Saat Ini (data resmi):\n${baris.join('\n')}';
  }

  Future<String?> _callLlama(String userMessage, List<Report> laporan, EnvironmentController env) async {
    const apiKey = String.fromEnvironment('LLAMA_API_KEY', defaultValue: '');
    const apiUrl = String.fromEnvironment('LLAMA_API_URL', defaultValue: _titikAiDefault);
    const apiModel = String.fromEnvironment('LLAMA_API_MODEL', defaultValue: _modelAiDefault);

    // Bila kunci AI belum dipasang, jawab dari data nyata yang sudah ada
    // di aplikasi supaya pengguna tetap dapat informasi yang benar.
    if (apiKey.isEmpty || apiKey == 'YOUR_LLAMA_API_KEY') {
      return _jawabLokal(userMessage, laporan, env);
    }

    try {
      final reportsContext = laporan
          .map((r) =>
              '- ${r.jenis} di ${r.kecamatan}, ${DateFormat('dd MMM HH:mm').format(r.createdAt)}, '
              'status ${r.status.label}, ${r.votes} dukungan. Detail: ${r.deskripsi}')
          .join('\n');
      final envContext = _konteksAi(env);

      final systemInstruction =
          '''Anda adalah "Asisten Laporan Warga" pada aplikasi SiagaKota, aplikasi pelaporan banjir dan kerusakan infrastruktur Kota Palembang.

Aturan menjawab:
1. Jawab HANYA berdasarkan data yang diberikan pada konteks. Jangan mengarang kejadian, angka, atau prakiraan.
2. Bila data yang ditanyakan kosong, katakan terus terang bahwa data itu belum ada atau tidak tercatat — jangan menjamin suatu wilayah "aman".
3. Gunakan bahasa Indonesia yang ramah, jelas, dan mengalir seperti percakapan. Hindari daftar bernomor kecuali diminta.
4. Ringkas: cukup 2-4 kalimat untuk pertanyaan sederhana.
5. Tulis satuan dengan wajar (contoh: 28,1 derajat Celsius, bukan 28.1°C).
6. Bila pengguna bertanya di luar topik kota/lingkungan/laporan, arahkan dengan sopan kembali ke topik tersebut.''';

      final promptContext = '''Data laporan warga:
${reportsContext.isEmpty ? 'Belum ada laporan warga yang tercatat.' : reportsContext}

${envContext.isEmpty ? 'Data cuaca, kualitas udara, dan gempa belum tersedia.' : envContext}

Pertanyaan pengguna: "$userMessage"''';

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
        if (isi != null && isi.trim().isNotEmpty) return isi.trim();
        // Jawaban kosong dari server -> pakai jawaban lokal agar tetap guna.
        return _jawabLokal(userMessage, laporan, env);
      } else {
        // Jangan tampilkan pesan error mentah ke pengguna; jawab dari data
        // nyata yang ada, dan catat penyebabnya untuk pengembang.
        debugPrint('[SiagaBot] AI gagal ${response.statusCode}: ${response.body}');
        return _jawabLokal(userMessage, laporan, env);
      }
    } catch (e) {
      // Termasuk gagal jaringan / CORS pada web -> tetap jawab dari data nyata.
      debugPrint('[SiagaBot] AI tidak terjangkau: $e');
      return _jawabLokal(userMessage, laporan, env);
    }
  }

  /// Jawaban yang disusun dari data nyata di aplikasi, dipakai saat kunci AI
  /// belum dipasang atau server AI tidak dapat dihubungi. Ditulis sebagai
  /// kalimat mengalir — bukan tempelan baris data — agar enak dibaca.
  String _jawabLokal(String tanya, List<Report> laporan, EnvironmentController env) {
    final t = tanya.toLowerCase();
    final bagian = <String>[];

    final tanyaCuaca = t.contains('cuaca') || t.contains('hujan') ||
        t.contains('panas') || t.contains('suhu') || t.contains('gerimis') ||
        t.contains('angin');
    final tanyaUdara = t.contains('udara') || t.contains('aqi') ||
        t.contains('polusi') || t.contains('pm2') || t.contains('asap') ||
        t.contains('uv');
    final tanyaGempa = t.contains('gempa') || t.contains('lindu');
    final tanyaLaporan = t.contains('laporan') || t.contains('banjir') ||
        t.contains('jalan') || t.contains('rusak') || t.contains('aduan');

    if (tanyaCuaca) bagian.add(_kalimatCuaca(env));
    if (tanyaUdara) bagian.add(_kalimatUdara(env));
    if (tanyaGempa) bagian.add(_kalimatGempa(env));
    if (tanyaLaporan || bagian.isEmpty) bagian.add(_kalimatLaporan(laporan));

    return bagian.join('\n\n');
  }

  String _kalimatCuaca(EnvironmentController env) {
    final c = env.cuaca;
    if (c == null) {
      return 'Data cuaca belum berhasil dimuat. Coba tekan tombol Perbarui pada kartu Cuaca ya.';
    }
    final s = c.sekarang;
    final sb = StringBuffer(
      'Saat ini cuaca di sekitar Anda ${s.kondisi.toLowerCase()} dengan suhu '
      '${s.suhu.toStringAsFixed(1)} derajat Celsius (terasa ${s.suhuTerasa.toStringAsFixed(1)} derajat). '
      'Kelembapan ${s.kelembapan} persen dan angin bertiup sekitar '
      '${s.kecepatanAngin.toStringAsFixed(0)} kilometer per jam dari arah ${s.arahMataAngin}.',
    );
    final risiko = c.risikoBanjir;
    if (c.curahHujan24Jam >= 0.5) {
      sb.write(
        ' Prakiraan hujan 24 jam ke depan sekitar '
        '${c.curahHujan24Jam.toStringAsFixed(0)} mm.',
      );
    }
    if (risiko >= 4) {
      sb.write(' Karena curah hujan tinggi, potensi banjir perlu diwaspadai.');
    } else if (risiko >= 2) {
      sb.write(' Ada kemungkinan hujan, sebaiknya siapkan payung.');
    }
    return sb.toString();
  }

  String _kalimatUdara(EnvironmentController env) {
    final u = env.udara;
    if (u == null) {
      return 'Data kualitas udara belum berhasil dimuat. Coba tekan tombol Perbarui ya.';
    }
    return 'Kualitas udara saat ini tergolong ${u.kategori.label.toLowerCase()} '
        'dengan indeks AQI ${u.aqi}. Kadar PM2.5 tercatat ${u.pm25.toStringAsFixed(0)} mikrogram per meter kubik '
        'dan PM10 ${u.pm10.toStringAsFixed(0)}. Indeks UV ${u.indeksUv.toStringAsFixed(1)} (${u.kategoriUv.toLowerCase()}). '
        '${u.saran}';
  }

  /// Mengubah catatan "Potensi" dari BMKG menjadi kalimat yang wajar.
  /// Teks aslinya kadang berbunyi "Gempa ini dirasakan untuk diteruskan pada
  /// masyarakat", yang membingungkan bila ditampilkan apa adanya.
  String _potensiGempa(String potensi) {
    final p = potensi.toLowerCase();
    if (p.contains('tidak berpotensi tsunami')) {
      return 'Gempa ini tidak berpotensi menimbulkan tsunami.';
    }
    if (p.contains('berpotensi tsunami')) {
      return 'Gempa ini berpotensi menimbulkan tsunami. Harap waspada.';
    }
    if (p.contains('dirasakan')) {
      return 'Getaran ini dirasakan warga di sekitar lokasi.';
    }
    return potensi;
  }

  String _kalimatGempa(EnvironmentController env) {
    final g = env.gempa;
    if (g == null) {
      return 'Data gempa terbaru belum berhasil dimuat. Coba tekan tombol Perbarui ya.';
    }
    // Teks BMKG sudah berupa kalimat lengkap ("Pusat gempa berada di ..."),
    // jadi tidak perlu ditambah kata pengantar agar tidak berulang.
    // Nama tempat tetap memakai huruf aslinya (bukan dihuruf-kecilkan).
    return 'Gempa terakhir yang tercatat BMKG berkekuatan magnitudo '
        '${g.magnitude.toStringAsFixed(1)} pada kedalaman ${g.kedalaman}. '
        '${g.wilayah}, terjadi ${g.tanggal} pukul ${g.jam}. '
        '${_potensiGempa(g.potensi)}';
  }

  String _kalimatLaporan(List<Report> laporan) {
    if (laporan.isEmpty) {
      return 'Sejauh ini belum ada laporan warga yang tercatat. Kalau Anda menemukan masalah di sekitar, '
          'silakan tekan tombol "Buat Laporan" ya.';
    }
    final aktif = laporan.where((r) => r.status != ReportStatus.selesai).length;
    final banjir = laporan.where((r) => r.jenis == 'Banjir').length;
    final sb = StringBuffer(
      'Saat ini ada ${laporan.length} laporan warga yang tercatat, '
      '$aktif di antaranya masih dalam penanganan.',
    );
    if (banjir > 0) {
      sb.write(' Laporan terkait banjir berjumlah $banjir.');
    }
    // Sebutkan laporan terbaru sebagai contoh.
    final terbaru = laporan.first;
    sb.write(
      ' Laporan terbaru: ${terbaru.jenis} di ${terbaru.kecamatan} '
      '(${terbaru.status.label.toLowerCase()}).',
    );
    return sb.toString();
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
