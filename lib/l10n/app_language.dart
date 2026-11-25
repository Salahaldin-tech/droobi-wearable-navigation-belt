import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language of the app's interface (text and layout direction).
///
/// This is independent from [VoiceLanguage], which only controls the
/// language used for speech recognition.
enum AppLanguage {
  arabic('ar'),
  english('en');

  const AppLanguage(this.code);

  /// ISO 639-1 code stored in preferences and used for the [Locale].
  final String code;

  Locale get locale => Locale(code);

  TextDirection get textDirection =>
      this == AppLanguage.arabic ? TextDirection.rtl : TextDirection.ltr;

  /// Arabic is the default for new installations and for any unknown value.
  static AppLanguage fromCode(String? code) =>
      code == AppLanguage.english.code ? AppLanguage.english : AppLanguage.arabic;
}

/// Reads and writes the selected interface language.
///
/// Uses SharedPreferences, which the app already uses for other settings,
/// so the choice survives app restarts and phone reboots.
class AppLanguageStore {
  const AppLanguageStore._();

  static const String preferencesKey = 'droobi_app_language_v1';

  static Future<AppLanguage> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return AppLanguage.fromCode(preferences.getString(preferencesKey));
    } catch (_) {
      return AppLanguage.arabic;
    }
  }

  static Future<void> save(AppLanguage language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferencesKey, language.code);
  }
}

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier(super.initial);

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    state = language;
    await AppLanguageStore.save(language);
  }
}

/// The current interface language.
///
/// main() overrides this with the value loaded from preferences before the
/// first frame, so the app never flashes the wrong language on start.
final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier(AppLanguage.arabic);
});
