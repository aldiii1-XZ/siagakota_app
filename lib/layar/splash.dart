/// SiagaKota — splash.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;
import 'dart:async';

import 'package:flutter/material.dart';

import '../components.dart';
import '../layar/auth_gate.dart';
import '../update_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    await _updateService.checkForUpdate(context);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SiagaLoadingWidget(
        message: 'Memuat SiagaKota...',
      ),
    );
  }
}
