/// SiagaKota — masuk.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components.dart';
import '../controllers/index.dart';
import '../layar/auth_gate.dart';
import '../models/index.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final controller = TextEditingController();
  final adminPassController = TextEditingController();
  String _adminKecamatan = kecamatanPalembang.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_handleNameChanged);
    controller.dispose();
    adminPassController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final hasAccounts = auth.accounts.isNotEmpty;
        final canCreate = !_saving && controller.text.trim().isNotEmpty;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Stack(
            children: [
              // Background orbs
              Positioned(
                top: -80, left: -80,
                child: Container(
                  width: 360, height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF818CF8).withAlpha(50),
                      const Color(0xFF818CF8).withAlpha(0),
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: -80, right: -80,
                child: Container(
                  width: 360, height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF60A5FA).withAlpha(50),
                      const Color(0xFF60A5FA).withAlpha(0),
                    ]),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: FadeInScale(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo & Title
                            Column(
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5).withAlpha(80),
                                        blurRadius: 24, offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
                                ),
                                const SizedBox(height: 20),
                                RichText(
                                  text: const TextSpan(
                                    text: 'SiagaKota',
                                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
                                    children: [
                                      TextSpan(text: '.', style: TextStyle(color: Color(0xFF2563EB))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Platform Tata Kota & Pengaduan Cerdas',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 36),
                            // Glass card
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(220),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: Colors.white.withAlpha(180)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(12),
                                    blurRadius: 40, offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Officer portal button
                                  _buildAdminEntryCard(),
                                  const SizedBox(height: 24),
                                  // Divider
                                  Row(
                                    children: [
                                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text('AKSES WARGA', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFCBD5E1), letterSpacing: 2)),
                                      ),
                                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Existing accounts
                                  if (hasAccounts) ...[
                                    ...auth.accounts.map((name) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _buildAccountCard(
                                        name: name,
                                        onTap: () async {
                                          await auth.loginWithExisting(name);
                                          if (!context.mounted) return;
                                          Navigator.of(context).pushAndRemoveUntil(
                                            MaterialPageRoute(builder: (_) => const AuthGate()),
                                            (route) => false,
                                          );
                                        },
                                      ),
                                    )),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text('BUAT AKUN BARU', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFCBD5E1), letterSpacing: 2)),
                                        ),
                                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildNameField(),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 58,
                                    child: FilledButton.icon(
                                      icon: _saving
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.person_add_alt_1_rounded),
                                      label: Text(_saving ? 'Menyimpan...' : 'Simpan & Masuk'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: canCreate ? const Color(0xFF4F46E5) : const Color(0xFFD9E3F1),
                                        foregroundColor: canCreate ? Colors.white : const Color(0xFF8FA4C3),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                      onPressed: canCreate ? () => _createAccount(auth) : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              '© 2026 SIAGAKOTA PALEMBANG',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), letterSpacing: 2.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createAccount(AuthController auth) async {
    final name = controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama akun tidak boleh kosong')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await auth.createAccount(name);
      if (!mounted) return;
      controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun tersimpan dan login berhasil')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan akun: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openAdminLogin() async {
    final auth = context.read<AuthController>();
    adminPassController.clear();
    final success = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Masuk mode Admin'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adminPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password admin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _adminKecamatan,
                  decoration: const InputDecoration(
                    labelText: 'Kecamatan yang dikelola',
                    border: OutlineInputBorder(),
                  ),
                  items: kecamatanPalembang
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(k),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      _adminKecamatan = val ?? kecamatanPalembang.first,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await auth.loginAsAdmin(
                    password: adminPassController.text,
                    kecamatan: _adminKecamatan,
                  );
                  if (!ok) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Password admin salah')),
                    );
                    return;
                  }
                  if (mounted) {
                    navigator.pop(true);
                  }
                },
                child: const Text('Masuk'),
              ),
            ],
          ),
        ) ??
        false;

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  Widget _buildAdminEntryCard() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openAdminLogin,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(60),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Masuk Portal Petugas',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard({
    required String name,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withAlpha(15),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_circle_outlined, color: Color(0xFF4F46E5), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
                        const SizedBox(width: 5),
                        const Text('Terverifikasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: 'Nama akun',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD6E0ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD6E0ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF84B6FF), width: 1.8),
        ),
      ),
      onSubmitted: (_) {
        if (!_saving && controller.text.trim().isNotEmpty) {
          _createAccount(context.read<AuthController>());
        }
      },
    );
  }
}
