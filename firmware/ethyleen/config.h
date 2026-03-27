#ifndef CONFIG_H
#define CONFIG_H

// ==================== WiFi ====================
#define WIFI_SSID     "edge40neo_3974"
#define WIFI_PASSWORD "1234parola"

// ==================== Firebase ====================
// Firebase Realtime Database URL (no trailing slash)
// Example: "https://ethyleen-default-rtdb.firebaseio.com"
#define FIREBASE_HOST "https://ethyleen-9d1d5-default-rtdb.europe-west1.firebasedatabase.app"

// Firebase database secret or Web API key for authentication
#define FIREBASE_AUTH "QaINzImywWn1zrICVHmYaFFQMpXjijLxnucUORbg"

// ==================== Board: Olimex ESP32-S3-DevKit-Lipo ====================
// ADC1 pins only (ADC2 cannot be used while WiFi is active on ESP32-S3)
// UEXT I2C uses GPIO 8 (SDA) and GPIO 9 (SCL) — reserved for BME280

// ==================== MQ Sensor Pins (analog, ADC1) ====================
#define MQ135_PIN  1   // GPIO1 — Ammonia/CO2 (Elimex K2187/K2281)
#define MQ3_PIN    2   // GPIO2 — Ethanol     (Elimex K2091)
#define MQ9_PIN    4   // GPIO4 — Methane/CO  (Elimex K2134)

// ==================== BME280 (Olimex MOD-BME280) ====================
// Connected via UEXT port using CABLE-UEXT-JWF
#define BME280_SDA   8      // UEXT pin 6
#define BME280_SCL   9      // UEXT pin 5
#define BME280_ADDR  0x77   // Your BME280's I2C address

// ==================== Battery Monitoring ====================
// Olimex ESP32-S3-DevKit-Lipo has a voltage divider for battery sensing
#define BAT_SENSE_PIN  3    // GPIO3 — battery voltage (via divider)
#define BAT_DIVIDER    2.0  // Voltage divider ratio (adjust if needed)
#define BAT_FULL_V     4.2  // Fully charged LiPo voltage
#define BAT_EMPTY_V    3.3  // Cutoff voltage

// ==================== Sensor Calibration ====================
// Calibrated from your sensors' clean-air readings (raw: 560, 1036, 295)
#define MQ135_R0 17.53  // kOhm
#define MQ3_R0   0.49   // kOhm
#define MQ9_R0   12.88  // kOhm

// Load resistor value on Elimex sensor boards
#define RL_VALUE 10.0  // kOhm (check your board — some use 1kOhm)

// ==================== Thresholds (ppm) ====================
// Below WARNING = FRESH, between WARNING and SPOILED = WARNING, above SPOILED = SPOILED
#define MQ135_WARNING_PPM  30.0
#define MQ135_SPOILED_PPM  80.0

#define MQ3_WARNING_PPM    15.0
#define MQ3_SPOILED_PPM    50.0

#define MQ9_WARNING_PPM    20.0
#define MQ9_SPOILED_PPM    60.0

// ==================== Timing ====================
#define READING_INTERVAL_MS  30000   // 30 seconds between readings
#define TREND_WINDOW_SIZE    20      // Number of readings for trend analysis
#define UPLOAD_INTERVAL_MS   30000   // Upload every 30 seconds

// ==================== Device ====================
#define DEVICE_ID "ethyleen-001"

#endif
