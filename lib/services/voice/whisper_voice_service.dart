import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../../core/enums/voice_language.dart';
import 'voice_input_service.dart';

/// Concrete VoiceInputService using LOCAL Whisper (whisper.cpp via the
/// whisper_flutter_new package) for on-device transcription, and the
/// `record` package for microphone capture to a WAV file.
///
/// This is the only file that imports whisper_flutter_new or record
/// directly.
///
/// IMPORTANT BEHAVIORAL NOTE: the Whisper model weights are downloaded
/// once, on first use, from Hugging Face (requires internet that one
/// time). After that, the model is cached on-device and every
/// subsequent recording + transcription is fully local - no audio and
/// no text ever leaves the device. This is what "local Whisper" means
/// in this implementation; the one-time model download is a real,
/// intentional exception to "no network," not an oversight.
///
/// Model: WhisperModel.base (multilingual - NOT an .en-only variant,
/// since Arabic support depends on using a multilingual model).
/// Swappable via [_model] if a different size/accuracy tradeoff is
/// wanted later (e.g. WhisperModel.small for better accuracy).
class WhisperVoiceService implements VoiceInputService {
  WhisperVoiceService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const WhisperModel _model = WhisperModel.base;

  /// Fixed recording window. whisper_flutter_new/whisper.cpp is
  /// file-based (no built-in voice-activity detection), so unlike the
  /// old speech_to_text flow there's no "final result" signal to stop
  /// on automatically - recording runs for this fixed duration, then
  /// stops and transcribes whatever was captured. Named constant so
  /// it's easy to retune.
  static const Duration _recordingDuration = Duration(seconds: 6);

  final AudioRecorder _recorder;
  Whisper? _whisper;
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<void> ensureModelReady() async {
    // Constructing Whisper is cheap; the actual model
    // download/load happens lazily inside the package on first
    // transcribe() call. Caching the instance here just avoids
    // reconstructing it (and re-triggering that check) every time.
    _whisper ??= Whisper(model: _model);
  }

  @override
  Future<String?> listenForDestination({
    required VoiceLanguage language,
    VoidCallback? onRecordingComplete,
  }) async {
    await ensureModelReady();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/droobi_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _isListening = true;

    await Future.delayed(_recordingDuration);

    final recordedPath = await _recorder.stop();
    _isListening = false;

    // Recording phase is over; transcription (the "processing" phase
    // from the caller's perspective) starts now.
    onRecordingComplete?.call();

    if (recordedPath == null || !File(recordedPath).existsSync()) {
      return null;
    }

    try {
      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: recordedPath,
          language: language.whisperCode,
          isTranslate: false,
        ),
      );

      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } finally {
      // Clean up the temp recording regardless of outcome - it's not
      // needed once transcribed, and these would otherwise accumulate
      // in the temp directory across repeated mic taps.
      final file = File(recordedPath);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  @override
  Future<void> stopListening() async {
    if (_isListening) {
      await _recorder.stop();
      _isListening = false;
    }
  }
}