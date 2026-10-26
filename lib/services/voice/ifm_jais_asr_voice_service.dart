import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/enums/voice_language.dart';
import 'voice_input_service.dart';

/// Thrown when a transcript conflicts with the selected speech language.
class VoiceLanguageMismatchException implements Exception {
  const VoiceLanguageMismatchException(this.language);

  final VoiceLanguage language;

  @override
  String toString() => 'Speech did not match the selected language';
}

/// IFM-hosted Jais-ASR speech-to-text service.
///
/// WARNING: compile-time defines are embedded in the client app. Use this
/// direct-API configuration only for local testing. Production must call a
/// backend that keeps the IFM API key secret.
class IfmJaisAsrVoiceService implements VoiceInputService {
  IfmJaisAsrVoiceService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const String _endpoint =
      'https://api.ifm.ai/v1/audio/transcriptions';
  static const String _model = 'IFM/Jais-ASR';
  static const String _apiKey = String.fromEnvironment('IFM_API_KEY');

  static const int _minWavBytes = 44 + 9600;

  final AudioRecorder _recorder;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _stopRequested = false;
  Completer<void>? _recordingStopCompleter;

  @override
  bool get isListening => _isListening;

  @override
  Future<void> ensureModelReady() async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'IFM API key is missing. Run with --dart-define=IFM_API_KEY=...',
      );
    }
  }

  @override
  Future<String?> listenForDestination({
    required VoiceLanguage language,
    VoidCallback? onRecordingComplete,
  }) async {
    if (_isListening || _isProcessing) return null;
    await ensureModelReady();

    _isListening = true;
    _stopRequested = false;
    _recordingStopCompleter = Completer<void>();
    String? recordedPath;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw StateError('Microphone permission was not granted.');
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/droobi_ifm_${DateTime.now().millisecondsSinceEpoch}.wav';

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

      if (!_stopRequested) {
        await _recordingStopCompleter!.future;
      }
      recordedPath = await _recorder.stop();
    } catch (_) {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      rethrow;
    } finally {
      _isListening = false;
      _recordingStopCompleter = null;
    }

    onRecordingComplete?.call();

    if (recordedPath == null || !File(recordedPath).existsSync()) {
      return null;
    }

    final file = File(recordedPath);
    if (await file.length() < _minWavBytes) {
      await file.delete();
      return null;
    }

    _isProcessing = true;
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = _model
        ..fields['language'] = language == VoiceLanguage.arabic ? 'ar' : 'en'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException(
          'IFM transcription timed out after 90 seconds.',
        ),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Do not log the Authorization header or API key.
        throw HttpException(
          'IFM transcription failed (HTTP ${response.statusCode}): '
          '${response.body.length > 500 ? response.body.substring(0, 500) : response.body}',
        );
      }

      final text = _removeTrailingPunctuation(_extractTranscript(response.body));
      if (_usesWrongScript(text, language)) {
        throw VoiceLanguageMismatchException(language);
      }
      debugPrint('IFM Jais-ASR returned ${text.length} characters.');
      return text.isEmpty ? null : text;
    } finally {
      _isProcessing = false;
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  bool _usesWrongScript(String text, VoiceLanguage language) {
    final hasArabic = RegExp(r'[\\u0600-\\u06FF\\u0750-\\u077F\\u08A0-\\u08FF]').hasMatch(text);
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(text);

    // The API receives the language hint; this also rejects wrong-script output.
    return switch (language) {
      VoiceLanguage.arabic => hasLatin,
      VoiceLanguage.english => hasArabic,
    };
  }

  /// Remove punctuation only from the very end, keeping punctuation inside
  /// the recognized destination phrase intact.
  String _removeTrailingPunctuation(String value) => value
      .trim()
      .replaceFirst(RegExp(r'[\s.!?؟،؛:…]+$'), '')
      .trimRight();

  String _extractTranscript(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is String) return decoded;
      if (decoded is Map<String, dynamic>) {
        for (final key in ['text', 'transcription', 'transcript']) {
          final value = decoded[key];
          if (value is String) return value;
        }
        // Some OpenAI-compatible APIs return a list of segments.
        final segments = decoded['segments'];
        if (segments is List) {
          return segments
              .whereType<Map>()
              .map((segment) => segment['text'])
              .whereType<String>()
              .join(' ');
        }
      }
    } on FormatException {
      // A plain-text response is also accepted.
    }
    return body;
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;
    _stopRequested = true;
    final completer = _recordingStopCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}
