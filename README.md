# Ethyleen

Сензори, които следят годността на храната, и изпращат нотификация на потребителя когато някой продукт е на път да се развали, като по този начин се намалява прахосването на храна.

Smart food freshness monitor — detects spoilage gases inside your fridge before you can smell them, sends real-time alerts to your phone, and suggests recipes to use food before it goes bad.

## Architecture

```
┌──────────────────────┐       ┌──────────────┐       ┌──────────────┐
│  ESP32-S3 Capsule     │──WiFi──▶  Firebase     │◀──────│  Flutter App  │
│  (in fridge)          │       │  Cloud        │──────▶│  (your phone) │
│                       │       │               │       │               │
│  MQ-135 (NH3)         │       │  Realtime DB  │       │  Dashboard    │
│  MQ-3  (EtOH)        │       │  Cloud Funcs  │       │  History      │
│  MQ-9  (CH4/CO)       │       │  FCM Push     │       │  Settings     │
│  BME280 (Temp/Hum)    │       │  Claude API   │       │  Notifications│
│  Power Bank (USB)     │       │               │       │  AI Recipes   │
└──────────────────────┘       └──────────────┘       └──────────────┘
```

## Project Structure

```
Ethyleen/
├── firmware/                       # ESP32-S3 Arduino firmware
│   ├── ethyleen/
│   │   ├── ethyleen.ino            # Main firmware (sensors, WiFi, Firebase, calibration)
│   │   └── config.h                # WiFi, Firebase, pins, thresholds, calibration config
│   ├── hardware_test/
│   │   └── hardware_test.ino       # Standalone sensor/wiring test (no WiFi needed)
│   └── i2c_scan/
│       └── i2c_scan.ino            # I2C bus scanner for finding BME280 address
├── firebase/                       # Firebase backend
│   ├── firebase.json               # Firebase project config
│   ├── database.rules.json         # Realtime Database security rules
│   └── functions/
│       ├── index.js                # Cloud Functions (alerts, battery, Claude API recipes)
│       ├── package.json            # Node.js dependencies
│       └── .env.example            # API key template
└── app/                            # Flutter mobile app
    ├── pubspec.yaml
    └── lib/
        ├── main.dart               # App entry, theme switching, onboarding gate
        ├── models/
        │   └── sensor_reading.dart  # SensorReading model + FreshnessLevel enum
        ├── screens/
        │   ├── dashboard_screen.dart # Live gauges, environment card, device status, 24h summary
        │   ├── history_screen.dart   # Zoomable chart, stats, CSV export
        │   ├── settings_screen.dart  # Theme, alerts, thresholds, environment presets
        │   └── onboarding_screen.dart # First-launch intro wizard (4 pages)
        ├── services/
        │   ├── firebase_service.dart  # Realtime DB streams, history queries, calibration
        │   ├── alert_service.dart     # Local push notifications (respects mute/toggle)
        │   └── settings_service.dart  # SharedPreferences persistence for all settings
        └── widgets/
            ├── sensor_gauge.dart       # Circular arc gauge per gas sensor
            ├── freshness_indicator.dart # FRESH / WARNING / SPOILED banner
            ├── recipe_card.dart        # AI-generated recipe display
            └── history_chart.dart      # Zoomable multi-line fl_chart with pinch/pan
```

## Features

### Firmware
- **Three gas sensors** (MQ-135, MQ-3, MQ-9) with temperature/humidity compensation
- **Trend analysis** — rolling window linear regression avoids false alarms from fridge door openings
- **Remote calibration** — calibrate sensors from the app; R0 values and thresholds saved to NVS (persist across reboots)
- **Dynamic thresholds** — after calibration, warning/spoiled thresholds are automatically calculated as multiples of the baseline (3x/8x)
- **Power bank battery estimate** — time-based calculation from configurable capacity and current draw

