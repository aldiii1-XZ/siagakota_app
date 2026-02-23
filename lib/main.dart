import 'package:flutter/material.dart';

void main() {
  runApp(const SiagaKotaApp());
}

class SiagaKotaApp extends StatelessWidget {
  const SiagaKotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SiagaKota',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class Report {
  final String nama;
  final String jenis;
  final String deskripsi;

  Report(this.nama, this.jenis, this.deskripsi);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Report> reports = [];

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportForm()),
    );

    if (result != null && result is Report) {
      setState(() {
        reports.insert(0, result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🌊 SiagaKota"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToForm,
        child: const Icon(Icons.add),
      ),
      body: reports.isEmpty
          ? const Center(child: Text("Belum ada laporan"))
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(report.jenis),
                    subtitle: Text(
                        "Pelapor: ${report.nama}\n${report.deskripsi}"),
                    trailing: const Text("Diproses"),
                  ),
                );
              },
            ),
    );
  }
}

class ReportForm extends StatefulWidget {
  const ReportForm({super.key});

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final _formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final deskripsiController = TextEditingController();
  String jenis = "Banjir";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buat Laporan"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(
                  labelText: "Nama Pelapor",
                ),
                validator: (value) =>
                    value!.isEmpty ? "Masukkan nama" : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: jenis,
                items: const [
                  DropdownMenuItem(
                    value: "Banjir",
                    child: Text("Banjir"),
                  ),
                  DropdownMenuItem(
                    value: "Infrastruktur Rusak",
                    child: Text("Infrastruktur Rusak"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    jenis = value.toString();
                  });
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: deskripsiController,
                decoration: const InputDecoration(
                  labelText: "Deskripsi",
                ),
                maxLines: 3,
                validator: (value) =>
                    value!.isEmpty ? "Masukkan deskripsi" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final report = Report(
                      namaController.text,
                      jenis,
                      deskripsiController.text,
                    );
                    Navigator.pop(context, report);
                  }
                },
                child: const Text("Kirim Laporan"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}