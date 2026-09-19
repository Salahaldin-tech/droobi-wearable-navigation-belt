import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums/voice_language.dart';

/// The language the user is currently speaking in for voice input.
/// Defaults to Arabic (primary target user base); switchable at
/// runtime via the Settings screen (Voice Language section).
class VoiceLanguageNotifier extends StateNotifier<VoiceLanguage> {
  VoiceLanguageNotifier() : super(VoiceLanguage.arabic);

  void setLanguage(VoiceLanguage language) {
    state = language;
  }
}

final voiceLanguageProvider =
    StateNotifierProvider<VoiceLanguageNotifier, VoiceLanguage>((ref) {
  return VoiceLanguageNotifier();
});