/// Priority for a spoken announcement. Higher-priority announcements
/// may interrupt a lower-priority one currently speaking (e.g. a
/// belt-disconnection warning should interrupt a routine status read,
/// per Stage 3's reconnection-announcement policy).
enum AnnouncementPriority { low, normal, high }

/// Abstract interface for audio/TTS feedback.
///
/// The rest of the app depends only on this interface, never on
/// flutter_tts directly - consistent with the BLE/Auth/Search pattern.
/// Centralizing announcements here (rather than each widget calling
/// TTS ad hoc) is what keeps visual state and spoken state from
/// drifting apart, per Stage 2's accessibility architecture.
abstract class FeedbackService {
  Future<void> announce(
    String message, {
    AnnouncementPriority priority = AnnouncementPriority.normal,
  });

  /// Interrupts any announcement currently being spoken.
  Future<void> stop();
}
