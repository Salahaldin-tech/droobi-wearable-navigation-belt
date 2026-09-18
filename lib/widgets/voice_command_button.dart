import 'package:flutter/material.dart';

import '../core/enums/voice_command_state.dart';

/// The Home Screen's primary, centered microphone action.
///
/// State (idle/listening/processing/recognized/error) is always
/// reflected in BOTH the semantic label AND the visual appearance -
/// never appearance/color alone, per Stage 4's explicit requirement.
class VoiceCommandButton extends StatelessWidget {
  const VoiceCommandButton({
    super.key,
    required this.state,
    required this.onTap,
  });

  final VoiceCommandState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (semanticLabel, semanticHint, icon, color) = switch (state.phase) {
      VoiceCommandPhase.idle => (
          'Voice Command',
          'Tap to speak your destination',
          Icons.mic,
          Colors.indigo,
        ),
      VoiceCommandPhase.listening => (
          'Listening',
          'Speak now',
          Icons.mic,
          Colors.red,
        ),
      VoiceCommandPhase.processing => (
          'Processing your request',
          null,
          Icons.mic,
          Colors.orange,
        ),
      VoiceCommandPhase.recognized => (
          'Heard: ${state.recognizedText ?? ""}',
          'Double tap to confirm, or tap again to retry',
          Icons.mic,
          Colors.green,
        ),
      VoiceCommandPhase.error => (
          "Sorry, I didn't catch that",
          'Tap to try again',
          Icons.mic_off,
          Colors.grey,
        ),
    };

    return Semantics(
      button: true,
      label: semanticLabel,
      hint: semanticHint,
      liveRegion: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color, width: 4),
          ),
          child: Icon(icon, size: 72, color: color),
        ),
      ),
    );
  }
}
