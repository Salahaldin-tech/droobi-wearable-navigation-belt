/// Abstract interface for converting spoken input into text.
///
/// The rest of the app depends only on this interface, never on the
/// speech_to_text package directly - consistent with the BLE/Auth/
/// Search/Feedback pattern.
abstract class VoiceInputService {
  /// True while actively listening for speech.
  bool get isListening;

  /// Starts listening and resolves with the recognized text, or null
  /// if nothing was recognized / the attempt timed out / failed.
  /// Does not throw for "no speech detected" - that's a normal
  /// outcome, represented as a null return, not an exception.
  Future<String?> listenForDestination();

  /// Stops listening early, if in progress.
  Future<void> stopListening();
}
