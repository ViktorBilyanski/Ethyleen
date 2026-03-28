/*
 * Ethyleen — Food Freshness Monitor
 * Firmware for Olimex ESP32-S3-DevKit-Lipo
 *
 * Sensors:
 *   MQ-135 (Elimex K2187/K2281) — ammonia/CO2 (meat/fish spoilage)
 *   MQ-3   (Elimex K2091)       — ethanol (fruit/veg fermentation)
 *   MQ-9   (Elimex K2134)       — methane/CO (deep decay)
 *   MOD-BME280 (Olimex)         — temperature & humidity (via UEXT)
 *
 * Power: 3.7V 3000mAh LiPo → MT3608 boost to 5V for MQ heaters
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_BME280.h>
#include <Preferences.h>
#include <time.h>
#include "config.h"

// ==================== Data Structures ====================

enum FreshnessLevel {
  FRESH,
  WARNING,
  SPOILED
};

struct SensorReading {
  float mq135_ppm;
  float mq3_ppm;
  float mq9_ppm;
  float temperature;   // °C from BME280
  float humidity;      // %RH from BME280
  float battery_pct;   // 0-100%
  FreshnessLevel freshness;
  unsigned long timestamp;
};

// ==================== BME280 ====================

Adafruit_BME280 bme;
bool bme_ok = false;

// ==================== Calibration (NVS) ====================

Preferences prefs;
float active_mq135_r0 = MQ135_R0_DEFAULT;
float active_mq3_r0   = MQ3_R0_DEFAULT;
float active_mq9_r0   = MQ9_R0_DEFAULT;
unsigned long last_calibration_check = 0;
bool calibrating = false;

// ==================== Dynamic Thresholds ====================

float thresh_mq135_warning = MQ135_WARNING_DEFAULT;
float thresh_mq135_spoiled = MQ135_SPOILED_DEFAULT;
float thresh_mq3_warning   = MQ3_WARNING_DEFAULT;
float thresh_mq3_spoiled   = MQ3_SPOILED_DEFAULT;
float thresh_mq9_warning   = MQ9_WARNING_DEFAULT;
float thresh_mq9_spoiled   = MQ9_SPOILED_DEFAULT;

// ==================== Trend Tracking ====================

float mq135_history[TREND_WINDOW_SIZE];
float mq3_history[TREND_WINDOW_SIZE];
float mq9_history[TREND_WINDOW_SIZE];
int history_index = 0;
int history_count = 0;

// ==================== Timing ====================

unsigned long last_reading_time = 0;
unsigned long last_upload_time = 0;

// ==================== Latest Reading ====================

SensorReading latest_reading;

// ==================== Setup ====================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("===================================");
  Serial.println("  Ethyleen Food Monitor v1.0");
  Serial.println("  Olimex ESP32-S3-DevKit-Lipo");
  Serial.println("===================================");

  // Load calibration values from NVS (or use defaults)
  prefs.begin("ethyleen", false);
  active_mq135_r0 = prefs.getFloat("mq135_r0", MQ135_R0_DEFAULT);
  active_mq3_r0   = prefs.getFloat("mq3_r0", MQ3_R0_DEFAULT);
  active_mq9_r0   = prefs.getFloat("mq9_r0", MQ9_R0_DEFAULT);
  Serial.printf("Loaded R0 values: MQ135=%.2f  MQ3=%.2f  MQ9=%.2f\n",
                active_mq135_r0, active_mq3_r0, active_mq9_r0);

  // Load thresholds from NVS (or use defaults)
  thresh_mq135_warning = prefs.getFloat("t135w", MQ135_WARNING_DEFAULT);
  thresh_mq135_spoiled = prefs.getFloat("t135s", MQ135_SPOILED_DEFAULT);
  thresh_mq3_warning   = prefs.getFloat("t3w",   MQ3_WARNING_DEFAULT);
  thresh_mq3_spoiled   = prefs.getFloat("t3s",   MQ3_SPOILED_DEFAULT);
  thresh_mq9_warning   = prefs.getFloat("t9w",   MQ9_WARNING_DEFAULT);
  thresh_mq9_spoiled   = prefs.getFloat("t9s",   MQ9_SPOILED_DEFAULT);
  Serial.printf("Loaded thresholds: MQ135=%.2f/%.2f  MQ3=%.2f/%.2f  MQ9=%.2f/%.2f\n",
                thresh_mq135_warning, thresh_mq135_spoiled,
                thresh_mq3_warning, thresh_mq3_spoiled,
                thresh_mq9_warning, thresh_mq9_spoiled);

  // Initialize I2C for BME280 BEFORE configuring ADC
  // (ADC attenuation setting can interfere with GPIO 8/9 which are also ADC pins)
  Wire.begin(BME280_SDA, BME280_SCL);
  delay(100);  // Give BME280 time to power up

  if (bme.begin(BME280_ADDR, &Wire)) {
    bme_ok = true;
    Serial.println("BME280 found on UEXT port.");
    // Configure for low-power indoor monitoring
    bme.setSampling(
      Adafruit_BME280::MODE_FORCED,
      Adafruit_BME280::SAMPLING_X1,   // temperature
      Adafruit_BME280::SAMPLING_NONE,  // pressure (not needed)
      Adafruit_BME280::SAMPLING_X1,   // humidity
      Adafruit_BME280::FILTER_OFF
    );
  } else {
    Serial.println("WARNING: BME280 not found! Check wiring.");
  }

  // Configure ADC (ESP32-S3: 12-bit by default)
  // Done AFTER I2C init so attenuation doesn't affect GPIO 8/9
  analogReadResolution(12);  // 0-4095
  analogSetAttenuation(ADC_11db);  // Full 0-3.3V range

  // Initialize history arrays
  for (int i = 0; i < TREND_WINDOW_SIZE; i++) {
    mq135_history[i] = 0;
    mq3_history[i] = 0;
    mq9_history[i] = 0;
  }

  // Connect to WiFi
  connectWiFi();

  // Configure NTP for timestamps
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.println("Waiting for NTP time sync...");
  time_t now = time(nullptr);
  int attempts = 0;
  while (now < 1000000 && attempts < 20) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
    attempts++;
  }
  Serial.println();
  Serial.println("Time synchronized.");

  // Warm up MQ sensors (need ~2 minutes for stable readings)
  // MT3608 must be providing 5V to sensor heaters by now
  Serial.println("Warming up MQ sensors (30s)...");
  for (int i = 30; i > 0; i--) {
    Serial.printf("  %d seconds remaining...\n", i);
    delay(1000);
  }
  Serial.println("Sensors ready.");
  Serial.println();
}

// ==================== Main Loop ====================

void loop() {
  // Ensure WiFi stays connected
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  unsigned long now = millis();

  // Take a reading at the configured interval
  if (now - last_reading_time >= READING_INTERVAL_MS) {
    last_reading_time = now;

    // Read sensors
    latest_reading = readSensors();

    // Add to trend history
    addToHistory(latest_reading);

    // Print to serial
    printReading(latest_reading);
  }

  // Upload at the configured interval
  if (now - last_upload_time >= UPLOAD_INTERVAL_MS) {
    last_upload_time = now;
    uploadToFirebase(latest_reading);
  }

  // Check for calibration command from app
  if (!calibrating && now - last_calibration_check >= CALIBRATION_CHECK_MS) {
    last_calibration_check = now;
    checkCalibrationCommand();
  }
}

// ==================== WiFi ====================

void connectWiFi() {
  Serial.printf("Connecting to WiFi: %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(" Connected!");
    Serial.printf("  IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println(" FAILED. Will retry...");
  }
}

// ==================== BME280 Reading ====================

float readTemperature() {
  if (!bme_ok) return -99.0;
  bme.takeForcedMeasurement();
  return bme.readTemperature();
}

float readHumidity() {
  if (!bme_ok) return -1.0;
  return bme.readHumidity();
}

// ==================== Battery Monitoring (Power Bank) ====================
// Time-based estimate: assumes 100% at boot, counts down based on current draw

float readBatteryPercent() {
  float elapsed_hours = millis() / 3600000.0;
  float consumed_mah = elapsed_hours * ESTIMATED_CURRENT_MA;
  float pct = (1.0 - consumed_mah / POWERBANK_CAPACITY_MAH) * 100.0;
  return constrain(pct, 0.0, 100.0);
}

// ==================== Gas Sensor Reading ====================

float readAnalogAverage(int pin, int samples) {
  float sum = 0;
  for (int i = 0; i < samples; i++) {
    sum += analogRead(pin);
    delay(5);
  }
  return sum / samples;
}

// Temperature & humidity compensation factor for MQ sensors
// MQ sensor resistance drifts with ambient conditions
float getCompensationFactor(float temp, float hum) {
  if (temp < -40 || hum < 0) return 1.0;  // BME280 not available
  // Reference conditions: 20°C, 65% RH
  return 1.0 + 0.02 * (temp - 20.0) - 0.005 * (hum - 65.0);
}

float adcToPPM_MQ135(float adc_value, float comp_factor) {
  float voltage = (adc_value / 4095.0) * 3.3;
  if (voltage < 0.01) return 0;

  float rs = ((3.3 * RL_VALUE) / voltage) - RL_VALUE;
  rs /= comp_factor;  // Apply temperature/humidity compensation
  float ratio = rs / active_mq135_r0;

  // MQ-135 curve approximation for ammonia: m=-0.417, b=0.862
  if (ratio <= 0) return 0;
  float ppm = pow(10, ((log10(ratio) - 0.862) / -0.417));
  return max(0.0f, ppm);
}

float adcToPPM_MQ3(float adc_value, float comp_factor) {
  float voltage = (adc_value / 4095.0) * 3.3;
  if (voltage < 0.01) return 0;

  float rs = ((3.3 * RL_VALUE) / voltage) - RL_VALUE;
  rs /= comp_factor;
  float ratio = rs / active_mq3_r0;

  // MQ-3 curve for ethanol: m=-0.66, b=0.62
  if (ratio <= 0) return 0;
  float ppm = pow(10, ((log10(ratio) - 0.62) / -0.66));
  return max(0.0f, ppm);
}

float adcToPPM_MQ9(float adc_value, float comp_factor) {
  float voltage = (adc_value / 4095.0) * 3.3;
  if (voltage < 0.01) return 0;

  float rs = ((3.3 * RL_VALUE) / voltage) - RL_VALUE;
  rs /= comp_factor;
  float ratio = rs / active_mq9_r0;

  // MQ-9 curve for methane/CO: m=-0.48, b=0.72
  if (ratio <= 0) return 0;
  float ppm = pow(10, ((log10(ratio) - 0.72) / -0.48));
  return max(0.0f, ppm);
}

SensorReading readSensors() {
  SensorReading r;

  // Read environment from BME280 (via UEXT)
  r.temperature = readTemperature();
  r.humidity    = readHumidity();
  r.battery_pct = readBatteryPercent();

  // Compensation factor for gas sensor temperature/humidity drift
  float comp = getCompensationFactor(r.temperature, r.humidity);

  // Take averaged gas readings (10 samples each)
  float raw135 = readAnalogAverage(MQ135_PIN, 10);
  float raw3   = readAnalogAverage(MQ3_PIN, 10);
  float raw9   = readAnalogAverage(MQ9_PIN, 10);

  // Convert to compensated ppm
  r.mq135_ppm = adcToPPM_MQ135(raw135, comp);
  r.mq3_ppm   = adcToPPM_MQ3(raw3, comp);
  r.mq9_ppm   = adcToPPM_MQ9(raw9, comp);

  // Evaluate freshness using trend-aware logic
  r.freshness = evaluateFreshness(r);

  // Get Unix timestamp
  r.timestamp = (unsigned long)time(nullptr);

  return r;
}

// ==================== Trend Analysis ====================

void addToHistory(SensorReading r) {
  mq135_history[history_index] = r.mq135_ppm;
  mq3_history[history_index]   = r.mq3_ppm;
  mq9_history[history_index]   = r.mq9_ppm;

  history_index = (history_index + 1) % TREND_WINDOW_SIZE;
  if (history_count < TREND_WINDOW_SIZE) {
    history_count++;
  }
}

float getAverage(float* history, int count) {
  if (count == 0) return 0;
  float sum = 0;
  for (int i = 0; i < count; i++) {
    sum += history[i];
  }
  return sum / count;
}

float getTrend(float* history, int count) {
  // Returns positive value if readings are rising, negative if falling
  // Uses simple linear regression slope
  if (count < 3) return 0;

  float sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
  for (int i = 0; i < count; i++) {
    sum_x  += i;
    sum_y  += history[i];
    sum_xy += i * history[i];
    sum_x2 += i * i;
  }
  float n = (float)count;
  float slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
  return slope;
}

// ==================== Freshness Evaluation ====================

FreshnessLevel evaluateFreshness(SensorReading r) {
  // Check if any sensor is in SPOILED range (dynamic thresholds)
  if (r.mq135_ppm >= thresh_mq135_spoiled ||
      r.mq3_ppm   >= thresh_mq3_spoiled   ||
      r.mq9_ppm   >= thresh_mq9_spoiled) {
    return SPOILED;
  }

  // Check if any sensor is in WARNING range (dynamic thresholds)
  bool any_warning = (r.mq135_ppm >= thresh_mq135_warning ||
                      r.mq3_ppm   >= thresh_mq3_warning   ||
                      r.mq9_ppm   >= thresh_mq9_warning);

  if (any_warning) {
    // Confirm with trend — only warn if trend is rising (avoids false alarms)
    float trend135 = getTrend(mq135_history, history_count);
    float trend3   = getTrend(mq3_history, history_count);
    float trend9   = getTrend(mq9_history, history_count);

    // If at least one sensor shows a rising trend, it's a real warning
    if (trend135 > 0.1 || trend3 > 0.1 || trend9 > 0.1) {
      return WARNING;
    }

    // If we have enough history and no rising trend, likely a temporary spike
    if (history_count >= 5) {
      return FRESH;
    }

    // Not enough data yet — trust the raw reading
    return WARNING;
  }

  return FRESH;
}

const char* freshnessToString(FreshnessLevel level) {
  switch (level) {
    case FRESH:   return "fresh";
    case WARNING: return "warning";
    case SPOILED: return "spoiled";
    default:      return "unknown";
  }
}

// ==================== Firebase Upload ====================

void uploadToFirebase(SensorReading r) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, skipping upload.");
    return;
  }

  HTTPClient http;

  // Build URL: /readings/{device_id}.json?auth=...
  String url = String(FIREBASE_HOST) +
               "/readings/" + DEVICE_ID + ".json?auth=" + FIREBASE_AUTH;

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Build JSON payload
  JsonDocument doc;
  doc["mq135"]        = round(r.mq135_ppm * 10.0) / 10.0;
  doc["mq3"]          = round(r.mq3_ppm * 10.0) / 10.0;
  doc["mq9"]          = round(r.mq9_ppm * 10.0) / 10.0;
  doc["temperature"]  = round(r.temperature * 10.0) / 10.0;
  doc["humidity"]     = round(r.humidity * 10.0) / 10.0;
  doc["battery"]      = round(r.battery_pct);
  doc["freshness"]    = freshnessToString(r.freshness);
  doc["timestamp"]    = r.timestamp;
  doc["device"]       = DEVICE_ID;

  // Trend info
  float trend135 = getTrend(mq135_history, history_count);
  float trend3   = getTrend(mq3_history, history_count);
  float trend9   = getTrend(mq9_history, history_count);
  doc["trend_mq135"] = round(trend135 * 100.0) / 100.0;
  doc["trend_mq3"]   = round(trend3 * 100.0) / 100.0;
  doc["trend_mq9"]   = round(trend9 * 100.0) / 100.0;

  // Estimate hours until spoiled (based on trend slope)
  // Slope is ppm per reading; readings are READING_INTERVAL_MS apart
  float readings_per_hour = 3600000.0f / READING_INTERVAL_MS;
  float est_hours = -1;  // -1 means stable / not rising

  // Check each sensor, take the shortest estimate
  if (trend135 > 0.01f && r.mq135_ppm < thresh_mq135_spoiled) {
    float h = (thresh_mq135_spoiled - r.mq135_ppm) / (trend135 * readings_per_hour);
    if (est_hours < 0 || h < est_hours) est_hours = h;
  }
  if (trend3 > 0.01f && r.mq3_ppm < thresh_mq3_spoiled) {
    float h = (thresh_mq3_spoiled - r.mq3_ppm) / (trend3 * readings_per_hour);
    if (est_hours < 0 || h < est_hours) est_hours = h;
  }
  if (trend9 > 0.01f && r.mq9_ppm < thresh_mq9_spoiled) {
    float h = (thresh_mq9_spoiled - r.mq9_ppm) / (trend9 * readings_per_hour);
    if (est_hours < 0 || h < est_hours) est_hours = h;
  }

  doc["est_hours"] = round(est_hours * 10.0) / 10.0;

  String payload;
  serializeJson(doc, payload);

  Serial.printf("Uploading to Firebase... ");
  int httpCode = http.PUT(payload);

  if (httpCode > 0) {
    Serial.printf("OK (%d)\n", httpCode);

    // Also push to history log
    String historyUrl = String(FIREBASE_HOST) +
                        "/history/" + DEVICE_ID + ".json?auth=" + FIREBASE_AUTH;
    http.end();
    http.begin(historyUrl);
    http.addHeader("Content-Type", "application/json");
    http.POST(payload);  // POST creates a new entry with auto-generated key
  } else {
    Serial.printf("FAILED (%d): %s\n", httpCode, http.errorToString(httpCode).c_str());
  }

  http.end();
}

// ==================== Calibration ====================

void checkCalibrationCommand() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(FIREBASE_HOST) +
               "/commands/" + DEVICE_ID + "/calibrate.json?auth=" + FIREBASE_AUTH;
  http.begin(url);
  int httpCode = http.GET();

  if (httpCode == 200) {
    String response = http.getString();
    if (response == "true") {
      Serial.println("Calibration command received!");
      http.end();
      performCalibration();
      return;
    }
  }
  http.end();
}

void updateCalibrationStatus(const char* status, float r0_135, float r0_3, float r0_9) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(FIREBASE_HOST) +
               "/calibration/" + DEVICE_ID + ".json?auth=" + FIREBASE_AUTH;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  JsonDocument doc;
  doc["status"] = status;
  doc["mq135_r0"] = round(r0_135 * 100.0) / 100.0;
  doc["mq3_r0"]   = round(r0_3 * 100.0) / 100.0;
  doc["mq9_r0"]   = round(r0_9 * 100.0) / 100.0;
  doc["timestamp"] = (unsigned long)time(nullptr);

  // Include calculated thresholds so the app can use them
  doc["mq135_warning"] = round(thresh_mq135_warning * 100.0) / 100.0;
  doc["mq135_spoiled"] = round(thresh_mq135_spoiled * 100.0) / 100.0;
  doc["mq3_warning"]   = round(thresh_mq3_warning * 100.0) / 100.0;
  doc["mq3_spoiled"]   = round(thresh_mq3_spoiled * 100.0) / 100.0;
  doc["mq9_warning"]   = round(thresh_mq9_warning * 100.0) / 100.0;
  doc["mq9_spoiled"]   = round(thresh_mq9_spoiled * 100.0) / 100.0;

  String payload;
  serializeJson(doc, payload);
  http.PUT(payload);
  http.end();
}

void deleteCalibrationCommand() {
  HTTPClient http;
  String url = String(FIREBASE_HOST) +
               "/commands/" + DEVICE_ID + "/calibrate.json?auth=" + FIREBASE_AUTH;
  http.begin(url);
  http.sendRequest("DELETE");
  http.end();
}

void performCalibration() {
  calibrating = true;
  Serial.println("Starting calibration...");

  // Notify app
  updateCalibrationStatus("calibrating", 0, 0, 0);

  // Read environment for compensation
  float temp = readTemperature();
  float hum = readHumidity();
  float comp = getCompensationFactor(temp, hum);
  Serial.printf("  Environment: %.1f°C, %.1f%% RH (comp: %.3f)\n", temp, hum, comp);

  // Take many samples for a stable average
  float sum135 = 0, sum3 = 0, sum9 = 0;
  for (int i = 0; i < CALIBRATION_SAMPLES; i++) {
    sum135 += readAnalogAverage(MQ135_PIN, 10);
    sum3   += readAnalogAverage(MQ3_PIN, 10);
    sum9   += readAnalogAverage(MQ9_PIN, 10);

    if (i % 10 == 0) {
      Serial.printf("  Sample %d/%d\n", i + 1, CALIBRATION_SAMPLES);
    }
    delay(CALIBRATION_DELAY_MS);
  }

  float avg135 = sum135 / CALIBRATION_SAMPLES;
  float avg3   = sum3   / CALIBRATION_SAMPLES;
  float avg9   = sum9   / CALIBRATION_SAMPLES;

  Serial.printf("  Avg ADC: MQ135=%.0f  MQ3=%.0f  MQ9=%.0f\n", avg135, avg3, avg9);

  // Calculate Rs from voltage divider
  float v135 = (avg135 / 4095.0) * 3.3;
  float v3   = (avg3   / 4095.0) * 3.3;
  float v9   = (avg9   / 4095.0) * 3.3;

  float rs135 = (v135 > 0.01) ? ((3.3 * RL_VALUE) / v135) - RL_VALUE : RL_VALUE;
  float rs3   = (v3   > 0.01) ? ((3.3 * RL_VALUE) / v3)   - RL_VALUE : RL_VALUE;
  float rs9   = (v9   > 0.01) ? ((3.3 * RL_VALUE) / v9)   - RL_VALUE : RL_VALUE;

  // Apply temperature/humidity compensation
  rs135 /= comp;
  rs3   /= comp;
  rs9   /= comp;

  // Calculate R0 = Rs / clean_air_factor
  float new_r0_135 = rs135 / MQ135_CLEAN_AIR_FACTOR;
  float new_r0_3   = rs3   / MQ3_CLEAN_AIR_FACTOR;
  float new_r0_9   = rs9   / MQ9_CLEAN_AIR_FACTOR;

  Serial.printf("  New R0: MQ135=%.2f  MQ3=%.2f  MQ9=%.2f\n",
                new_r0_135, new_r0_3, new_r0_9);
  Serial.printf("  Old R0: MQ135=%.2f  MQ3=%.2f  MQ9=%.2f\n",
                active_mq135_r0, active_mq3_r0, active_mq9_r0);

  // Save to NVS
  prefs.putFloat("mq135_r0", new_r0_135);
  prefs.putFloat("mq3_r0", new_r0_3);
  prefs.putFloat("mq9_r0", new_r0_9);

  // Update active values
  active_mq135_r0 = new_r0_135;
  active_mq3_r0   = new_r0_3;
  active_mq9_r0   = new_r0_9;

  // Take a baseline reading with the new R0 values
  float base_raw135 = readAnalogAverage(MQ135_PIN, 10);
  float base_raw3   = readAnalogAverage(MQ3_PIN, 10);
  float base_raw9   = readAnalogAverage(MQ9_PIN, 10);
  float base_ppm135 = adcToPPM_MQ135(base_raw135, comp);
  float base_ppm3   = adcToPPM_MQ3(base_raw3, comp);
  float base_ppm9   = adcToPPM_MQ9(base_raw9, comp);

  Serial.printf("  Baseline ppm: MQ135=%.2f  MQ3=%.2f  MQ9=%.2f\n",
                base_ppm135, base_ppm3, base_ppm9);

  // Calculate thresholds as multiples of baseline (with minimum floors)
  thresh_mq135_warning = max(MQ135_MIN_WARNING, base_ppm135 * WARNING_MULTIPLIER);
  thresh_mq135_spoiled = max(thresh_mq135_warning * 2.0f, base_ppm135 * SPOILED_MULTIPLIER);
  thresh_mq3_warning   = max(MQ3_MIN_WARNING,   base_ppm3 * WARNING_MULTIPLIER);
  thresh_mq3_spoiled   = max(thresh_mq3_warning * 2.0f,   base_ppm3 * SPOILED_MULTIPLIER);
  thresh_mq9_warning   = max(MQ9_MIN_WARNING,   base_ppm9 * WARNING_MULTIPLIER);
  thresh_mq9_spoiled   = max(thresh_mq9_warning * 2.0f,   base_ppm9 * SPOILED_MULTIPLIER);

  Serial.printf("  New thresholds: MQ135=%.2f/%.2f  MQ3=%.2f/%.2f  MQ9=%.2f/%.2f\n",
                thresh_mq135_warning, thresh_mq135_spoiled,
                thresh_mq3_warning, thresh_mq3_spoiled,
                thresh_mq9_warning, thresh_mq9_spoiled);

  // Save thresholds to NVS
  prefs.putFloat("t135w", thresh_mq135_warning);
  prefs.putFloat("t135s", thresh_mq135_spoiled);
  prefs.putFloat("t3w",   thresh_mq3_warning);
  prefs.putFloat("t3s",   thresh_mq3_spoiled);
  prefs.putFloat("t9w",   thresh_mq9_warning);
  prefs.putFloat("t9s",   thresh_mq9_spoiled);

  // Reset trend history since baseline changed
  history_count = 0;
  history_index = 0;

  // Report to Firebase (including thresholds)
  updateCalibrationStatus("done", new_r0_135, new_r0_3, new_r0_9);

  // Delete the command so it doesn't re-trigger
  deleteCalibrationCommand();

  Serial.println("Calibration complete!");
  calibrating = false;
}

// ==================== Serial Output ====================

void printReading(SensorReading r) {
  Serial.println("--- Sensor Reading ---");
  Serial.printf("  MQ-135 (NH3/CO2): %.1f ppm  (trend: %+.2f)\n",
                r.mq135_ppm, getTrend(mq135_history, history_count));
  Serial.printf("  MQ-3   (EtOH):    %.1f ppm  (trend: %+.2f)\n",
                r.mq3_ppm, getTrend(mq3_history, history_count));
  Serial.printf("  MQ-9   (CH4/CO):  %.1f ppm  (trend: %+.2f)\n",
                r.mq9_ppm, getTrend(mq9_history, history_count));
  if (bme_ok) {
    Serial.printf("  Temp: %.1f C   Humidity: %.1f %%\n",
                  r.temperature, r.humidity);
  }
  Serial.printf("  Battery: %.0f%%\n", r.battery_pct);
  Serial.printf("  Freshness: %s\n", freshnessToString(r.freshness));
  Serial.printf("  Timestamp: %lu\n", r.timestamp);
  Serial.println();
}
