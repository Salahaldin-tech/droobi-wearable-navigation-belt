/*
 * Droobi wearable navigation belt - ESP32 firmware
 *
 * BLE protocol must stay in sync with:
 *   lib/core/enums/belt_command.dart
 *
 * Commands: F, B, L, R, FL, FR, BL, BR, ARRIVED, STOP, HB
 * ARRIVED briefly activates all four motors together.
 * HB is a heartbeat and never activates motors.
 *
 * The four GPIOs below are DRIVER INPUT pins, not motor power outputs.
 * Do not connect ERM motors directly to ESP32 GPIO pins.
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Keep these values identical to Droobi's Flutter BLE configuration.
static const char *DEVICE_NAME = "DroobiBelt";
static const char *SERVICE_UUID = "4e4a0001-6f6e-4b65-8b1a-0123456789ab";
static const char *COMMAND_CHARACTERISTIC_UUID = "4e4a0002-6f6e-4b65-8b1a-0123456789ab";

// Configure these to match the actual driver inputs used on your breadboard.
static constexpr uint8_t MOTOR_FRONT_PIN = 25;
static constexpr uint8_t MOTOR_BACK_PIN  = 26;
static constexpr uint8_t MOTOR_LEFT_PIN  = 27;
static constexpr uint8_t MOTOR_RIGHT_PIN = 14;

// Set to false if your motor-driver input stage is active LOW.
static constexpr bool MOTOR_ACTIVE_HIGH = true;

// A missing heartbeat stops vibration as a safety measure.
static constexpr unsigned long HEARTBEAT_TIMEOUT_MS = 10000;
static constexpr unsigned long DIRECTION_PULSE_MS = 3000;
static constexpr unsigned long ARRIVAL_PULSE_MS = 1200;

BLEServer *bleServer = nullptr;
BLECharacteristic *commandCharacteristic = nullptr;
bool deviceConnected = false;
bool previousDeviceConnected = false;

unsigned long lastHeartbeatMs = 0;
bool heartbeatSeen = false;
bool arrivalPulseActive = false;
unsigned long arrivalPulseUntilMs = 0;
String lastCommand = "STOP";
// Remember the last direction even after its 3-second pulse ends.
// Repeated writes of the same direction must not restart the timer.
String lastDirectionCommand = "STOP";
bool directionPulseActive = false;
unsigned long directionPulseUntilMs = 0;

void setMotor(uint8_t pin, bool enabled) {
  const bool outputHigh = MOTOR_ACTIVE_HIGH ? enabled : !enabled;
  digitalWrite(pin, outputHigh ? HIGH : LOW);
}

void setAllMotorsOff() {
  setMotor(MOTOR_FRONT_PIN, false);
  setMotor(MOTOR_BACK_PIN, false);
  setMotor(MOTOR_LEFT_PIN, false);
  setMotor(MOTOR_RIGHT_PIN, false);
}

void stopMotors() {
  setAllMotorsOff();
  arrivalPulseActive = false;
  arrivalPulseUntilMs = 0;
  directionPulseActive = false;
  directionPulseUntilMs = 0;
  lastCommand = "STOP";
}

void pulseAllMotorsForArrival() {
  lastDirectionCommand = "STOP";
  directionPulseActive = false;
  directionPulseUntilMs = 0;
  setMotor(MOTOR_FRONT_PIN, true);
  setMotor(MOTOR_BACK_PIN, true);
  setMotor(MOTOR_LEFT_PIN, true);
  setMotor(MOTOR_RIGHT_PIN, true);
  arrivalPulseActive = true;
  arrivalPulseUntilMs = millis() + ARRIVAL_PULSE_MS;
  lastCommand = "ARRIVED";
  Serial.println("[ARRIVED] All four motors ON for 1200 ms");
}

void applyCommand(String command) {
  command.trim();
  command.toUpperCase();

  if (command == "HB") {
    lastHeartbeatMs = millis();
    heartbeatSeen = true;
    return;
  }

  if (command == "STOP") {
    stopMotors();
    lastDirectionCommand = "STOP";
    Serial.println("[CMD] STOP");
    return;
  }

  if (command == "ARRIVED") {
    stopMotors();
    pulseAllMotorsForArrival();
    return;
  }

  const bool isDirection =
      command == "F" || command == "B" || command == "L" ||
      command == "R" || command == "FL" || command == "FR" ||
      command == "BL" || command == "BR";

  if (!isDirection) {
    Serial.print("[WARN] Unknown command: ");
    Serial.println(command);
    return;
  }

  // Ignore repeated writes of the same direction. In particular, RRRR
  // must not keep restarting the 3-second vibration window.
  if (command == lastDirectionCommand) {
    return;
  }

  // A new direction starts a fresh 3-second pulse.
  stopMotors();
  lastDirectionCommand = command;

  if (command == "F") {
    setMotor(MOTOR_FRONT_PIN, true);
  } else if (command == "B") {
    setMotor(MOTOR_BACK_PIN, true);
  } else if (command == "L") {
    setMotor(MOTOR_LEFT_PIN, true);
  } else if (command == "R") {
    setMotor(MOTOR_RIGHT_PIN, true);
  } else if (command == "FL") {
    setMotor(MOTOR_FRONT_PIN, true);
    setMotor(MOTOR_LEFT_PIN, true);
  } else if (command == "FR") {
    setMotor(MOTOR_FRONT_PIN, true);
    setMotor(MOTOR_RIGHT_PIN, true);
  } else if (command == "BL") {
    setMotor(MOTOR_BACK_PIN, true);
    setMotor(MOTOR_LEFT_PIN, true);
  } else if (command == "BR") {
    setMotor(MOTOR_BACK_PIN, true);
    setMotor(MOTOR_RIGHT_PIN, true);
  }

  directionPulseActive = true;
  directionPulseUntilMs = millis() + DIRECTION_PULSE_MS;
  lastCommand = command;
  Serial.print("[CMD] ");
  Serial.print(command);
  Serial.println(" - motors ON for 3000 ms");
}

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    const std::string value = characteristic->getValue();
    if (value.empty()) return;

    String command;
    command.reserve(value.length());
    for (size_t i = 0; i < value.length(); ++i) {
      command += value[i];
    }
    applyCommand(command);
  }
};

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    deviceConnected = true;
    lastHeartbeatMs = millis();
    heartbeatSeen = true;
    Serial.println("[BLE] Droobi connected");
    stopMotors();
    lastDirectionCommand = "STOP";
  }

  void onDisconnect(BLEServer *server) override {
    deviceConnected = false;
    heartbeatSeen = false;
    Serial.println("[BLE] Droobi disconnected; stopping motors");
    stopMotors();
    lastDirectionCommand = "STOP";
  }
};

void testAllDirections() {
  const char *commands[] = {"F", "B", "L", "R", "FL", "FR", "BL", "BR"};
  Serial.println("[TEST] Running all 8 direction patterns");
  for (const char *command : commands) {
    applyCommand(String(command));
    delay(700);
    stopMotors();
    delay(250);
  }
  Serial.println("[TEST] Complete");
}

void setup() {
  Serial.begin(115200);
  delay(200);

  pinMode(MOTOR_FRONT_PIN, OUTPUT);
  pinMode(MOTOR_BACK_PIN, OUTPUT);
  pinMode(MOTOR_LEFT_PIN, OUTPUT);
  pinMode(MOTOR_RIGHT_PIN, OUTPUT);
  stopMotors();

  BLEDevice::init(DEVICE_NAME);
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new ServerCallbacks());

  BLEService *service = bleServer->createService(SERVICE_UUID);
  commandCharacteristic = service->createCharacteristic(
    COMMAND_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_WRITE_NR
  );
  commandCharacteristic->setCallbacks(new CommandCallbacks());
  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println();
  Serial.println("=== Droobi Belt ESP32 ready ===");
  Serial.println("BLE name: DroobiBelt");
  Serial.println("Serial commands: F B L R FL FR BL BR ARRIVED STOP TEST");
  Serial.println("Waiting for Droobi BLE connection...");
}

void loop() {
  // Serial test mode allows motor testing before the app is connected.
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    input.toUpperCase();

    if (input == "TEST") {
      testAllDirections();
    } else if (input == "F" || input == "B" || input == "L" ||
               input == "R" || input == "FL" || input == "FR" ||
               input == "BL" || input == "BR" || input == "ARRIVED" ||
               input == "STOP") {
      applyCommand(input);
    } else if (input.length() > 0) {
      Serial.println("[HELP] Use F B L R FL FR BL BR ARRIVED STOP or TEST");
    }
  }

  if (directionPulseActive &&
      static_cast<long>(millis() - directionPulseUntilMs) >= 0) {
    setAllMotorsOff();
    directionPulseActive = false;
    directionPulseUntilMs = 0;
    lastCommand = "STOP";
    Serial.println("[DIRECTION] 3-second pulse complete; motors stopped");
  }

  if (arrivalPulseActive &&
      static_cast<long>(millis() - arrivalPulseUntilMs) >= 0) {
    stopMotors();
    Serial.println("[ARRIVED] Pulse complete; motors stopped");
  }

  if (heartbeatSeen && millis() - lastHeartbeatMs > HEARTBEAT_TIMEOUT_MS) {
    if (lastCommand != "STOP") {
      Serial.println("[SAFETY] Heartbeat timeout; stopping motors");
      stopMotors();
    }
    heartbeatSeen = false;
  }

  // Restart advertising after a disconnect so the app can reconnect.
  if (!deviceConnected && previousDeviceConnected) {
    delay(200);
    BLEDevice::startAdvertising();
    Serial.println("[BLE] Advertising restarted");
    previousDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !previousDeviceConnected) {
    previousDeviceConnected = deviceConnected;
  }

  delay(5);
}
