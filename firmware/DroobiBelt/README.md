# Droobi Belt ESP32 Firmware

This folder contains the breadboard-test firmware for the Droobi navigation belt.

## Firmware

- Sketch: `DroobiBelt.ino`
- Target: ESP32 Dev Module using the Arduino ESP32 board package
- BLE advertised name: `DroobiBelt` (must match Flutter `BleConstants.deviceName`)
- Service UUID: `4e4a0001-6f6e-4b65-8b1a-0123456789ab`
- Writable characteristic UUID: `4e4a0002-6f6e-4b65-8b1a-0123456789ab`

## Wire protocol

The command strings match `lib/core/enums/belt_command.dart`.

| Payload | Expected motor pattern |
|---|---|
| `F` | Front |
| `B` | Back |
| `L` | Left |
| `R` | Right |
| `FL` | Front + Left |
| `FR` | Front + Right |
| `BL` | Back + Left |
| `BR` | Back + Right |
| `ARRIVED` | All four motors together for about 1.2 seconds, then stop |
| `STOP` | All motors off |
| `HB` | Heartbeat only; no motor activation |

Each GPIO constant is a **motor-driver input**, not a motor power output. Update the pins to match the actual driver wiring before running the motors. Defaults: GPIO 25 (front), 26 (back), 27 (left), and 14 (right).

## First test

1. Open `DroobiBelt.ino` in Arduino IDE and select the correct ESP32 board and port.
2. Compile and upload the sketch.
3. Open Serial Monitor at 115200 baud with line ending set to Newline.
4. Enter `TEST` to run the eight direction patterns, or test one at a time using `F`, `FL`, and `STOP`.
5. Enter `ARRIVED` to verify that all four motors pulse together and then stop automatically.
6. Connect Droobi and test a route, including reaching the destination.

## Error and safety behavior

- The ESP32 stops all motors when BLE disconnects.
- The app's BLE service attempts to reconnect automatically. After reconnection, it sends the current navigation direction only if navigation is actively running; otherwise it sends `STOP`.
- If the app's heartbeat stops for 10 seconds, the firmware stops the motors.
- If GPS/location services are turned off during navigation, the app publishes a GPS-unavailable error and the bridge sends `STOP`. Navigation can resume when location updates return.
- Reaching the destination sends `ARRIVED`; all four motors pulse together for about 1.2 seconds, then stop.
- Unknown commands do not activate a motor.
- Never connect ERM motors directly to ESP32 GPIO pins. Use the appropriate motor driver and a suitable power supply.

The firmware and app changes still require compilation and an end-to-end test on the actual ESP32, phone, and motor-driver circuit.
