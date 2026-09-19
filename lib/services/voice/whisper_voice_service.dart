import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../../core/enums/voice_language.dart';
import 'voice_input_service.dart';

class WhisperVoiceService implements VoiceInputService {
  WhisperVoiceService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const WhisperModel _model = WhisperModel.small;

  final AudioRecorder _recorder;

  Whisper? _whisper;

  // True from the moment listenForDestination() starts until the recorder
  // has been stopped. Only listenForDestination() may reset it.
  bool _isListening = false;

  // True while Whisper is transcribing.
  bool _isProcessing = false;

  // Set by stopListening(). Remembers a release that happens before the
  // recorder has finished starting.
  bool _stopRequested = false;

  Completer<void>? _recordingStopCompleter;

  @override
  bool get isListening => _isListening;

  @override
  Future<void> ensureModelReady() async {
    _whisper ??= const Whisper(model: _model);
  }

  @override
  Future<String?> listenForDestination({
    required VoiceLanguage language,
    VoidCallback? onRecordingComplete,
  }) async {
    // Prevent multiple recordings/transcriptions from running together.
    if (_isListening || _isProcessing) {
      return null;
    }

    // Mark the session active immediately so an early release is not lost.
    _isListening = true;
    _stopRequested = false;
    _recordingStopCompleter = Completer<void>();

    String? recordedPath;

    try {
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
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
        path: path,
      );

      // If the user already released during setup, do not wait.
      if (!_stopRequested) {
        // Wait here until stopListening() is called.
        await _recordingStopCompleter!.future;
      }

      // Stop the recorder and get the finished WAV path.
      recordedPath = await _recorder.stop();
    } catch (_) {
      // Never leave the recorder running after an error.
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      rethrow;
    } finally {
      _isListening = false;
      _recordingStopCompleter = null;
    }

    // Recording is fully stopped at this point.
    onRecordingComplete?.call();

    if (recordedPath == null || !File(recordedPath).existsSync()) {
      return null;
    }

    _isProcessing = true;
    final watch = Stopwatch()..start();

    try {
      debugPrint(
        'Whisper: file ${File(recordedPath).lengthSync()} bytes, starting',
      );

      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: recordedPath,
          language: language.whisperCode,
          isTranslate: false,
        ),
      );

      debugPrint(
        'Whisper: finished in ${watch.elapsedMilliseconds} ms, '
        'text: "${result.text}"',
      );

      final text = result.text.trim();

      return text.isEmpty ? null : text;
    } finally {
      _isProcessing = false;

      final file = File(recordedPath);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    // Do NOT change _isListening here.
    // listenForDestination() resets it after the recorder has stopped.
    _stopRequested = true;

    final completer = _recordingStopCompleter;

    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}