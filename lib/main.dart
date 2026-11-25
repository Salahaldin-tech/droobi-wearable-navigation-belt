import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'l10n/app_language.dart';

/// STAGE 8 ENTRY POINT./// firebase_options.dart is NOT included here - it must be generated
/// locally by running `flutterfire configure` against your own
/// Firebase project (see setup steps provided separately). This file
/// will not compile until that generated file exists.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Restore the saved interface language (Arabic on a fresh install)
  // before the first frame so the app always opens in the user's choice.
  final appLanguage = await AppLanguageStore.load();
  runApp(ProviderScope(
    overrides: [
      appLanguageProvider.overrideWith(
        (ref) => AppLanguageNotifier(appLanguage),
      ),
    ],
    child: const DroobiApp(),
  ));
}
