import 'package:flutter_tts/flutter_tts.dart';

import 'feedback_service.dart';

/// Concrete FeedbackService using flutter_tts.
///
/// This is the only file that imports flutter_tts directly.
class FlutterTtsFeedbackService implements FeedbackService {
  FlutterTtsFeedbackService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setSpeechRate(0.5);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
  }

  final FlutterTts _tts;

  AnnouncementPriority? _currentPriority;

  @override
  Future<void> announce(
    String message, {
    AnnouncementPriority priority = AnnouncementPriority.normal,
  }) async {
    // A higher-or-equal priority announcement interrupts whatever is
    // currently speaking; a lower-priority one waits its turn rather
    // than talking over something more important (Stage 3 policy).
    if (_currentPriority != null &&
        priority.index < _currentPriority!.index) {
      return;
    }
    if (_currentPriority != null && priority.index >= _currentPriority!.index) {
      await _tts.stop();
    }
    _currentPriority = priority;
    await _tts.speak(message);
  }

  @override
  Future<void> stop() async {
    _currentPriority = null;
    await _tts.stop();
  }
}
