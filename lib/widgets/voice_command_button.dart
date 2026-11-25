import 'package:flutter/material.dart';

import '../core/enums/voice_command_state.dart';

import '../core/theme/app_colors.dart';
import '../l10n/l10n.dart';

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
          context.tr('Voice Command', 'الأمر الصوتي'),
          context.tr(
            'Press and hold to speak your destination',
            'اضغط مطولًا وانطق اسم وجهتك',
          ),
          Icons.mic,
          AppColors.brown,
        ),
      VoiceCommandPhase.listening => (
          context.tr('Listening', 'جارٍ الاستماع'),
          context.tr('Release to finish speaking', 'ارفع إصبعك لإنهاء التحدث'),
          Icons.mic,
          AppColors.brown,
        ),
      VoiceCommandPhase.processing => (
          context.tr('Processing your request', 'جارٍ معالجة طلبك'),
          null,
          Icons.mic,
          AppColors.brown,
        ),
      VoiceCommandPhase.recognized => (
          context.tr(
            'Heard: ${widget.state.recognizedText ?? ""}',
            'سمعت: ${widget.state.recognizedText ?? ""}',
          ),
          context.tr(
            'Waiting to search destination',
            'بانتظار البحث عن الوجهة',
          ),
          Icons.mic,
          AppColors.brown,
        ),
      VoiceCommandPhase.error => (
          context.tr("Sorry, I didn't catch that", 'عذرًا، لم أتمكن من فهم ذلك'),
          context.tr('Press and hold to try again', 'اضغط مطولًا للمحاولة مرة أخرى'),
          Icons.mic_off,
          AppColors.brown,
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
                color: color.withValues(alpha: 0.15),
                border: Border.all(
                  color: color,
                  width: 4,
                ),
                boxShadow: widget.state.phase ==
                        VoiceCommandPhase.listening
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
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