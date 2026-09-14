/// The 8 navigation directions plus STOP, exactly as agreed in Stage 1.
///
/// This is a Dart enum specifically so that an invalid command is a
/// compile-time impossibility anywhere in the app's own logic. The
/// wire string is only produced at the point of actual BLE transmission
/// (see [wireValue]), never passed around as a raw String elsewhere.
///
/// Heartbeat ("HB") is intentionally NOT part of this enum - it is not
/// a navigation command, must never participate in send-on-change
/// dedup, and must never be treated as "the current direction".
enum BeltCommand {
  front,
  back,
  left,
  right,
  frontLeft,
  frontRight,
  backLeft,
  backRight,
  stop,
}

extension BeltCommandWireValue on BeltCommand {
  /// The exact UTF-8 text sent over BLE. Must match DroobiBelt.ino.
  String get wireValue {
    switch (this) {
      case BeltCommand.front:
        return 'F';
      case BeltCommand.back:
        return 'B';
      case BeltCommand.left:
        return 'L';
      case BeltCommand.right:
        return 'R';
      case BeltCommand.frontLeft:
        return 'FL';
      case BeltCommand.frontRight:
        return 'FR';
      case BeltCommand.backLeft:
        return 'BL';
      case BeltCommand.backRight:
        return 'BR';
      case BeltCommand.stop:
        return 'STOP';
    }
  }

  /// A short human-readable label, for the test screen / future UI.
  String get label {
    switch (this) {
      case BeltCommand.front:
        return 'Front';
      case BeltCommand.back:
        return 'Back';
      case BeltCommand.left:
        return 'Left';
      case BeltCommand.right:
        return 'Right';
      case BeltCommand.frontLeft:
        return 'Front-Left';
      case BeltCommand.frontRight:
        return 'Front-Right';
      case BeltCommand.backLeft:
        return 'Back-Left';
      case BeltCommand.backRight:
        return 'Back-Right';
      case BeltCommand.stop:
        return 'STOP';
    }
  }
}
