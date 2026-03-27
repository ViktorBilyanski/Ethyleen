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
│  MQ-9  (CH4/CO)       │       │  FCM Push     │       │  Alerts       │
│  BME280 (Temp/Hum)    │       │  Claude API   │       │  AI Recipes   │
│  LiPo 3000mAh        │       │               │       │  Battery %    │
└──────────────────────┘       └──────────────┘       └──────────────┘
```

## Project Structure

```
Ethyleen/
├── firmware/               # ESP32-S3 Arduino firmware
│   └── ethyleen/
│       ├── ethyleen.ino    # Main firmware (sensors, WiFi, Firebase upload)
│       └── config.h        # WiFi, Firebase, pin and calibration config
├── firebase/               # Firebase backend
│   ├── firebase.json       # Firebase project config
│   ├── database.rules.json # Realtime Database security rules
│   └── functions/
│       ├── index.js        # Cloud Functions (alerts, battery, Claude API recipes)
│       ├── package.json    # Node.js dependencies
│       └── .env.example    # API key template
└── app/                    # Flutter mobile app
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── models/         # Data models
        ├── screens/        # Dashboard, History screens
        ├── services/       # Firebase service layer
        └── widgets/        # Gauge, chart, card components
```

## How It Works

**Gas Sensors** — Three MQ-series sensors detect different spoilage gases:
- **MQ-135** (Elimex K2187/K2281): Ammonia and CO2 from protein breakdown (meat, fish, dairy)
- **MQ-3** (Elimex K2091): Ethanol from fermentation (fruits, vegetables, bread)
- **MQ-9** (Elimex K2134): Methane and CO from anaerobic bacteria (sealed/vacuum-packed food)

**Environment Sensor** — The **MOD-BME280** (Olimex) tracks fridge temperature and humidity. These readings are used to compensate gas sensor readings (MQ sensor resistance drifts with temperature/humidity) and displayed in the app.

**Intelligence** — The firmware doesn't just check thresholds. It tracks trends over a rolling window — a slow steady rise over hours triggers a warning, while a single spike (like opening the fridge door) is ignored.

**Freshness levels**:
- **FRESH** — all sensors below baseline
- **WARNING** — one or more sensors rising with a confirmed upward trend
- **SPOILED** — sensors significantly above threshold

**Cloud pipeline** — The ESP32-S3 uploads readings to Firebase every 30 seconds. When warning/spoiled is detected, a Cloud Function sends a push notification and calls the Claude API to generate a recipe to use the affected food before it's too late. A separate function alerts when battery drops below 15%.

## Hardware (Bill of Materials)

| Component | Part Number | Purpose | Connection |
|-----------|-------------|---------|------------|
| ESP32-S3-DevKit-Lipo | Olimex #1 | Microcontroller + WiFi + LiPo charger | — |
| MQ-135 | Elimex K2187/K2281 | Ammonia/CO2 detection | AO → GPIO 1 |
| MQ-3 | Elimex K2091 | Ethanol detection | AO → GPIO 2 |
| MQ-9 | Elimex K2134 | Methane/CO detection | AO → GPIO 4 |
| MOD-BME280 | Olimex #36 | Temperature + humidity | UEXT (I2C: SDA=GPIO8, SCL=GPIO9) |
| MT3608 | Olimex #13 | Boost converter 3.7V → 5V for MQ heaters | Battery → 5V out |
| LiPo Battery | 3.7V 3000mAh JST | Power source | JST connector on ESP32-S3 |
| BREADBOARD-MAXI | Olimex #56 | Wiring organization | — |
| Jumper Wires FF | Olimex #57 | Sensor connections | — |
| Jumper Wires MM | Olimex #58 | Breadboard connections | — |
| Jumper Wires MF | Olimex #59 | Mixed connections | — |
| CABLE-UEXT-JWF | Olimex #62 | BME280 → ESP32-S3 UEXT port | Direct plug |

### Wiring Diagram

```
                    ┌─────────────────────────────┐
                    │   ESP32-S3-DevKit-Lipo       │
                    │          (Olimex)             │
                    │                               │
   MQ-135 AO ──────┤ GPIO 1 (ADC1_CH0)             │
   MQ-3  AO ──────┤ GPIO 2 (ADC1_CH1)             │
   MQ-9  AO ──────┤ GPIO 4 (ADC1_CH3)             │
                    │                               │
                    │ UEXT ◄── CABLE-UEXT-JWF ──── MOD-BME280
                    │   (SDA=GPIO8, SCL=GPIO9)      │
                    │                               │
   LiPo 3.7V ──────┤ JST Battery Connector         │
                    │   └── GPIO 3 (battery sense)  │
                    └─────────────────────────────┘

   MT3608 Boost Converter:
   Battery 3.7V ──▶ MT3608 IN ──▶ MT3608 OUT (5V) ──▶ MQ-135 VCC
                                                   ──▶ MQ-3  VCC
                                                   ──▶ MQ-9  VCC

   All MQ sensor GND pins → common GND on breadboard
   MT3608 GND → common GND on breadboard
   ESP32-S3 GND → common GND on breadboard
```

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
- `WiFi` (built-in with ESP32-S3)
- `HTTPClient` (built-in with ESP32-S3)
- `Wire` (built-in)

**Steps**:
1. Open `firmware/ethyleen/ethyleen.ino` in Arduino IDE
2. Edit `config.h` with your WiFi credentials and Firebase URL
3. Wire sensors as shown in the diagram above
4. Select board: **"ESP32S3 Dev Module"** (or "OLIMEX ESP32-S3-DevKit-Lipo" if available)
5. Upload via USB-C

### 2. Firebase

**Steps**:
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Realtime Database
3. Deploy database rules: `firebase deploy --only database` (from the `firebase/` directory)
4. Deploy Cloud Functions:
   ```bash
   cd firebase/functions
   cp .env.example .env    # Add your Anthropic API key
   npm install
   cd ..
   firebase deploy --only functions
   ```

### 3. Flutter App

**Steps**:
1. Add your Firebase config files:
   - Android: download `google-services.json` → `app/android/app/`
   - iOS: download `GoogleService-Info.plist` → `app/ios/Runner/`
2. Run:
   ```bash
   cd app
   flutter pub get
   flutter run
   ```

## Power Notes

- The **LiPo 3000mAh battery** powers the ESP32-S3 directly via the JST connector. The board has a built-in charger — plug in USB-C to charge.
- MQ sensors need 5V for their internal heaters. The **MT3608 boost converter** steps up the battery's 3.7V to 5V. Adjust the MT3608 potentiometer until the output reads exactly 5.0V before connecting sensors.
- MQ sensors draw ~150mA each at 5V (heater). Total system draw is ~500-600mA. With a 3000mAh battery, expect roughly 5-6 hours of runtime. For continuous monitoring, keep the USB-C cable plugged in or use a larger battery.
- The firmware monitors battery voltage via GPIO 3 and reports it to the app. A Cloud Function sends a push notification when battery drops below 15%.
