# 🦯 Droobi

### Wearable Navigation System for Visually Impaired Users

<p align="center">
  <strong>Navigate independently. Move confidently.</strong>
</p>

<p align="center">
  Droobi is a Flutter-based accessibility navigation application designed to help visually impaired users navigate their surroundings through voice guidance, GPS-based routing, and a future wearable haptic navigation belt powered by ESP32.
</p>

<p align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![ESP32](https://img.shields.io/badge/ESP32-Wearable-000000?style=for-the-badge&logo=espressif&logoColor=white)
![OSM](https://img.shields.io/badge/OpenStreetMap-Search-7EBC6F?style=for-the-badge&logo=openstreetmap&logoColor=white)

</p>

---

## 📖 Overview

**Droobi** is an accessibility-focused navigation application developed as part of the **Navigation Belt for Visually Impaired Users** project.

The system combines:

- 📍 GPS positioning
- 🗺️ Route calculation
- 🔎 Destination search
- 🎙️ Local voice input
- 🔊 Text-to-speech feedback
- 🧭 Device orientation
- 📡 Bluetooth Low Energy communication
- 🦯 A future wearable haptic navigation belt

The mobile application acts as the main navigation engine while the wearable belt is designed to communicate directional instructions through vibration.

### The idea

Instead of requiring a visually impaired user to continuously look at a phone screen, Droobi is designed around **audio and haptic interaction**.

```text
                ┌─────────────────────┐
                │       DROOBI        │
                │    Flutter App      │
                └──────────┬──────────┘
                           │
             ┌─────────────┼─────────────┐
             │             │             │
             ▼             ▼             ▼
          🎙️ Voice      📍 GPS       🗺️ Routing
             │             │             │
             └─────────────┼─────────────┘
                           │
                           ▼
                  Navigation Command
                           │
                           ▼
                    Bluetooth LE
                           │
                           ▼
                ┌─────────────────────┐
                │    Droobi Belt      │
                │       ESP32         │
                └──────────┬──────────┘
                           │
                 ┌─────────┼─────────┐
                 ▼         ▼         ▼
               Left      Forward    Right
              Vibration  Vibration  Vibration
```

---

# ✨ Features

## 🗺️ Intelligent Destination Search

Users can search for destinations using the application's search system.

The current implementation uses:

- OpenStreetMap
- Nominatim
- Palestine-specific search
- City-based search boundaries
- Persistent city selection

Supported cities currently include:

### West Bank

- Ramallah
- East Jerusalem
- Hebron
- Nablus
- Jenin
- Bethlehem
- Jericho
- Tulkarm
- Qalqilya
- Tubas
- Salfit

### Gaza Strip

- Gaza City
- Khan Yunis
- Rafah
- Jabalia
- Deir al-Balah

---

## 🎙️ Voice Input

Droobi is designed for hands-free interaction.

The application uses **local Whisper-based speech recognition** instead of relying on a cloud speech-to-text service.

This provides the foundation for:

- Arabic voice commands
- English voice commands
- Destination input
- Accessibility-focused interaction

---

## 🔊 Voice Feedback

Droobi uses Text-to-Speech to provide navigation and accessibility feedback.

The application supports:

- English
- Arabic

The user can switch the voice language from Settings.

---

## 📍 GPS Navigation

The application uses the device's GPS to determine the user's current location.

The navigation system is designed to:

1. Obtain the user's location.
2. Search for the destination.
3. Calculate a route.
4. Determine the required direction.
5. Provide navigation instructions.
6. Send directional information to the wearable belt.

---

## 🧭 Direction & Orientation

Droobi uses the device's orientation information to determine the user's heading.

The navigation logic compares:

```text
Current Heading
       +
Required Route Bearing
       ↓
Navigation Direction
       ↓
Forward / Left / Right / Back
```

This allows the system to transform geographic route information into understandable directional instructions.

---

# 📡 Wearable Navigation Belt

The future hardware component of the project is a wearable navigation belt built around an **ESP32**.

The belt is designed to provide directional information through vibration rather than visual information.

### Hardware concept

```text
             ┌───────────────────┐
             │       ESP32       │
             └─────────┬─────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
       Left Motor   Front Motor   Right Motor
          │            │            │
          └────────────┼────────────┘
                       │
                  Back Motor
```

The motors are positioned around the belt so the user can interpret vibration direction.

### Current hardware direction

- ESP32
- BLE communication
- ERM vibration motors
- LiPo battery
- TP4056 charging module
- Motor driver/transistor control circuitry

The ESP32 operates at **3.3V logic**, and the design does not require a boost converter for the ESP32 itself.

---

# 🔗 Bluetooth Communication

Droobi uses **Bluetooth Low Energy (BLE)** for communication between the Flutter application and the future navigation belt.

Current communication architecture:

```text
Flutter App
    │
    │ BLE
    ▼
ESP32
    │
    ▼
Motor Control
    │
    ├── Left
    ├── Right
    ├── Front
    └── Back
```

The mobile application generates a navigation command and sends it through BLE.

---

# 🔐 Authentication & User Management

Droobi uses Firebase Authentication for user accounts.

User profiles are stored in Cloud Firestore.

```text
Firebase Authentication
          │
          ▼
        User UID
          │
          ▼
    users/{uid}
          │
     ┌────┴────┐
     │         │
   user      admin
```

The application includes role-based access for developer functionality.

### User

Regular users have access to the normal application functionality.

### Admin

Administrators can access the **Developer / Dev Test Menu**.

The application also uses Firestore Security Rules to prevent users from changing their own role to `admin`.

---

# ⚙️ Technology Stack

| Category | Technology |
|---|---|
| Mobile Framework | Flutter |
| Language | Dart |
| State Management | Riverpod |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Destination Search | OpenStreetMap / Nominatim |
| Routing | OSRM |
| Location | Geolocator |
| Orientation | Flutter Compass |
| Voice Recognition | Whisper / whisper.cpp |
| Text-to-Speech | Flutter TTS |
| Bluetooth | Flutter Blue Plus |
| Wearable MCU | ESP32 |
| Version Control | Git / GitHub |

---

# 🏗️ Application Architecture

Droobi follows a layered architecture designed to keep the UI separated from services and application logic.

```text
lib/
│
├── core/
│   └── enums/
│
├── models/
│   ├── app_user.dart
│   └── destination.dart
│
├── screens/
│   ├── auth/
│   ├── home/
│   ├── settings/
│   └── test/
│
├── services/
│   ├── ble/
│   ├── firebase/
│   ├── search/
│   ├── voice/
│   └── accessibility/
│
├── state/
│   ├── auth_state_notifier.dart
│   ├── belt_connection_notifier.dart
│   ├── destination_search_notifier.dart
│   └── voice_language_notifier.dart
│
└── widgets/
    ├── connection_status_indicator.dart
    └── droobi_bottom_nav.dart
```

The project isolates external services behind interfaces where appropriate, allowing components to be replaced without changing the rest of the application.

---

# 🔄 Navigation Flow

```text
                  User
                   │
                   ▼
            Voice / Search
                   │
                   ▼
          Destination Selection
                   │
                   ▼
             GPS Location
                   │
                   ▼
              OSRM Routing
                   │
                   ▼
           Route Calculation
                   │
                   ▼
          Bearing Calculation
                   │
                   ▼
          Direction Decision
                   │
          ┌────────┼────────┐
          ▼        ▼        ▼
        Left    Forward   Right
          │        │        │
          └────────┼────────┘
                   ▼
                BLE
                   │
                   ▼
                ESP32
                   │
                   ▼
            Haptic Feedback
```

---

# 🎨 User Interface

Droobi follows a clean and accessibility-focused interface.

The UI focuses on:

- Large interactive elements
- Minimal visual clutter
- Clear navigation
- Voice interaction
- High readability
- Simple settings
- Clear belt connection status

Primary application color:

```text
#2F80ED
```

---

# 📱 Screenshots

> Add your screenshots to `assets/screenshots/` and update the paths below.

### Login

<p align="center">
  <img src="assets/screenshots/login.png" width="250">
</p>

### Home

<p align="center">
  <img src="assets/screenshots/home.png" width="250">
</p>

### Destination Search

<p align="center">
  <img src="assets/screenshots/search.png" width="250">
</p>

### Settings

<p align="center">
  <img src="assets/screenshots/settings.png" width="250">
</p>

### Navigation

<p align="center">
  <img src="assets/screenshots/navigation.png" width="250">
</p>

---

# 🚀 Getting Started

## Requirements

Before running Droobi, install:

- Flutter SDK
- Dart SDK
- Android Studio
- Android SDK
- Git
- A physical Android device or emulator

Verify Flutter:

```bash
flutter doctor
```

---

## 📥 Clone the Repository

```bash
git clone https://github.com/Salahaldin-tech/droobi-wearable-navigation-belt.git
```

```bash
cd droobi-wearable-navigation-belt
```

---

## 📦 Install Dependencies

```bash
flutter pub get
```

---

## 🔥 Firebase Configuration

The project requires Firebase Authentication and Cloud Firestore.

Configure Firebase for your Flutter project using the appropriate Firebase configuration files for your development environment.

Required services include:

- Firebase Authentication
- Cloud Firestore

The Firestore database contains user profiles under:

```text
users/{uid}
```

and shared university location data under:

```text
universityLocations/{universityId}
```

---

# ▶️ Run the Application

Connect an Android device or start an emulator.

Then:

```bash
flutter run
```

---

# 🧪 Developer Tools

Administrators can access:

```text
Settings
   ↓
Developer
   ↓
Dev Test Menu
```

The Developer section is hidden from normal users.

The developer tools are intended for testing navigation, routing, BLE, and other application components during development.

---

# 🦯 Project Goal

The ultimate goal of Droobi is to create a navigation system that allows visually impaired users to move through their environment with greater independence.

Instead of relying primarily on a visual map interface, the system combines:

**Voice + GPS + Direction + Haptic Feedback**

into one navigation experience.

```text
          DROOBI
             │
     ┌───────┼───────┐
     │       │       │
   Voice    GPS    Haptic
     │       │       │
     └───────┼───────┘
             │
       Independent
        Navigation
```

---

# 🛣️ Roadmap

## Mobile Application

- [x] Flutter application foundation
- [x] Firebase Authentication
- [x] Firestore user profiles
- [x] Role-based admin access
- [x] Destination search
- [x] City selection
- [x] OpenStreetMap / Nominatim integration
- [x] GPS location
- [x] Routing integration
- [x] Voice input foundation
- [x] Text-to-Speech
- [x] BLE communication layer
- [x] Settings
- [x] Developer testing menu

## Wearable Belt

- [x] ESP32 hardware architecture
- [x] BLE communication design
- [x] Motor layout design
- [ ] ESP32 firmware
- [ ] Motor control implementation
- [ ] Complete BLE command protocol
- [ ] Physical belt prototype
- [ ] Hardware integration testing
- [ ] Navigation accuracy testing

---

# 🔬 Future Improvements

Future development may include:

- Improved GPS filtering
- More accurate heading estimation
- Better route-following logic
- More robust BLE reconnection
- Advanced vibration patterns
- Additional accessibility features
- Improved Arabic voice interaction
- Hardware testing with visually impaired users
- Battery optimization
- Navigation safety improvements

---

# 📂 Project Structure

```text
droobi/
│
├── android/
├── assets/
├── ios/
├── lib/
│   ├── core/
│   ├── models/
│   ├── screens/
│   ├── services/
│   ├── state/
│   └── widgets/
│
├── test/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

# 🤝 Contributing

Contributions, suggestions, and improvements are welcome.

If you would like to contribute:

```bash
git clone https://github.com/Salahaldin-tech/droobi-wearable-navigation-belt.git
```

Create a feature branch:

```bash
git checkout -b feature/your-feature
```

Commit your changes:

```bash
git commit -m "Add your feature"
```

Push the branch:

```bash
git push origin feature/your-feature
```

Then open a Pull Request.

---

# 👨‍💻 Development

Droobi is being developed as a graduation project focused on combining:

**Software Engineering + Mobile Development + Accessibility + Embedded Systems + BLE + Navigation**

The project brings together a Flutter mobile application and a future ESP32-based wearable device into one navigation ecosystem.

---

# 📜 License

This project is currently developed as an academic/graduation project.

If you plan to reuse, distribute, or commercially deploy the project, please contact the project authors first.

---

<p align="center">

### 🦯 Droobi

**Technology designed to make navigation more accessible.**

</p>

<p align="center">
  Built with Flutter • Firebase • OpenStreetMap • ESP32 • BLE
</p>
