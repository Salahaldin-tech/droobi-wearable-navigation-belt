/// The language the user is speaking in, for voice destination input.
///
/// This drives which Whisper language code is passed to transcription
/// (multilingual Whisper models, never an English-only .en model
/// variant - Arabic support depends on this).
enum VoiceLanguage {
  arabic,
  english,
}

extension VoiceLanguageWhisperCode on VoiceLanguage {
  /// The ISO 639-1 code Whisper expects.
  String get whisperCode {
    switch (this) {
      case VoiceLanguage.arabic:
        return 'ar';
      case VoiceLanguage.english:
        return 'en';
    }
  }

  String get label {
    switch (this) {
      case VoiceLanguage.arabic:
        return 'Arabic';
      case VoiceLanguage.english:
        return 'English';
    }
  }
}
