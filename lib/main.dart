import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'config_autenticacion/auth_gate.dart';
import 'config/app_theme.dart';
import 'home_login.dart';
import 'OutboxPage.dart';
import 'registro.dart';
import 'services/connectivity_service.dart';
import 'services/offline_outbox_service.dart';
import 'widgets/ui/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await ConnectivityService.instance.init();
  await OfflineOutboxService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BoviControll',
      theme: AppTheme.light,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const Align(
              alignment: Alignment.topCenter,
              child: OfflineBanner(),
            ),
          ],
        );
      },
      // El AuthGate decide si mostrar MenuPage o HomeScreen
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/registro': (context) => const RegistroPage(),
        '/menu': (context) => const AuthGate(),
        OutboxPage.routeName: (context) => const OutboxPage(),
      },
    );
  }
}
