import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'voice_input_service.dart';

/// Concrete VoiceInputService using the speech_to_text package
/// (on-device platform speech recognition, per Stage 2's decision to
/// use platform STT rather than a cloud voice API).
///
/// This is the only file that imports speech_to_text directly.
class SpeechToTextVoiceService implements VoiceInputService {
  SpeechToTextVoiceService({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<String?> listenForDestination() async {
    final available = await _speech.initialize();
    if (!available) {
      return null;
    }

    final completer = Completer<String?>();
    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          final text = result.recognizedWords.trim();
          completer.complete(text.isEmpty ? null : text);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
      partialResults: false,
    );

    // Safety net: resolve with whatever we have (or null) if the
    // recognizer never fires a final result within the listen window.
    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );

    _isListening = false;
    return result;
  }

  @override
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }
}
