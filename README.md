```
        __          .__
_______/  |_ ___.__.|  |_______
\____ \   __<   |  ||  |\_  __ \
|  |_> >  |  \___  ||  |_|  | \/
|   __/|__|  / ____||____/__|
|__|         \/

https://ptylr.com  
https://www.linkedin.com/in/ptylr/
```

# LibreArm

LibreArm is an open-source iOS app that connects directly to the **QardioArm** blood pressure monitor via Bluetooth Low Energy (BLE) and saves readings into **Apple Health**.  
This project exists because Qardio, Inc. shut down its backend services and app support, leaving the QardioArm hardware functional but unusable with the original app.

- 📲 **Available on the [Apple App Store](https://apps.apple.com/gb/app/librearm/id6752661389)**  
- 💻 Open source on [GitHub](https://github.com/ptylr/LibreArm) for transparency and community contributions  

---

## ✨ Features (v1.3.0)

### New in v1.3.0

- Added **Delay Between Readings** slider — choose between 10s, 30s, or 60s intervals for Average Mode.
- Average Mode label updated to “Average (3 readings)” for clarity.
- Added live countdown between readings that reflects the user-selected delay value.
- Enhanced reliability: the **Stop Measurement** button now remains active and red for the entire multi-run session.
- Improved UI alignment for toggles and controls.
- Version updated to 1.3.0.

---
## ✨ Features (v1.2.0)

- Connects to QardioArm over BLE (no Qardio cloud or accounts required)
- **Connection management**:
  - Start scanning automatically on launch
  - Retry button with 30-second connection timeout (hidden when connected)
  - Device status always visible in the UI
- **Measurement handling**:
  - ✅ Improved reliability: readings are now only saved to Health **once the full blood pressure cycle is complete**
  - Single, debounced save to HealthKit (no partial inflating entries)
  - Dynamic **Start/Stop button**  
    - Blue *Start Measurement* when idle  
    - Red *Stop Measurement* while inflating, sends cancel on tap
- **UI improvements**:
  - Centered title and status
  - App icon displayed in header
  - Card-style layout for latest reading (systolic, diastolic, MAP, heart rate)
  - Developer credit and GitHub link footer
- 100% local: no accounts, no data leaves your device

---

## 📲 Installation

### 1. From the App Store (recommended)
Download directly from the App Store:  
👉 [LibreArm on the App Store](https://apps.apple.com/gb/app/librearm/id6752661389)  

### 2. Build from source
If you’d like to build it yourself:

```bash
git clone https://github.com/ptylr/LibreArm.git
cd LibreArm
open LibreArm.xcodeproj
```

Requirements:
- Xcode 15+
- iOS 16+ device (QardioArm does not work in the simulator)
- Apple ID signed into Xcode (free dev account OK for local builds)

On first run you’ll be prompted for:
- **Bluetooth access** (to connect to the cuff)
- **Health access** (to save readings)

---

## 🖼 Screenshots

<table>
  <tr>
    <td><img src="./images/screenshots/LibreArm_iPhone16Pro_AppleHealth_Permissions.png" width="250" alt="Apple Health Permissions"/></td>
    <td><img src="./images/screenshots/LibreArm_iPhone16Pro_Home_Connecting.png" width="250" alt="LibreArm connecting to QardioArm"/></td>
    <td><img src="./images/screenshots/LibreArm_iPhone16Pro_Home_Connected.png" width="250" alt="LibreArm connected to QardioArm"/></td>
    <td><img src="./images/screenshots/LibreArm_iPhone16Pro_Home_Measuring.png" width="250" alt="LibreArm measuring Blood Pressure + Pulse"/></td>
  </tr>
</table>

---

## 📱 Flutter Version (v2.0)

A cross-platform Flutter implementation is available in the `flutter_app/` directory, providing support for **iOS and Android** from a single codebase.

### Features
- All features from the native iOS app
- Low battery detection (prevents false readings when device battery is low)
- Cross-platform: iOS, Android (and potentially Web, macOS, Windows, Linux)
- Red logo to differentiate from native iOS app (optional styling choice)

> **Note:** Currently only tested on iPhone. Android testing pending.

### Build from source (Flutter)

#### Prerequisites
1. Install Flutter: [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
2. Verify installation: `flutter doctor`

#### iOS Build
```bash
git clone https://github.com/ashok-raj/LibreArm.git
cd LibreArm/flutter_app

# Install dependencies
flutter pub get

# Install CocoaPods dependencies
cd ios && pod install && cd ..

# Run on connected iPhone
flutter run -d <device-id>

# Or build release IPA
flutter build ios --release
```

Requirements:
- macOS with Xcode 15+
- CocoaPods (`brew install cocoapods`)
- Physical iOS device (BLE doesn't work in simulator)
- Apple Developer account for device deployment

#### Android Build
```bash
git clone https://github.com/ashok-raj/LibreArm.git
cd LibreArm/flutter_app

# Install dependencies
flutter pub get

# Run on connected Android device
flutter run -d <device-id>

# Or build release APK
flutter build apk --release
```

Requirements:
- Android Studio with Android SDK
- Physical Android device (for BLE testing)

#### Useful Commands
```bash
flutter devices          # List connected devices
flutter run              # Run in debug mode
flutter run --release    # Run in release mode
flutter build apk        # Build Android APK
flutter build ios        # Build iOS app
```

For more details, see the official [Flutter documentation](https://docs.flutter.dev/).

### Code Comparison

For transparency, here's how the Flutter codebase compares to the native iOS app:

| | Native iOS (Swift) | Flutter (Dart) |
|---|---|---|
| **Total Lines** | 612 | 822 |
| **Difference** | - | +210 lines (+34%) |

**Breakdown by file:**

| Native iOS | Lines | Flutter | Lines |
|---|---|---|---|
| BPClient.swift | 401 | bp_client.dart | 391 |
| ContentView.swift | 167 | main.dart | 335 |
| Health.swift | 29 | health_service.dart | 75 |
| LibreArmApp.swift | 15 | bp_reading.dart | 21 |

The core BLE logic is nearly identical. The UI code is larger in Flutter due to more verbose widget syntax, but the tradeoff is cross-platform support.

---

## 🔧 Development Notes

- **Language & UI**: Swift + SwiftUI
- **Bluetooth**: CoreBluetooth (service 0x1810, char 0x2A35 + vendor control UUID `583CB5B3-875D-40ED-9098-C39EB0C1983D`)
- **Health**: HealthKit (blood pressure and heart rate types)
- **App Icon**: Custom design included in `Assets.xcassets`

The app implements a debounce strategy so that **only the final reading** after a measurement is saved, preventing dozens of partial entries in Health.  
As of v1.1.1, LibreArm further ensures that **both systolic and diastolic readings are present** before saving to Apple Health.

---

## 🛡 Privacy

- LibreArm does **not** connect to the internet.  
- All readings stay on your device.  
- Data is saved into **Apple Health** if permission is granted.

---

## 🤝 Contributing

Pull requests are welcome! If you’d like to contribute improvements (UI, Bluetooth stability, documentation), please fork the repo and open a PR.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

---

## Disclaimer
This document is provided for information purposes only. Paul Taylor may change the contents hereof without notice. This document is not warranted to be error-free, nor subject to any other warranties or conditions, whether expressed orally or implied in law, including implied warranties and conditions of merchantability or fitness for a particular purpose. Paul Taylor specifically disclaims any liability with respect to this document and no contractual obligations are formed either directly or indirectly by this document. The technologies, functionality, services, and processes described herein are subject to change without notice.

LibreArm is **not affiliated with or endorsed by Qardio, Inc.**  
QardioArm™ is a trademark of Qardio, Inc. This project is community-driven to keep existing hardware usable.
