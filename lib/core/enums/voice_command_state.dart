/// State machine for the Home Screen's voice command flow, per Stage 2:
///
///   idle -> listening -> processing -> recognized(text) -> (confirmed)
///                                            |
///                                            v
///                                          error
///
/// Never communicated by appearance/color alone - every transition
/// pairs a semantic label update with a spoken announcement via
/// FeedbackService (enforced in VoiceCommandNotifier, not here).
enum VoiceCommandPhase {
  idle,
  listening,
  processing,
  recognized,
  error,
}

class VoiceCommandState {
  const VoiceCommandState({
    this.phase = VoiceCommandPhase.idle,
    this.recognizedText,
    this.errorMessage,
  });

  final VoiceCommandPhase phase;
  final String? recognizedText;
  final String? errorMessage;

  VoiceCommandState copyWith({
    VoiceCommandPhase? phase,
    String? recognizedText,
    String? errorMessage,
    bool clearRecognizedText = false,
    bool clearError = false,
  }) {
    return VoiceCommandState(
      phase: phase ?? this.phase,
      recognizedText:
          clearRecognizedText ? null : (recognizedText ?? this.recognizedText),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
