/// SiagaKota — auth gate.
/// Berkas ini dipisah dari main.dart agar tiap layar berdiri sendiri.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/index.dart';
import '../layar/beranda.dart';
import '../layar/masuk.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (!auth.isReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isLoggedIn) {
          return const HomeShell();
        }
        return const LoginPage();
      },
    );
  }
}
