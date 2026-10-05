/// SiagaKota — form laporan.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../controllers/index.dart';
import '../models/index.dart';

enum LocationLabelMode { street, coordinate }

class ReportFormPage extends StatefulWidget {
  const ReportFormPage({super.key, this.draft});

  final ReportDraft? draft;

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final deskripsiController = TextEditingController();
  String jenis = 'Banjir';
  double severity = 3;
  String _selectedKecamatan = kecamatanPalembang.first;
  Position? position;
  String? _alamatJalan;
  bool _alamatLoading = false;
  LocationLabelMode _locationLabelMode = LocationLabelMode.coordinate;
  String? fotoPath;
  Uint8List? fotoBytes;
  bool loadingLocation = false;

  // Voice to text states
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  // Vision AI state
  bool _analyzingImage = false;

  Future<void> _analyzeImage() async {
    if (fotoBytes == null && fotoPath == null) return;
    setState(() => _analyzingImage = true);
    
    try {
      final apiKey = const String.fromEnvironment('LLAMA_API_KEY', defaultValue: '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');
      final apiUrl = const String.fromEnvironment('LLAMA_API_URL', defaultValue: 'https://api.openrouter.ai/api/v1/chat/completions');
      if (apiKey == 'YOUR_LLAMA_API_KEY' || apiKey.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          deskripsiController.text = 'Terdapat kerusakan infrastruktur yang cukup parah berdasarkan foto. (Hasil Simulasi Vision AI)';
          jenis = 'Infrastruktur Rusak';
          severity = 4;
        });
      } else {
        Uint8List imageBytes;
        if (fotoBytes != null) {
          imageBytes = fotoBytes!;
        } else {
          imageBytes = await File(fotoPath!).readAsBytes();
        }
        final base64Image = base64Encode(imageBytes);

        final promptText = "Analisis foto ini untuk laporan masalah kota. Tentukan 3 hal: 1. Jenis laporan (Banjir, Infrastruktur Rusak, atau Pohon Tumbang), 2. Tingkat keparahan (angka 1 sampai 5), 3. Deskripsi singkat masalah yang terlihat. Format jawaban: 'Jenis: [jenis]\\nKeparahan: [angka]\\nDeskripsi: [deskripsi]'";

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'temperature': 0.3,
          'max_tokens': 300,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': promptText},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                  }
                ]
              }
            ],
          }),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['choices'][0]['message']['content'] ?? '';
          if (text.isNotEmpty) {
          // Parse results simple
          final lines = text.split('\n');
          String newJenis = jenis;
          double newSeverity = severity;
          String newDesc = deskripsiController.text;

          for (final line in lines) {
            if (line.toLowerCase().startsWith('jenis:')) {
              final val = line.split(':')[1].trim();
              if (['Banjir', 'Infrastruktur Rusak', 'Pohon Tumbang'].contains(val)) {
                newJenis = val;
              }
            } else if (line.toLowerCase().startsWith('keparahan:')) {
              final val = double.tryParse(line.split(':')[1].trim());
              if (val != null && val >= 1 && val <= 5) newSeverity = val;
            } else if (line.toLowerCase().startsWith('deskripsi:')) {
              newDesc = line.split(':')[1].trim();
            }
          }
          setState(() {
            jenis = newJenis;
            severity = newSeverity;
            if (deskripsiController.text.isEmpty) {
              deskripsiController.text = newDesc;
            } else {
              deskripsiController.text += '\n(AI Analysis): $newDesc';
            }
          });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menganalisis foto. Error: ${response.statusCode}')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menganalisis foto: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _analyzingImage = false);
      }
    }
  }

  @override
  void dispose() {
    namaController.dispose();
    deskripsiController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initSpeech();
    final d = widget.draft;
    if (d != null) {
      namaController.text = d.nama;
      deskripsiController.text = d.deskripsi;
      jenis = d.jenis;
      severity = d.severity;
      _selectedKecamatan = d.kecamatan;
      if (d.fotoPath != null) fotoPath = d.fotoPath;
      if (d.fotoBase64 != null) {
        fotoBytes = base64Decode(d.fotoBase64!);
      }
    }
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (e) => debugPrint("Speech Error: $e"),
        onStatus: (s) => debugPrint("Speech Status: $s"),
      );
      setState(() {});
    } catch (e) {
      debugPrint("Speech Init Error: $e");
    }
  }

  void _startListening() async {
    await _speech.listen(onResult: _onSpeechResult);
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(dynamic result) {
    setState(() {
      // Perbarui controller deskripsi secara real-time
      deskripsiController.text = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Laporan')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama Pelapor'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Masukkan nama' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: jenis,
                decoration: const InputDecoration(labelText: 'Jenis laporan'),
                items: const [
                  DropdownMenuItem(value: 'Banjir', child: Text('Banjir')),
                  DropdownMenuItem(
                    value: 'Infrastruktur Rusak',
                    child: Text('Infrastruktur Rusak'),
                  ),
                  DropdownMenuItem(
                    value: 'Pohon Tumbang',
                    child: Text('Pohon tumbang'),
                  ),
                ],
                onChanged: (val) => setState(() => jenis = val ?? 'Banjir'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedKecamatan,
                decoration: const InputDecoration(labelText: 'Kecamatan'),
                items: kecamatanPalembang
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(k),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(
                    () => _selectedKecamatan = val ?? kecamatanPalembang.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: deskripsiController,
                decoration: InputDecoration(
                  labelText: 'Deskripsi',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : null,
                    ),
                    onPressed: () {
                      if (!_speechEnabled) {
                        _initSpeech(); // Coba inisialisasi ulang jika gagal
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fitur suara belum siap atau izin mikrofon ditolak. Pastikan izin diberikan.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      if (_isListening) {
                        _stopListening();
                      } else {
                        _startListening();
                      }
                    },
                  ),
                ),
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Masukkan deskripsi' : null,
              ),
              const SizedBox(height: 12),
              Text('Tingkat keparahan'),
              Slider(
                value: severity,
                min: 1,
                max: 5,
                divisions: 4,
                label: severity.toStringAsFixed(1),
                onChanged: (val) => setState(() => severity = val),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: loadingLocation ? null : _ambilLokasi,
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        loadingLocation ? 'Mengambil...' : 'Ambil lokasi GPS',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pilihLokasiDiPeta,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Pilih di peta'),
                    ),
                  ),
                ],
              ),
              if (position != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tampilan lokasi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<LocationLabelMode>(
                        segments: const [
                          ButtonSegment(
                            value: LocationLabelMode.street,
                            icon: Icon(Icons.route),
                            label: Text('Nama jalan'),
                          ),
                          ButtonSegment(
                            value: LocationLabelMode.coordinate,
                            icon: Icon(Icons.pin_drop),
                            label: Text('Koordinat'),
                          ),
                        ],
                        selected: {_locationLabelMode},
                        onSelectionChanged: (values) {
                          if (values.isEmpty) return;
                          _onLocationModeChanged(values.first);
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildLocationPreview(),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFoto,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Tambah foto'),
                  ),
                  const SizedBox(width: 12),
                  if (fotoPath != null)
                    Expanded(
                      child: Text(
                        File(fotoPath!).path.split(Platform.pathSeparator).last,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (fotoBytes != null)
                    const Expanded(
                      child: Text(
                        'Foto terpilih',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (fotoPath != null || fotoBytes != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: fotoBytes != null
                        ? Image.memory(
                            fotoBytes!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Foto tidak dapat dimuat'),
                            ),
                          )
                        : Image.file(
                            File(fotoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Foto tidak dapat dimuat'),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _analyzingImage ? null : _analyzeImage,
                    icon: _analyzingImage 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                    label: Text(_analyzingImage ? 'Menganalisis...' : 'Analisis Foto dengan AI (Magic Autofill)'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveDraft,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Simpan draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Kirim laporan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ambilLokasi() async {
    setState(() => loadingLocation = true);
    try {
      final pos = await _getPrecisePosition();
      if (pos == null) return;
      await _setPosition(pos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal ambil lokasi: $e')));
    } finally {
      if (mounted) {
        setState(() => loadingLocation = false);
      }
    }
  }

  Future<void> _setPosition(Position pos) async {
    if (!mounted) return;
    setState(() {
      position = pos;
      if (_locationLabelMode == LocationLabelMode.coordinate) {
        _alamatJalan = null;
        _alamatLoading = false;
      }
    });
    if (_locationLabelMode == LocationLabelMode.street) {
      await _fetchAlamat(pos);
    }
  }

  Future<void> _fetchAlamat(Position pos) async {
    setState(() {
      _alamatLoading = true;
      _alamatJalan = null;
    });
    try {
      final places = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        if (places.isNotEmpty) {
          final p = places.first;
          final parts = [
            if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
            if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
            if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          ];
          _alamatJalan = parts.isEmpty ? null : parts.join(', ');
        } else {
          _alamatJalan = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _alamatJalan = null);
    } finally {
      if (mounted) {
        setState(() => _alamatLoading = false);
      }
    }
  }

  void _onLocationModeChanged(LocationLabelMode mode) {
    if (_locationLabelMode == mode) return;
    setState(() => _locationLabelMode = mode);
    if (mode == LocationLabelMode.street &&
        position != null &&
        _alamatJalan == null) {
      _fetchAlamat(position!);
    }
  }

  Widget _buildLocationPreview() {
    if (position == null) {
      return const SizedBox.shrink();
    }
    String label;
    if (_locationLabelMode == LocationLabelMode.street) {
      if (_alamatLoading) {
        label = 'Mengambil nama jalan...';
      } else {
        label = _alamatJalan ?? 'Nama jalan belum tersedia';
      }
    } else {
      label =
          '${position!.latitude.toStringAsFixed(4)}, ${position!.longitude.toStringAsFixed(4)}';
    }
    return Row(
      children: [
        Icon(Icons.place, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pilihLokasiDiPeta() async {
    final initial = position != null
        ? LatLng(position!.latitude, position!.longitude)
        : null;
    final selected = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(initialCenter: initial),
      ),
    );
    if (selected == null) return;
    await _setPosition(_positionFromLatLng(selected));
  }

  Position _positionFromLatLng(LatLng point) {
    return Position(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      floor: null,
      isMocked: false,
    );
  }

  Future<Position?> _getPrecisePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktifkan layanan lokasi')),
        );
      }
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 8),
      );
    } on TimeoutException catch (_) {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final source = await _selectSource();
    if (source == null) return;

    final file = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) return;

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      setState(() {
        fotoBytes = bytes;
        fotoPath = null;
      });
    } else {
      setState(() {
        fotoPath = file.path;
        fotoBytes = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (position == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          const SnackBar(content: Text('Pilih lokasi terlebih dahulu')));
      return;
    }
    if ((jenis == 'Infrastruktur Rusak' || jenis == 'Pohon Tumbang') &&
        fotoPath == null &&
        fotoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jenis ini memerlukan foto')),
      );
      return;
    }

    final controller = context.read<ReportController>();
    final auth = context.read<AuthController>();
    // Sertakan risiko banjir dari data cuaca nyata (bila sudah dimuat),
    // agar laporan banjir lebih diprioritaskan saat hujan lebat.
    final env = context.read<EnvironmentController>();
    await controller.addReport(
      nama: namaController.text,
      jenis: jenis,
      deskripsi: deskripsiController.text,
      severity: severity,
      kecamatan: _selectedKecamatan,
      owner: auth.userName ?? namaController.text,
      position: position!,
      fotoPath: fotoPath,
      fotoBytes: fotoBytes,
      weatherRisk: jenis == 'Banjir' ? env.risikoBanjir : null,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _saveDraft() async {
    final draft = ReportDraft(
      nama: namaController.text,
      jenis: jenis,
      deskripsi: deskripsiController.text,
      severity: severity,
      kecamatan: _selectedKecamatan,
      fotoPath: fotoPath,
      fotoBase64: fotoBytes != null ? base64Encode(fotoBytes!) : null,
    );
    final controller = context.read<ReportController>();
    await controller.addDraft(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft disimpan')));
    Navigator.pop(context);
  }

  Future<ImageSource?> _selectSource() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Ambil dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, this.initialCenter});

  final LatLng? initialCenter;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late LatLng _center;
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? const LatLng(-6.2000, 106.8166);
    _selected = widget.initialCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih lokasi di peta'),
        actions: [
          TextButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.pop<LatLng>(context, _selected),
            child: const Text(
              'Pakai',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 15,
          minZoom: 3,
          maxZoom: 18,
          onTap: (tapPosition, point) {
            setState(() => _selected = point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.siagakota',
          ),
          if (_selected != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selected!,
                  width: 42,
                  height: 42,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 36,
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selected == null
                    ? 'Ketuk peta untuk memilih titik.'
                    : 'Dipilih: ${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
