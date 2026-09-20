import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  // ---------------------------------------------------------------------------
  // MODEL FILE VALIDATION
  //
  // whisper_flutter_new only checks modelFile.existsSync(). A truncated
  // download therefore stays on the phone and crashes libwhisper.so.
  // The service validates the file itself before the package can use it.
  // ---------------------------------------------------------------------------

  // Same file name the package looks for in getApplicationSupportDirectory().
  static const String _modelFileName = 'ggml-small.bin';

  static const String _modelUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin';

  // SHA-256 of the official ggml-small.bin (about 488 MB).
  static const String _modelSha256 =
      '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b';

  // Cheap sanity range. The checksum is the real integrity check.
  static const int _minModelBytes = 480000000;
  static const int _maxModelBytes = 495000000;

  // Recordings shorter than about 0.3 seconds are not sent to native Whisper.
  // 44 byte WAV header + 0.3 s of 16 kHz mono 16-bit audio.
  static const int _minWavBytes = 44 + 9600;

  final AudioRecorder _recorder;

  Whisper? _whisper;

  // Shared by every caller, so validation/download runs only once at a time.
  Future<void>? _modelReadyFuture;

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

  /// Makes sure a VALID model file exists before native Whisper is used.
  ///
  /// Safe to call many times. If it fails (for example no internet), the
  /// next call tries again.
  @override
  Future<void> ensureModelReady() {
    _modelReadyFuture ??= _prepareModel();
    return _modelReadyFuture!;
  }

  Future<void> _prepareModel() async {
    try {
      await _validateOrDownloadModel();
      _whisper ??= const Whisper(model: _model);
    } catch (_) {
      // Allow a retry on the next call.
      _modelReadyFuture = null;
      rethrow;
    }
  }

  Future<void> _validateOrDownloadModel() async {
    final supportDir = await getApplicationSupportDirectory();
    final modelFile = File('${supportDir.path}/$_modelFileName');
    final markerFile = File('${modelFile.path}.verified');

    debugPrint('Whisper: model path ${modelFile.path}');

    if (modelFile.existsSync()) {
      final isValid = await _isModelValid(modelFile, markerFile);

      if (isValid) {
        debugPrint('Whisper: model file is valid');
        return;
      }

      debugPrint(
        'Whisper: model file is invalid '
        '(${modelFile.lengthSync()} bytes), deleting it',
      );

      await _deleteIfExists(modelFile);
      await _deleteIfExists(markerFile);
    }

    await _downloadModel(modelFile, markerFile);
  }

  /// Size range first (cheap), then SHA-256. The SHA-256 is computed once;
  /// after that a small marker file records the verified size.
  Future<bool> _isModelValid(File modelFile, File markerFile) async {
    final length = modelFile.lengthSync();

    if (length < _minModelBytes || length > _maxModelBytes) {
      return false;
    }

    if (markerFile.existsSync() &&
        markerFile.readAsStringSync().trim() == '$length') {
      return true;
    }

    final watch = Stopwatch()..start();
    final hash = await _sha256Of(modelFile);

    debugPrint(
      'Whisper: checksum computed in ${watch.elapsedMilliseconds} ms',
    );

    if (hash != _modelSha256) {
      debugPrint('Whisper: checksum mismatch, got $hash');
      return false;
    }

    await markerFile.writeAsString('$length');
    return true;
  }

  /// Downloads to a .part file and only renames it to ggml-small.bin after
  /// the HTTP status, size and SHA-256 have all been verified.
  Future<void> _downloadModel(File modelFile, File markerFile) async {
    final partFile = File('${modelFile.path}.part');
    await _deleteIfExists(partFile);

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    final watch = Stopwatch()..start();
    IOSink? sink;

    try {
      debugPrint('Whisper: downloading $_modelFileName');

      final request = await client.getUrl(Uri.parse(_modelUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception(
          'Whisper model download failed: HTTP ${response.statusCode}',
        );
      }

      final expectedLength = response.contentLength;

      sink = partFile.openWrite();

      // pipe() closes the sink when the download finishes.
      await response.timeout(const Duration(seconds: 60)).pipe(sink);
      sink = null;

      final downloadedLength = partFile.lengthSync();

      if (expectedLength > 0 && downloadedLength != expectedLength) {
        throw Exception(
          'Whisper model download incomplete: '
          '$downloadedLength of $expectedLength bytes',
        );
      }

      if (downloadedLength < _minModelBytes ||
          downloadedLength > _maxModelBytes) {
        throw Exception(
          'Whisper model has an unexpected size: $downloadedLength bytes',
        );
      }

      final hash = await _sha256Of(partFile);

      if (hash != _modelSha256) {
        throw Exception('Whisper model checksum mismatch: $hash');
      }

      await partFile.rename(modelFile.path);
      await markerFile.writeAsString('$downloadedLength');

      debugPrint(
        'Whisper: model downloaded and verified in '
        '${watch.elapsedMilliseconds} ms',
      );
    } catch (_) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {
          // Ignore errors while cleaning up.
        }
      }

      await _deleteIfExists(partFile);
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
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
      // Validates (and if needed re-downloads) the model. Native Whisper
      // is never reached with an unverified model file.
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

    // Do not send an almost empty recording to native Whisper.
    final recordedFile = File(recordedPath);
    if (recordedFile.lengthSync() < _minWavBytes) {
      debugPrint(
        'Whisper: recording too short '
        '(${recordedFile.lengthSync()} bytes), skipped',
      );
      await recordedFile.delete();
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