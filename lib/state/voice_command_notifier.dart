import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums/voice_command_state.dart';
import '../services/accessibility/feedback_service.dart';
import '../services/accessibility/flutter_tts_feedback_service.dart';
import '../services/voice/voice_input_service.dart';
import '../services/voice/whisper_voice_service.dart';
import 'destination_search_notifier.dart';
import 'voice_language_notifier.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FlutterTtsFeedbackService();
});

/// Local Whisper (whisper.cpp via whisper_flutter_new), replacing the
/// earlier speech_to_text-backed implementation. See
/// lib/services/voice/whisper_voice_service.dart for the important
/// note on the one-time model download.
final voiceInputServiceProvider = Provider<VoiceInputService>((ref) {
  return WhisperVoiceService();
});

/// Orchestrates: tap mic -> record -> transcribe (Whisper) ->
/// recognize -> confirm -> search.
///
/// This is the Home Screen mic's entry point into the existing Stage 7
/// destination search pipeline - recognized text is not acted on
/// blindly, it's surfaced for confirmation first (per Stage 5's
/// confirm-then-act design), then handed to destinationSearchProvider.
class VoiceCommandNotifier extends StateNotifier<VoiceCommandState> {
  VoiceCommandNotifier(this._ref, this._voiceInput, this._feedback)
      : super(const VoiceCommandState());

  final Ref _ref;
  final VoiceInputService _voiceInput;
  final FeedbackService _feedback;

  Future<void> startListening() async {
    state = state.copyWith(
      phase: VoiceCommandPhase.listening,
      clearRecognizedText: true,
      clearError: true,
    );
    await _feedback.announce(
      'Listening',
      priority: AnnouncementPriority.normal,
    );

    final language = _ref.read(voiceLanguageProvider);

    final text = await _voiceInput.listenForDestination(
      language: language,
      onRecordingComplete: () {
        // Whisper's record-then-transcribe flow means there's a real
        // gap here (local inference) worth reflecting in the UI/audio
        // state, unlike the old streaming speech_to_text flow where
        // recognition was effectively instantaneous.
        state = state.copyWith(phase: VoiceCommandPhase.processing);
      },
    );

    if (text == null || text.trim().isEmpty) {
      state = state.copyWith(
        phase: VoiceCommandPhase.error,
        errorMessage: "Sorry, I didn't catch that. Please try again.",
      );
      await _feedback.announce(
        "Sorry, I didn't catch that. Please try again.",
        priority: AnnouncementPriority.normal,
      );
      return;
    }

    state = state.copyWith(
      phase: VoiceCommandPhase.recognized,
      recognizedText: text,
    );
    await _feedback.announce(
      'Did you mean $text?',
      priority: AnnouncementPriority.normal,
    );
  }

  /// User confirmed the recognized text - hand off to destination
  /// search (Stage 7's existing service/provider).
  Future<void> confirmAndSearch() async {
    final text = state.recognizedText;
    if (text == null) return;

    state = state.copyWith(phase: VoiceCommandPhase.processing);
    await _ref.read(destinationSearchProvider.notifier).search(text);
    state = state.copyWith(phase: VoiceCommandPhase.idle, clearRecognizedText: true);
  }

  void reset() {
    state = const VoiceCommandState();
  }
}

final voiceCommandProvider =
    StateNotifierProvider<VoiceCommandNotifier, VoiceCommandState>((ref) {
  final voiceInput = ref.watch(voiceInputServiceProvider);
  final feedback = ref.watch(feedbackServiceProvider);
  return VoiceCommandNotifier(ref, voiceInput, feedback);
});
