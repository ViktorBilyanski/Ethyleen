/*
 * Ethyleen — Hardware Test Sketch
 * Tests all sensors and battery WITHOUT WiFi/Firebase.
 * Upload this first to verify your wiring is correct.
 */

#include <Wire.h>
#include <Adafruit_BME280.h>

// ==================== Pin Definitions ====================
// Must match your physical wiring

#define MQ135_PIN  1   // GPIO1 — MQ-135 AO pin
#define MQ3_PIN    2   // GPIO2 — MQ-3 AO pin
#define MQ9_PIN    4   // GPIO4 — MQ-9 AO pin

#define BME280_SDA 8   // UEXT pin 6
#define BME280_SCL 9   // UEXT pin 5

#define BAT_SENSE_PIN 3  // GPIO3 — battery voltage divider

// ==================== BME280 ====================

Adafruit_BME280 bme;
bool bme_ok = false;

// ==================== Setup ====================

void setup() {
  Serial.begin(115200);
  delay(2000);  // Wait for Serial Monitor to open

  Serial.println();
  Serial.println("==========================================");
  Serial.println("  Ethyleen Hardware Test");
  Serial.println("  Testing: MQ-135, MQ-3, MQ-9, BME280, Battery");
  Serial.println("==========================================");
  Serial.println();

  // Configure ADC
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  // Test BME280 on UEXT I2C
  Serial.println("[TEST 1] BME280 on UEXT port...");
  Wire.begin(BME280_SDA, BME280_SCL);
  if (bme.begin(0x76, &Wire)) {
    bme_ok = true;
    Serial.println("  PASS — BME280 found at address 0x76");
  } else if (bme.begin(0x77, &Wire)) {
    bme_ok = true;
    Serial.println("  PASS — BME280 found at address 0x77");
  } else {
    Serial.println("  FAIL — BME280 not detected!");
    Serial.println("         Check: is CABLE-UEXT-JWF plugged in firmly?");
    Serial.println("         Check: is MOD-BME280 connected to the other end?");
  }

  // Test ADC pins (check if sensors are providing voltage)
  Serial.println();
  Serial.println("[TEST 2] MQ sensor ADC pins...");

  int raw135 = analogRead(MQ135_PIN);
  int raw3   = analogRead(MQ3_PIN);
  int raw9   = analogRead(MQ9_PIN);

  Serial.printf("  MQ-135 (GPIO%d): raw=%d  voltage=%.2fV", MQ135_PIN, raw135, raw135 / 4095.0 * 3.3);
  if (raw135 < 10) Serial.println("  <- SUSPICIOUS: too low, check wiring");
  else if (raw135 > 4080) Serial.println("  <- SUSPICIOUS: maxed out, check wiring");
  else Serial.println("  OK");

  Serial.printf("  MQ-3   (GPIO%d): raw=%d  voltage=%.2fV", MQ3_PIN, raw3, raw3 / 4095.0 * 3.3);
  if (raw3 < 10) Serial.println("  <- SUSPICIOUS: too low, check wiring");
  else if (raw3 > 4080) Serial.println("  <- SUSPICIOUS: maxed out, check wiring");
  else Serial.println("  OK");

  Serial.printf("  MQ-9   (GPIO%d): raw=%d  voltage=%.2fV", MQ9_PIN, raw9, raw9 / 4095.0 * 3.3);
  if (raw9 < 10) Serial.println("  <- SUSPICIOUS: too low, check wiring");
  else if (raw9 > 4080) Serial.println("  <- SUSPICIOUS: maxed out, check wiring");
  else Serial.println("  OK");

  Serial.println();
  Serial.println("  NOTE: MQ sensors need 1-2 minutes to warm up.");
  Serial.println("        Values will be unstable at first — that's normal.");
  Serial.println("        If a sensor reads 0 or 4095 after warmup, the wiring is wrong.");

  // Test battery sense
  Serial.println();
  Serial.println("[TEST 3] Battery voltage...");
  int rawBat = analogRead(BAT_SENSE_PIN);
  float batVoltage = (rawBat / 4095.0) * 3.3 * 2.0;  // *2 for voltage divider
  Serial.printf("  GPIO%d: raw=%d  estimated voltage=%.2fV\n", BAT_SENSE_PIN, rawBat, batVoltage);
  if (batVoltage > 3.0 && batVoltage < 4.3) {
    float pct = (batVoltage - 3.3) / (4.2 - 3.3) * 100.0;
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    Serial.printf("  PASS — Battery at ~%.0f%% (%.2fV)\n", pct, batVoltage);
  } else if (rawBat < 10) {
    Serial.println("  NOTE — No battery detected (running on USB power only?)");
  } else {
    Serial.printf("  WARNING — Unexpected voltage: %.2fV\n", batVoltage);
  }

  Serial.println();
  Serial.println("==========================================");
  Serial.println("  Setup tests complete.");
  Serial.println("  Starting continuous readings below...");
  Serial.println("  (every 3 seconds for quick feedback)");
  Serial.println("==========================================");
  Serial.println();

  // Short warmup
  Serial.println("Warming up MQ sensors (60 seconds)...");
  Serial.println("You can already watch the values change below.");
  Serial.println();
}

// ==================== Main Loop ====================

unsigned long last_print = 0;
int reading_num = 0;

void loop() {
  if (millis() - last_print < 3000) return;  // Print every 3 seconds
  last_print = millis();
  reading_num++;

  // Read MQ sensors (average 10 samples)
  float raw135 = 0, raw3 = 0, raw9 = 0;
  for (int i = 0; i < 10; i++) {
    raw135 += analogRead(MQ135_PIN);
    raw3   += analogRead(MQ3_PIN);
    raw9   += analogRead(MQ9_PIN);
    delay(5);
  }
  raw135 /= 10.0;
  raw3   /= 10.0;
  raw9   /= 10.0;

  // Read BME280
  float temp = -99, hum = -1;
  if (bme_ok) {
    bme.takeForcedMeasurement();
    temp = bme.readTemperature();
    hum  = bme.readHumidity();
  }

  // Read battery
  float batRaw = analogRead(BAT_SENSE_PIN);
  float batV = (batRaw / 4095.0) * 3.3 * 2.0;

  // Print
  Serial.printf("#%d  |  ", reading_num);
  Serial.printf("MQ135: %4.0f  MQ3: %4.0f  MQ9: %4.0f  |  ", raw135, raw3, raw9);

  if (bme_ok) {
    Serial.printf("Temp: %.1fC  Hum: %.0f%%  |  ", temp, hum);
  } else {
    Serial.printf("BME280: N/A  |  ");
  }

  Serial.printf("Bat: %.2fV", batV);

  if (reading_num <= 20) {
    Serial.printf("  (warmup: %ds left)", 60 - reading_num * 3);
  }

  Serial.println();
}
