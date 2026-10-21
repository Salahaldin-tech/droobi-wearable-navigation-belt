# Droobi Belt ESP32 Firmware

This folder contains the first breadboard-test firmware for the Droobi navigation belt.

## Firmware

- Sketch: `DroobiBelt.ino`
- Target: ESP32 Dev Module using the Arduino ESP32 board package
- BLE advertised name: `Droobi Belt`
- Service UUID: `4e4a0001-6f6e-4b65-8b1a-0123456789ab`
- Writable characteristic UUID: `4e4a0002-6f6e-4b65-8b1a-0123456789ab`

## Wire protocol

The command strings intentionally match `lib/core/enums/belt_command.dart`.

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
| `STOP` | All off |
| `HB` | Heartbeat only; no motor activation |

Each GPIO constant in the sketch represents a **motor-driver input**, not a motor power output. Update the four pin constants to match the actual driver wiring before running the motors. The current example defaults are GPIO 25 (front), 26 (back), 27 (left), and 14 (right).

## First test

1. Open `DroobiBelt.ino` in Arduino IDE and select the ESP32 Dev Module.
2. Compile and upload the sketch.
3. Open Serial Monitor at 115200 baud with line ending set to Newline.
4. Enter `TEST` to run all eight patterns sequentially, or enter one command at a time (`F`, `FL`, `STOP`, etc.).
5. Once the individual patterns work, connect from Droobi and start a route.

## Safety behavior

- All motors are stopped on BLE connect/disconnect and on `STOP`.
- Unknown commands do not activate any motor.
- If heartbeats have been received and then stop for 10 seconds, motors stop.
- Test mode is for bench testing only. Keep the motors mechanically secured and avoid prolonged continuous vibration.

The firmware is a starting implementation and still needs compilation on the actual ESP32 board and an end-to-end test against the installed app and driver circuit.
