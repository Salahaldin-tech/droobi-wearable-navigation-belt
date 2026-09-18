import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

/// STAGE 8 ENTRY POINT./// firebase_options.dart is NOT included here - it must be generated
/// locally by running `flutterfire configure` against your own
/// Firebase project (see setup steps provided separately). This file
/// will not compile until that generated file exists.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: DroobiApp()));
}
