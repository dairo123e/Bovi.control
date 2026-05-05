// lib/config_autenticacion/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// desde esta subcarpeta subimos un nivel a lib/
import '../home_login.dart';
import '../menu.dart';
import '../services/auth_service.dart';

/// Componente que decide si mostrar Login o Menu según la sesión
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const HomeScreen();

        return FutureBuilder<void>(
          future: AuthService().ensureRoleNormalizedForCurrentUser(),
          builder: (context, normalizeSnap) {
            if (normalizeSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return MenuPage();
          },
        );
      },
    );
  }
}
