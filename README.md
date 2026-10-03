<div align="center">

# 🦯 Droobi

### *Feel the way. Don't look for it.*

**A voice + GPS + haptic navigation system for visually impaired users.**
A Flutter app that talks, listens, and drives a vibrating ESP32 belt, so the phone can stay in your pocket.

<br>

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![ESP32](https://img.shields.io/badge/ESP32-BLE%20Belt-E7352C?style=for-the-badge&logo=espressif&logoColor=white)
![OSM](https://img.shields.io/badge/OpenStreetMap-Nominatim-7EBC6F?style=for-the-badge&logo=openstreetmap&logoColor=white)
![Status](https://img.shields.io/badge/status-app%20done%20%7C%20belt%20in%20progress-2F80ED?style=for-the-badge)

<br>

[**The Idea**](#-the-idea) •
[**Features**](#-features) •
[**How It Works**](#-how-it-works) •
[**The Belt**](#-the-belt) •
[**Quick Start**](#-quick-start) •
[**Roadmap**](#%EF%B8%8F-roadmap)

</div>

---

## 💡 The Idea

Most navigation apps assume you can look at a screen. **Droobi doesn't.**

Instead of a map, Droobi gives you three things you can actually use while walking:

| 🎙️ Talk to it | 🔊 Hear it | 📳 Feel it |
|:---:|:---:|:---:|
| Say your destination in **Arabic or English**. Speech recognition runs **on-device**. | Turn-by-turn **spoken guidance** in your language. | A **belt with vibration motors** buzzes left, right, front, or back, so you always know which way to go. |

> **Built as a graduation project** at the Arab American University (Faculty of Engineering), combining mobile development, embedded systems, BLE, and accessibility.

---

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

### 🗺️ Destination Search
- OpenStreetMap + **Nominatim**
- Palestine-focused search
- City-bounded results for accuracy
- Your selected city is **remembered**

</td>
<td width="50%" valign="top">

### 🎙️ Offline Voice Input
- **Whisper (whisper.cpp)** running locally
- No cloud speech-to-text
- Arabic + English commands
- Hands-free destination entry

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🔊 Bilingual Voice Feedback
- Text-to-Speech in **English and Arabic**
- Switch language any time from Settings

</td>
<td width="50%" valign="top">

### 🧭 Heading-Aware Guidance
- GPS position + compass heading
- Compares *where you face* with *where the route goes*
- Outputs a clear Forward / Left / Right / Back

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 📡 BLE Belt Link
- Flutter ⇄ ESP32 over Bluetooth Low Energy
- Live connection status in the UI
- Interface-based service layer, swappable and testable

</td>
<td width="50%" valign="top">

### 🔐 Accounts & Roles
- Firebase Auth + Firestore profiles
- `user` / `admin` roles
- Security rules block self-promotion to admin
- Admin-only **Dev Test Menu**

</td>
</tr>
</table>

### 📍 Supported Cities

| 🏔️ West Bank | 🌊 Gaza Strip |
|---|---|
| Ramallah · East Jerusalem · Hebron · Nablus · Jenin · Bethlehem · Jericho · Tulkarm · Qalqilya · Tubas · Salfit | Gaza City · Khan Yunis · Rafah · Jabalia · Deir al-Balah |

---

## 🧠 How It Works

### The big picture

```mermaid
flowchart LR
    U([🧑 User]) -->|voice| V[🎙️ Whisper<br/>on-device STT]
    V --> S[🔎 Nominatim<br/>destination search]
    S --> R[🗺️ OSRM<br/>route]
    G[📍 GPS] --> N
    C[🧭 Compass] --> N
    R --> N{{🎯 Navigation<br/>engine}}
    N -->|spoken| T[🔊 TTS]
    N -->|command| B[📡 BLE]
    B --> E[⚡ ESP32]
    E --> M[📳 Motors]
    T --> U
    M --> U

    style N fill:#2F80ED,color:#fff,stroke:#2F80ED
    style E fill:#E7352C,color:#fff,stroke:#E7352C
```

### The core trick: heading vs. bearing

The app never tells you "go north." It tells you **which way to turn from where you're facing right now**.

```mermaid
flowchart LR
    A[📍 Current position] --> D[Compute route bearing]
    R[🗺️ Next route point] --> D
    H[🧭 Device heading] --> X[Δ = bearing − heading]
    D --> X
    X --> Q{Δ angle}
    Q -->|small| F[⬆️ Forward]
    Q -->|left| L[⬅️ Left]
    Q -->|right| RT[➡️ Right]
    Q -->|large| BK[⬇️ Back / turn around]
```

### One navigation session, step by step

```mermaid
sequenceDiagram
    actor User
    participant App as 📱 Droobi
    participant OSM as 🔎 Nominatim
    participant OSRM as 🗺️ OSRM
    participant Belt as 📡 ESP32 Belt

    User->>App: "Take me to the university"
    App->>OSM: search (city-bounded)
    OSM-->>App: destination
    App->>OSRM: route(GPS → destination)
    OSRM-->>App: path
    loop every position / heading update
        App->>App: bearing − heading → direction
        App-->>User: 🔊 spoken instruction
        App->>Belt: 📳 direction command (BLE)
        Belt-->>User: vibration on the matching side
    end
```

---

## 🦯 The Belt

The belt turns directions into something you can feel. Four vibration motors sit around the waist, so **the side that buzzes is the way you go**.

```
              FRONT
          ┌─────────────┐
          │   ● motor   │
   LEFT   │             │   RIGHT
  ● motor │    ESP32    │ ● motor
          │             │
          │   ● motor   │
          └─────────────┘
              BACK
```

| Vibration | Meaning |
|:---:|---|
| ⬆️ Front | Keep going straight |
| ⬅️ Left | Turn left |
| ➡️ Right | Turn right |
| ⬇️ Back | Wrong way, turn around |

### Hardware

| Part | Role |
|---|---|
| **ESP32** | Brain + BLE radio (3.3 V logic, no boost converter needed for the MCU) |
| **ERM vibration motors** | Directional haptic output |
| **Transistor / driver stage** | Switches motors safely from GPIO |
| **LiPo battery** | Portable power |
| **TP4056** | USB charging |

### BLE command protocol (draft)

> 🚧 Not finalized. This is the working proposal while the firmware is being written.

| Byte | Command |
|:---:|---|
| `0x00` | Stop / all motors off |
| `0x01` | Forward |
| `0x02` | Left |
| `0x03` | Right |
| `0x04` | Back |

---

## 🏗️ Architecture

Clean layers: the UI never talks to hardware or the network directly.

```mermaid
flowchart TB
    subgraph UI[🎨 Presentation]
        S1[screens/]
        W1[widgets/]
    end
    subgraph ST[🧩 State · Riverpod]
        N1[auth_state_notifier]
        N2[belt_connection_notifier]
        N3[destination_search_notifier]
        N4[voice_language_notifier]
    end
    subgraph SV[⚙️ Services · behind interfaces]
        B1[ble/]
        B2[firebase/]
        B3[search/]
        B4[voice/]
        B5[accessibility/]
    end
    subgraph EX[🌍 External]
        X1[(Firestore)]
        X2[(Nominatim)]
        X3[(OSRM)]
        X4[ESP32 Belt]
    end
    UI --> ST --> SV
    B1 --> X4
    B2 --> X1
    B3 --> X2
    B3 --> X3
```

<details>
<summary><b>📁 Folder structure</b></summary>

```text
lib/
├── core/
│   └── enums/
├── models/
│   ├── app_user.dart
│   └── destination.dart
├── screens/
│   ├── auth/
│   ├── home/
│   ├── settings/
│   └── test/
├── services/
│   ├── ble/
│   ├── firebase/
│   ├── search/
│   ├── voice/
│   └── accessibility/
├── state/
│   ├── auth_state_notifier.dart
│   ├── belt_connection_notifier.dart
│   ├── destination_search_notifier.dart
│   └── voice_language_notifier.dart
└── widgets/
    ├── connection_status_indicator.dart
    └── droobi_bottom_nav.dart
```

</details>

### ⚙️ Tech Stack

| Layer | Tech |
|---|---|
| App | Flutter · Dart |
| State | Riverpod |
| Auth & DB | Firebase Authentication · Cloud Firestore |
| Search | OpenStreetMap / Nominatim |
| Routing | OSRM |
| Location & heading | Geolocator · Flutter Compass |
| Voice in | Whisper / whisper.cpp (on-device) |
| Voice out | Flutter TTS |
| Bluetooth | Flutter Blue Plus |
| Wearable | ESP32 |

---

## 🎨 Design Principles

Built for people who can't rely on a screen, so every choice follows from that:

- 🎯 **Audio and haptics first**, visuals second
- 👆 **Large touch targets**, minimal clutter
- 🔤 **High contrast and readability** (primary color `#2F80ED`)
- 📶 **Always-visible belt connection status**
- 🌍 **Arabic and English as equals**

---

## 📱 Screenshots

> 📌 Drop your images into `assets/screenshots/`.

| Login | Home | Search | Settings | Navigation |
|:---:|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/login.png" width="160"> | <img src="assets/screenshots/home.png" width="160"> | <img src="assets/screenshots/search.png" width="160"> | <img src="assets/screenshots/settings.png" width="160"> | <img src="assets/screenshots/navigation.png" width="160"> |

---

## 🚀 Quick Start

**You'll need:** Flutter SDK, Android Studio + Android SDK, Git, and a physical Android device (recommended for GPS, compass, and BLE).

```bash
# 1. Check your setup
flutter doctor

# 2. Clone
git clone https://github.com/Salahaldin-tech/droobi-wearable-navigation-belt.git
cd droobi-wearable-navigation-belt

# 3. Install dependencies
flutter pub get

# 4. Run (device connected or emulator started)
flutter run
```

### 🔥 Firebase setup

Enable **Authentication** and **Cloud Firestore** for your project and add the Firebase config files for your platform.

| Collection | Purpose |
|---|---|
| `users/{uid}` | User profile + role (`user` / `admin`) |
| `universityLocations/{universityId}` | Shared university location data |

### 🧪 Developer tools

Admins get a hidden testing hub for routing, BLE, and other components:

```
Settings → Developer → Dev Test Menu
```

---

## 🛣️ Roadmap

```mermaid
gantt
    title Droobi progress
    dateFormat  YYYY-MM-DD
    axisFormat  %b
    section 📱 App
    Foundation, auth, search, routing, voice, TTS, BLE layer :done, a1, 2026-01-01, 120d
    section 🦯 Belt
    Hardware architecture + motor layout :done, b1, 2026-04-01, 60d
    ESP32 firmware + motor control       :active, b2, 2026-06-01, 60d
    BLE protocol + prototype + testing   :b3, after b2, 60d
```

### 📱 Mobile app: ✅ core complete

- [x] Flutter foundation
- [x] Firebase Auth + Firestore profiles
- [x] Role-based admin access
- [x] Destination search + city selection (OSM / Nominatim)
- [x] GPS location + OSRM routing
- [x] Voice input (Whisper) + Text-to-Speech
- [x] BLE communication layer
- [x] Settings + Developer test menu

### 🦯 Wearable belt: 🔨 in progress

- [x] ESP32 hardware architecture
- [x] BLE communication design
- [x] Motor layout design
- [ ] ESP32 firmware
- [ ] Motor control
- [ ] Complete BLE command protocol
- [ ] Physical belt prototype
- [ ] Hardware integration testing
- [ ] Navigation accuracy testing

### 🔭 What's next

- Better GPS filtering and heading estimation
- Smarter route-following logic
- More robust BLE reconnection
- Richer vibration patterns
- Battery optimization
- Better Arabic voice interaction
- **Testing with visually impaired users** and safety improvements

---

## 🤝 Contributing

Ideas, bug reports, and PRs are welcome.

```bash
git checkout -b feature/your-feature
git commit -m "Add your feature"
git push origin feature/your-feature
```

Then open a Pull Request.

---

## 📜 License

Developed as an academic / graduation project. If you want to reuse, distribute, or commercially deploy it, please contact the authors first.

---

<div align="center">

### 🦯 Droobi

**Technology that helps you find your way, without needing to see it.**

Built with Flutter • Firebase • OpenStreetMap • ESP32 • BLE

</div>
