/*
 * I2C Scanner — finds all devices on the I2C bus
 * Tests multiple pin combinations for BME280
 */

#include <Wire.h>

void scanBus(int sda, int scl) {
  Serial.printf("\nScanning I2C on SDA=GPIO%d, SCL=GPIO%d ...\n", sda, scl);
  Wire.begin(sda, scl);
  delay(100);

  int found = 0;
  for (byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    byte error = Wire.endTransmission();
    if (error == 0) {
      Serial.printf("  FOUND device at address 0x%02X", addr);
      if (addr == 0x76 || addr == 0x77) Serial.print(" <- BME280!");
      Serial.println();
      found++;
    }
  }

  if (found == 0) {
    Serial.println("  No devices found on these pins.");
  }
  Wire.end();
}

void setup() {
  Serial.begin(115200);
  delay(2000);

  Serial.println("==========================================");
  Serial.println("  I2C Bus Scanner");
  Serial.println("==========================================");

  // Try the expected pins first
  scanBus(8, 9);

  // Try swapped
  scanBus(9, 8);

  // Try other common ESP32-S3 I2C pins
  scanBus(13, 14);
  scanBus(17, 18);
  scanBus(47, 48);

  Serial.println("\n==========================================");
  Serial.println("  Scan complete.");
  Serial.println("  If BME280 was not found on any pins,");
  Serial.println("  check VIN is connected to 3.3V and");
  Serial.println("  GND is connected to GND.");
  Serial.println("==========================================");
}

void loop() {
}
