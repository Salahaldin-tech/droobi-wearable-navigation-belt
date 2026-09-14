/// BLE protocol constants for communicating with the DroobiBelt ESP32.
///
/// IMPORTANT: These values must exactly match the constants defined in
/// the ESP32 firmware (DroobiBelt.ino). If the protocol ever changes,
/// both sides must be updated together in the same change - never
/// silently, per the project's development rules.
library ble_constants;

class BleConstants {
  BleConstants._(); // no instances - constants holder only

  /// Advertised BLE device name for the belt.
  static const String deviceName = 'DroobiBelt';

  /// Custom 128-bit GATT Service UUID hosted by the ESP32.
  static const String serviceUuid = '4E4A0001-6F6E-4B65-8B1A-0123456789AB';

  /// Custom 128-bit GATT Characteristic UUID (write with response)
  /// used for both navigation commands and the heartbeat.
  static const String commandCharacteristicUuid =
      '4E4A0002-6F6E-4B65-8B1A-0123456789AB';

  /// Heartbeat payload. Distinct from all navigation commands.
  /// Sent periodically while connected; must NEVER change motor state
  /// on the ESP32 side - it only resets the firmware watchdog timer.
  static const String heartbeatCommand = 'HB';

  /// How often the app sends a heartbeat while connected.
  /// Must stay comfortably below the ESP32's 10s watchdog timeout
  /// (see WATCHDOG_TIMEOUT_MS in DroobiBelt.ino) to avoid false
  /// motor shutoffs during normal operation.
  static const Duration heartbeatInterval = Duration(seconds: 2);

  /// Reconnection backoff schedule, per the agreed Stage 3/4 policy.
  /// Index 0 = delay before attempt 1 (immediate), etc.
  /// Exactly 5 attempts; after the last one fails, auto-retry stops.
  static const List<Duration> reconnectBackoff = <Duration>[
    Duration.zero,
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
  ];

  /// How long a single scan attempt runs before being treated as
  /// "not found".
  static const Duration scanTimeout = Duration(seconds: 15);

  /// Timeout for the initial GATT connect handshake.
  static const Duration connectTimeout = Duration(seconds: 10);
}
