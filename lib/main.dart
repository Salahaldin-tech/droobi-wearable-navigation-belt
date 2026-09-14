import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'screens/test/ble_test_screen.dart';

/// STAGE 5 ENTRY POINT (temporary).
///
/// This currently boots straight into the BLE test screen so the
/// Flutter <-> ESP32 communication layer can be validated in
/// isolation, before any real UI (Home Screen, auth, navigation,
/// etc.) is built on top of it.
///
/// STAGE 6 ADDITION: Firebase is now initialized before runApp() so
/// the auth/Firestore services (lib/services/firebase/) work at
/// runtime. firebase_options.dart is NOT included here - it must be
/// generated locally by running `flutterfire configure` against your
/// own Firebase project (see setup steps provided separately). This
/// file will not compile until that generated file exists.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: DroobiTestApp()));
}

class DroobiTestApp extends StatelessWidget {
  const DroobiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Droobi (BLE Test)',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const BleTestScreen(),
    );
  }
}
