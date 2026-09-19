import 'package:flutter/foundation.dart';

import '../../core/enums/voice_language.dart';

/// Abstract interface for converting spoken input into text.
///
/// The rest of the app depends only on this interface, never on
/// whisper_flutter_new or the `record` package directly - consistent
/// with the BLE/Auth/Search/Feedback pattern.
///
/// Shape note vs. the previous speech_to_text-backed version: Whisper
/// is record-then-transcribe, not a live streaming recognizer, so:
///  - [language] is required per call (Whisper needs an explicit
///    language code; it doesn't auto-detect a UI-selected language).
///  - [onRecordingComplete] lets the caller (VoiceCommandNotifier)
///    move from a "listening" UI phase to a "processing" one at the
///    exact moment recording stops and transcription begins -
///    otherwise that transition would be invisible to the UI.
///  - [ensureModelReady] lets the caller trigger the one-time model
///    download/load ahead of time (e.g. on Home Screen init) rather
///    than surprising the user with a long delay on their first tap.
abstract class VoiceInputService {
  /// True while actively recording audio.
  bool get isListening;

  /// Triggers the (one-time, cached-after-first-run) Whisper model
  /// load/download. Safe to call repeatedly - a no-op once loaded.
  Future<void> ensureModelReady();

  /// Records audio, then transcribes it in [language]. Resolves with
  /// the recognized text, or null if nothing usable was recognized/
  /// captured. Does not throw for "no speech detected" - that's a
  /// normal outcome represented as a null return, not an exception.
  Future<String?> listenForDestination({
    required VoiceLanguage language,
    VoidCallback? onRecordingComplete,
  });

  /// Stops recording early, if in progress.
  Future<void> stopListening();
}