### App
- **Dashboard** — live freshness status, three sensor gauges, fridge environment card with ideal range bars, device status, 24h summary
- **Interactive elements** — tap any card/gauge for detailed bottom sheets with explanations
- **History** — zoomable/pannable line chart (pinch to zoom, drag to pan, double-tap to reset), time range selector (6h/24h/3d/7d), stats with time-in-state bar
- **Settings** — dark/light theme toggle, notification enable/mute with timer, power bank capacity, custom alert thresholds with per-sensor sliders, environment presets (Fridge/Room) with adjustable temp/humidity ranges, onboarding replay
- **Onboarding** — 4-page intro wizard shown on first launch (Welcome, Sensors, Setup, Notifications)
- **CSV export** — copy history data to clipboard from the History tab
- **Push notifications** — local alerts when freshness changes to warning/spoiled (respects mute and enable settings)
- **Dark/light theme** — Google Material-inspired light mode with white cards and shadows; dark mode with deep blue surfaces
- **Real-time timestamp** — "Updated Xs ago" counts live every second without flickering the rest of the UI

### Cloud (Firebase)
- **Realtime Database** — latest readings, history log, calibration data, commands, thresholds
- **Cloud Functions** — FCM push notifications, Claude API recipe generation, battery low alerts, daily history cleanup
- **Database paths** — `/readings`, `/history`, `/alerts`, `/recipes`, `/commands`, `/calibration`

## How It Works

**Gas Sensors** — Three MQ-series sensors detect different spoilage gases:
- **MQ-135** (Elimex K2187/K2281): Ammonia and CO2 from protein breakdown (meat, fish, dairy)
- **MQ-3** (Elimex K2091): Ethanol from fermentation (fruits, vegetables, bread)
- **MQ-9** (Elimex K2134): Methane and CO from anaerobic bacteria (sealed/vacuum-packed food)

**Environment Sensor** — The **MOD-BME280** (Olimex) tracks temperature and humidity. These readings compensate gas sensor drift and are displayed in the app with configurable ideal ranges.

**Calibration Flow**:
1. User taps the tune icon in the app
2. App sends a calibration command to Firebase
3. ESP32 takes 50 averaged samples over ~25 seconds
4. Calculates new R0 values for each sensor using clean air ratios
5. Computes dynamic thresholds (baseline x 3 for warning, baseline x 8 for spoiled)
6. Saves everything to NVS (persists across reboots) and reports back to Firebase
7. App updates gauges and alert logic with the new thresholds

**Freshness levels**:
- **FRESH** — all sensors below warning threshold
- **WARNING** — one or more sensors elevated with a confirmed rising trend
- **SPOILED** — sensors significantly above spoiled threshold

**Trend analysis** — The firmware tracks a rolling window of 20 readings and uses linear regression to detect sustained rises. A single spike (like opening the fridge door) is ignored; only a persistent upward trend triggers a warning.

**Cloud pipeline** — The ESP32-S3 uploads readings to Firebase every 30 seconds. When warning/spoiled is detected, a Cloud Function sends an FCM push notification and calls the Claude API (claude-sonnet-4-6) to generate a recipe. The app also fires local notifications independently. A scheduled function cleans up history entries older than 7 days.

## Hardware (Bill of Materials)

| Component | Part Number | Purpose | Connection |
|-----------|-------------|---------|------------|
| ESP32-S3-DevKit-Lipo | Olimex | Microcontroller + WiFi + LiPo charger | — |
| MQ-135 | Elimex K2187/K2281 | Ammonia/CO2 detection | AO -> GPIO 1 |
| MQ-3 | Elimex K2091 | Ethanol detection | AO -> GPIO 2 |
| MQ-9 | Elimex K2134 | Methane/CO detection | AO -> GPIO 4 |
| MOD-BME280 | Olimex | Temperature + humidity | UEXT (I2C: SDA=GPIO8, SCL=GPIO9) |
| MT3608 | Olimex | Boost converter 3.7V -> 5V for MQ heaters | Battery -> 5V out |
| USB Power Bank | 10000mAh | Power source | USB-C to ESP32-S3 |
| Breadboard | Olimex | Wiring organization | — |
| Jumper Wires | Olimex | Sensor connections | — |
| CABLE-UEXT-JWF | Olimex | BME280 -> ESP32-S3 UEXT port | Direct plug |

