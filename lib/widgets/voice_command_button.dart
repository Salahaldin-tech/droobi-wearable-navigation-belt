import 'package:flutter/material.dart';

import '../core/enums/voice_command_state.dart';

/// The Home Screen's primary, centered microphone action.
///
/// The button uses press-and-hold interaction:
/// - Press and hold -> start recording
/// - Release -> stop recording
///
/// A subtle animation provides visual feedback while listening.
class VoiceCommandButton extends StatefulWidget {
  const VoiceCommandButton({
    super.key,
    required this.state,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final VoiceCommandState state;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  State<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends State<VoiceCommandButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant VoiceCommandButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.state.phase == VoiceCommandPhase.listening) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
    } else {
      _animationController.stop();
      _animationController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 150),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePressStart() {
    if (widget.state.phase == VoiceCommandPhase.processing) {
      return;
    }

    setState(() {
      _isPressed = true;
    });

    widget.onPressStart();
  }

  void _handlePressEnd() {
    if (!_isPressed) {
      return;
    }

    setState(() {
      _isPressed = false;
    });

    widget.onPressEnd();
  }

  @override
  Widget build(BuildContext context) {
    final (semanticLabel, semanticHint, icon, color) =
        switch (widget.state.phase) {
      VoiceCommandPhase.idle => (
          'Voice Command',
          'Press and hold to speak your destination',
          Icons.mic,
          Colors.indigo,
        ),
      VoiceCommandPhase.listening => (
          'Listening',
          'Release to finish speaking',
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
          'Heard: ${widget.state.recognizedText ?? ""}',
          'Waiting to search destination',
          Icons.mic,
          Colors.green,
        ),
      VoiceCommandPhase.error => (
          "Sorry, I didn't catch that",
          'Press and hold to try again',
          Icons.mic_off,
          Colors.grey,
        ),
    };

    final isProcessing =
        widget.state.phase == VoiceCommandPhase.processing;

    return Semantics(
      button: true,
      label: semanticLabel,
      hint: semanticHint,
      liveRegion: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isProcessing
            ? null
            : (_) {
                _handlePressStart();
              },
        onTapUp: isProcessing
            ? null
            : (_) {
                _handlePressEnd();
              },
        onTapCancel: isProcessing
            ? null
            : _handlePressEnd,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(
                  color: color,
                  width: 4,
                ),
                boxShadow: widget.state.phase ==
                        VoiceCommandPhase.listening
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.25),
                          blurRadius: 18,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: 72,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}