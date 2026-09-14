/// Connection lifecycle states for the belt, per the Stage 3 design.
///
///   disconnected -> scanning -> connecting -> connected
///                                                  |
///                                     (link drops) v
///                                            reconnecting
///                                          /              \
///                                   connected        disconnected
///                                  (success)      (retries exhausted)
enum BeltConnectionState {
  /// No link, and not currently attempting one.
  disconnected,

  /// Actively scanning for a device advertising the belt's Service UUID.
  scanning,

  /// A matching device was found; GATT connect handshake in progress.
  connecting,

  /// Link established and the command characteristic is ready for writes.
  connected,

  /// Link unexpectedly dropped; automatic backoff retry is in progress.
  reconnecting,

  /// A scan attempt completed with no matching device found.
  scanFailed,
}