### Wiring Diagram

<img width="916" height="720" alt="image" src="https://github.com/user-attachments/assets/789c0df1-3542-476f-8aa1-38991c472ee3" />


### What Else You Might Need

- **USB-C cable** — for programming the ESP32-S3 and charging the battery (may be included with the dev kit)
- **Enclosure** — a ventilated plastic container or 3D-printed capsule to hold everything inside the fridge; must have holes/slots so air reaches the MQ sensors

That's it — your BOM is complete for a working prototype.

## Setup

### 1. ESP32-S3 Firmware

**Requirements**: Arduino IDE with ESP32-S3 board support (Espressif Arduino core v2.0+).

**Libraries needed** (install via Arduino Library Manager):
- `ArduinoJson` (v7+)
- `Adafruit BME280 Library`
- `Adafruit Unified Sensor`
- `WiFi`, `HTTPClient`, `Wire`, `Preferences` (built-in with ESP32-S3)

**Steps**:
1. Wire sensors as shown in the diagram above
2. Upload `firmware/i2c_scan/i2c_scan.ino` first to confirm your BME280's I2C address (usually 0x76 or 0x77)
3. Upload `firmware/hardware_test/hardware_test.ino` to verify all sensors are reading correctly
4. Edit `firmware/ethyleen/config.h` with your WiFi credentials, Firebase URL, and BME280 address
5. Upload `firmware/ethyleen/ethyleen.ino` — board: **"ESP32S3 Dev Module"**, USB CDC On Boot: **Enabled**
6. Open Serial Monitor (115200 baud) to verify readings

### 2. Firebase

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Realtime Database (europe-west1 recommended)
3. Deploy database rules from `firebase/database.rules.json`
4. Deploy Cloud Functions (requires Blaze plan):
   ```bash
   cd firebase/functions
   cp .env.example .env    # Add your Anthropic API key
   npm install
   cd ..
   firebase deploy --only functions
   ```

### 3. Flutter App

**Requirements**: Flutter SDK 3.1+ with Dart >=3.1.0.

**Note**: If your Windows username has a space (e.g., "Petar Antonov"), the app must be built from a path without spaces (e.g., `C:\Dev\ethyleen-app`) due to an `objective_c` build issue.

**Dependencies** (installed automatically via `flutter pub get`):
- `firebase_core` + `firebase_database` — Realtime DB connection
- `fl_chart` — zoomable sensor history charts
- `intl` — date/time formatting
- `flutter_local_notifications` — on-device spoilage alerts
- `shared_preferences` — settings persistence

**Steps**:
1. Copy the app to a path without spaces: `xcopy app C:\Dev\ethyleen-app /E /I`
2. Add your Firebase config: download `google-services.json` -> `android/app/`
3. Run:
   ```bash
   cd C:\Dev\ethyleen-app
   flutter pub get
   flutter run
   ```

### 4. First Use

1. The app shows a 4-page onboarding tutorial on first launch
2. Place the device in your fridge with only fresh food
3. Tap the **tune icon** in the app bar to calibrate sensors (~25 seconds)
4. The device will now monitor continuously and alert you when spoilage is detected
5. Adjust ideal temperature/humidity ranges in **Settings > Environment** (Fridge or Room preset)

## Power Notes

- Powered by a **USB power bank** (10000mAh recommended) connected via USB-C
- Battery percentage is estimated based on elapsed time and current draw (~600mA)
- MQ sensors need 5V for their heaters — the **MT3608 boost converter** steps up to 5V
- Configure your power bank capacity in **Settings > Device > Power bank capacity**
- Expected runtime: ~16.6 hours with a 10000mAh power bank
- The firmware and app report battery percentage; a Cloud Function alerts when it drops below 15%
