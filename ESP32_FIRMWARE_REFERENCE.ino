// ESP32 Climate Monitor - BLE & WiFi Configuration
// This is a reference implementation for the Flutter app
// Adjust sensor pins and WiFi settings as needed

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <EEPROM.h>
#include <DHT.h>

// ===== PIN DEFINITIONS =====
#define DHTPIN 4
#define DHTTYPE DHT22
#define LED_PIN 5
#define BATTERY_PIN 34

DHT dht(DHTPIN, DHTTYPE);

// ===== BLE DEFINITIONS =====
#define SERVICE_UUID "180A"  // Device Information Service
#define NOTIFY_CHAR_UUID "2A19"  // Battery Level characteristic (reuse for climate data)
#define WRITE_CHAR_UUID "2A29"  // Manufacturer Name String characteristic (reuse for commands)

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
BLECharacteristic* pWriteCharacteristic = NULL;

// ===== CONFIGURATION EEPROM STRUCTURE =====
struct {
  char ssid[32];
  char password[64];
  float maxTemp = 35.0;
  float minTemp = 5.0;
  float maxHumidity = 80.0;
  float minHumidity = 20.0;
} settings;

// ===== GLOBAL VARIABLES =====
float currentTemp = 0;
float currentHumidity = 0;
bool deviceConnected = false;
bool wifiConnected = false;
unsigned long lastBLEDataTime = 0;

// ===== SENSOR DATA FUNCTIONS =====
void readSensorData() {
  currentTemp = dht.readTemperature();
  currentHumidity = dht.readHumidity();
  
  if (isnan(currentTemp) || isnan(currentHumidity)) {
    Serial.println("Failed to read from DHT sensor!");
    currentTemp = 0;
    currentHumidity = 0;
  }
}

void sendClimateData() {
  if (!deviceConnected) return;
  
  String data = "CLIMATE:" + String(currentTemp, 1) + "," + String(currentHumidity, 1);
  pCharacteristic->setValue(data.c_str());
  pCharacteristic->notify();
  
  Serial.println("Sent: " + data);
}

void sendDeviceInfo() {
  if (!deviceConnected) return;
  
  String mac = WiFi.macAddress();
  String info = "INFO:ESP32-DHT22,v1.0," + mac;
  pCharacteristic->setValue(info.c_str());
  pCharacteristic->notify();
  
  Serial.println("Sent: " + info);
}

// ===== EEPROM FUNCTIONS =====
void loadSettings() {
  EEPROM.begin(512);
  EEPROM.readBytes(0, (uint8_t*) &settings, sizeof(settings));
  
  Serial.println("Loaded Settings:");
  Serial.print("  SSID: ");
  Serial.println(settings.ssid);
  Serial.print("  Max Temp: ");
  Serial.println(settings.maxTemp);
}

void saveSettings() {
  EEPROM.begin(512);
  EEPROM.writeBytes(0, (uint8_t*) &settings, sizeof(settings));
  EEPROM.commit();
  
  Serial.println("Settings saved to EEPROM");
}

// ===== BLE CALLBACKS =====
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    digitalWrite(LED_PIN, HIGH);  // LED on when connected
    Serial.println("BLE Client Connected");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    digitalWrite(LED_PIN, LOW);   // LED off when disconnected
    Serial.println("BLE Client Disconnected");
    
    // Restart advertising
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->start();
  }
};

class WriteCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    
    if (value.length() == 0) return;
    
    String command = String(value.c_str());
    command.trim();
    
    Serial.print("Received: ");
    Serial.println(command);
    
    // ===== PARSE COMMANDS =====
    
    // WiFi Configuration: WIFI:SSID,PASSWORD
    if (command.startsWith("WIFI:")) {
      String wifiData = command.substring(5);
      int commaIndex = wifiData.indexOf(',');
      
      if (commaIndex > 0) {
        String ssid = wifiData.substring(0, commaIndex);
        String password = wifiData.substring(commaIndex + 1);
        
        // Store in settings
        ssid.toCharArray(settings.ssid, sizeof(settings.ssid));
        password.toCharArray(settings.password, sizeof(settings.password));
        
        saveSettings();
        
        // Send confirmation
        String response = "WIFI_OK:" + ssid;
        pCharacteristic->setValue(response.c_str());
        pCharacteristic->notify();
        delay(100);
        
        // Try to connect to WiFi
        connectToWiFi();
      }
    }
    
    // Thresholds: THRESHOLDS:MAX_TEMP,MIN_TEMP,MAX_HUMID,MIN_HUMID
    else if (command.startsWith("THRESHOLDS:")) {
      String data = command.substring(11);
      // Parse comma-separated values
      int index = 0;
      int count = 0;
      float values[4] = {35.0, 5.0, 80.0, 20.0};
      
      String temp = "";
      for (int i = 0; i < data.length(); i++) {
        if (data[i] == ',') {
          values[count] = temp.toFloat();
          temp = "";
          count++;
        } else {
          temp += data[i];
        }
      }
      if (temp.length() > 0) {
        values[count] = temp.toFloat();
      }
      
      settings.maxTemp = values[0];
      settings.minTemp = values[1];
      settings.maxHumidity = values[2];
      settings.minHumidity = values[3];
      
      saveSettings();
      
      pCharacteristic->setValue("THRESHOLDS_OK");
      pCharacteristic->notify();
    }
    
    // Device Info Request: INFO
    else if (command == "INFO") {
      sendDeviceInfo();
    }
    
    // Calibration: CALIBRATE:OFFSET_TEMP,OFFSET_HUMIDITY
    else if (command.startsWith("CALIBRATE:")) {
      String data = command.substring(10);
      int commaIndex = data.indexOf(',');
      
      if (commaIndex > 0) {
        String tempOffset = data.substring(0, commaIndex);
        String humidityOffset = data.substring(commaIndex + 1);
        
        // Apply offsets if needed
        // currentTemp += tempOffset.toFloat();
        // currentHumidity += humidityOffset.toFloat();
        
        pCharacteristic->setValue("CALIBRATE_OK");
        pCharacteristic->notify();
      }
    }
    
    // Request climate data: UPDATE
    else if (command == "UPDATE") {
      readSensorData();
      sendClimateData();
    }
    
    else {
      Serial.println("Unknown command");
    }
  }
};

// ===== WIFI FUNCTIONS =====
void connectToWiFi() {
  if (strlen(settings.ssid) == 0) {
    Serial.println("No WiFi credentials configured");
    return;
  }
  
  Serial.print("Connecting to WiFi: ");
  Serial.println(settings.ssid);
  
  WiFi.begin(settings.ssid, settings.password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    digitalWrite(LED_PIN, HIGH);
    Serial.println("\nWiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    wifiConnected = false;
    Serial.println("\nFailed to connect to WiFi");
  }
}

// ===== BLE SETUP =====
void setupBLE() {
  BLEDevice::init("ESP32-Climate");
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  BLEService* pService = pServer->createService(SERVICE_UUID);
  
  // Notify characteristic for sending data
  pCharacteristic = pService->createCharacteristic(
    NOTIFY_CHAR_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  
  // Write characteristic for receiving commands
  pWriteCharacteristic = pService->createCharacteristic(
    WRITE_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pWriteCharacteristic->setCallbacks(new WriteCallbacks());
  
  pService->start();
  
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("BLE Server started");
}

// ===== SETUP =====
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== ESP32 Climate Monitor ===\n");
  
  // Setup pins
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Initialize WiFi
  WiFi.mode(WIFI_STA);
  
  // Initialize sensor
  dht.begin();
  delay(2000);
  
  // Load settings from EEPROM
  loadSettings();
  
  // Setup BLE
  setupBLE();
  
  // Try to connect to saved WiFi
  connectToWiFi();
}

// ===== MAIN LOOP =====
void loop() {
  // Read sensor data every 5 seconds
  if (millis() - lastBLEDataTime > 5000) {
    readSensorData();
    sendClimateData();
    lastBLEDataTime = millis();
  }
  
  // Check WiFi connection
  if (wifiConnected && WiFi.status() != WL_CONNECTED) {
    wifiConnected = false;
    digitalWrite(LED_PIN, LOW);
    Serial.println("WiFi disconnected");
  }
  
  delay(100);
}
