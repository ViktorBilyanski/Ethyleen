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

// ==================== Battery Monitoring (Power Bank) ====================
// Time-based estimate — no hardware sensor needed
// Adjust these values for your setup:
#define POWERBANK_CAPACITY_MAH  10000  // Power bank capacity in mAh
#define ESTIMATED_CURRENT_MA    600    // Total draw: ESP32 ~150mA + 3x MQ heaters ~450mA

// ==================== Sensor Calibration ====================
// Default R0 values (used if never calibrated via app)
// Calibrated from clean-air readings at ~23°C (raw: 560, 1036, 295)
#define MQ135_R0_DEFAULT 17.53  // kOhm
#define MQ3_R0_DEFAULT   0.49   // kOhm
#define MQ9_R0_DEFAULT   12.88  // kOhm

// Load resistor value on Elimex sensor boards
#define RL_VALUE 10.0  // kOhm (check your board — some use 1kOhm)

// Clean air resistance ratios (from datasheets)
// R0 = Rs_in_clean_air / clean_air_factor
#define MQ135_CLEAN_AIR_FACTOR  3.6
#define MQ3_CLEAN_AIR_FACTOR    10.0
#define MQ9_CLEAN_AIR_FACTOR    9.8

// Calibration settings
#define CALIBRATION_SAMPLES     50      // Number of samples to average
#define CALIBRATION_DELAY_MS    500     // Delay between samples (~25s total)
#define CALIBRATION_CHECK_MS    10000   // Check for calibration command every 10s

// ==================== Thresholds ====================
// After calibration, thresholds are calculated as: baseline_ppm * multiplier
// These multipliers control sensitivity:
#define WARNING_MULTIPLIER  3.0f   // warning at 3x the clean baseline
#define SPOILED_MULTIPLIER  8.0f   // spoiled at 8x the clean baseline

// Minimum floors (prevent false positives from sensor noise)
#define MQ135_MIN_WARNING  1.0f
#define MQ3_MIN_WARNING    0.2f
#define MQ9_MIN_WARNING    0.3f

// Default thresholds (used before first calibration)
#define MQ135_WARNING_DEFAULT  4.0
#define MQ135_SPOILED_DEFAULT  10.0
#define MQ3_WARNING_DEFAULT    0.5
#define MQ3_SPOILED_DEFAULT    2.0
#define MQ9_WARNING_DEFAULT    1.5
#define MQ9_SPOILED_DEFAULT    5.0

// ==================== Timing ====================
#define READING_INTERVAL_MS  30000   // 30 seconds between readings
#define TREND_WINDOW_SIZE    20      // Number of readings for trend analysis
#define UPLOAD_INTERVAL_MS   30000   // Upload every 30 seconds

// ==================== Device ====================
#define DEVICE_ID "ethyleen-001"

#endif
