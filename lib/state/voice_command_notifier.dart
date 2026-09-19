import 'dart:async';

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

final voiceInputServiceProvider = Provider<VoiceInputService>((ref) {
  return WhisperVoiceService();
});

const Duration _confirmationWindow = Duration(milliseconds: 2500);

class VoiceCommandNotifier extends StateNotifier<VoiceCommandState> {
  VoiceCommandNotifier(this._ref, this._voiceInput, this._feedback)
      : super(const VoiceCommandState());

  final Ref _ref;
  final VoiceInputService _voiceInput;
  final FeedbackService _feedback;

  Timer? _confirmationTimer;

  // Used to invalidate old recording/transcription operations.
  int _requestId = 0;

  /// Called when the user PRESSES the microphone.
  ///
  /// Recording starts and continues until onMicRelease() is called.
  Future<void> onMicPress() async {
    // If already recording or processing, do nothing.
    if (state.phase == VoiceCommandPhase.listening ||
        state.phase == VoiceCommandPhase.processing) {
      return;
    }

    // If a previous result was waiting for auto-search, cancel it.
    _cancelConfirmationTimer();
    _requestId++;

    final requestId = _requestId;

    // Stop any TTS before opening the microphone.
    // This prevents the app's own voice from being recorded.
    await _feedback.stop();

    if (!mounted || requestId != _requestId) {
      return;
    }

    state = state.copyWith(
      phase: VoiceCommandPhase.listening,
      clearRecognizedText: true,
      clearError: true,
    );

    final language = _ref.read(voiceLanguageProvider);

    try {
      final text = await _voiceInput.listenForDestination(
        language: language,
        onRecordingComplete: () {
          if (!mounted || requestId != _requestId) {
            return;
          }

          state = state.copyWith(
            phase: VoiceCommandPhase.processing,
          );
        },
      );

      // Ignore an old request if another recording has already started.
      if (!mounted || requestId != _requestId) {
        return;
      }

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

      final recognizedText = text.trim();

      state = state.copyWith(
        phase: VoiceCommandPhase.recognized,
        recognizedText: recognizedText,
      );

      // Speak the result only AFTER recording has completely stopped.
      await _feedback.announce(
        'Did you mean $recognizedText?',
        priority: AnnouncementPriority.normal,
      );

      if (!mounted || requestId != _requestId) {
        return;
      }

      _startConfirmationTimer(
        recognizedText,
        requestId,
      );
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      state = state.copyWith(
        phase: VoiceCommandPhase.error,
        errorMessage: 'Voice recognition failed. Please try again.',
      );
    }
  }

  /// Called when the user RELEASES the microphone.
  ///
  /// This stops the current recording immediately.
  Future<void> onMicRelease() async {
    if (state.phase != VoiceCommandPhase.listening) {
      return;
    }

    await _voiceInput.stopListening();
  }

  void _startConfirmationTimer(
    String text,
    int requestId,
  ) {
    _cancelConfirmationTimer();

    _confirmationTimer = Timer(
      _confirmationWindow,
      () {
        if (!mounted || requestId != _requestId) {
          return;
        }

        if (state.phase != VoiceCommandPhase.recognized) {
          return;
        }

        _proceedToSearch(text, requestId);
      },
    );
  }

  void _cancelConfirmationTimer() {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
  }

  Future<void> _proceedToSearch(
    String text,
    int requestId,
  ) async {
    if (!mounted || requestId != _requestId) {
      return;
    }

    _cancelConfirmationTimer();

    state = state.copyWith(
      phase: VoiceCommandPhase.processing,
    );

    await _ref
        .read(destinationSearchProvider.notifier)
        .search(text);

    if (!mounted || requestId != _requestId) {
      return;
    }

    state = state.copyWith(
      phase: VoiceCommandPhase.idle,
      clearRecognizedText: true,
    );
  }

  /// Optional explicit confirmation.
  Future<void> confirmAndSearch() async {
    final text = state.recognizedText;

    if (text == null || text.trim().isEmpty) {
      return;
    }

    _requestId++;
    final requestId = _requestId;

    await _proceedToSearch(
      text.trim(),
      requestId,
    );
  }

  void reset() {
    _cancelConfirmationTimer();
    _requestId++;

    state = const VoiceCommandState();
  }

  @override
  void dispose() {
    _cancelConfirmationTimer();
    _voiceInput.stopListening();
    super.dispose();
  }
}

final voiceCommandProvider =
    StateNotifierProvider<VoiceCommandNotifier, VoiceCommandState>((ref) {
  final voiceInput = ref.watch(voiceInputServiceProvider);
  final feedback = ref.watch(feedbackServiceProvider);

  return VoiceCommandNotifier(
    ref,
    voiceInput,
    feedback,
  );
});