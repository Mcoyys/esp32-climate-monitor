# 🌡️ ESP32 Climate Monitor - Advanced Features Implementation

## 📋 Project Overview

A comprehensive Flutter application for monitoring room temperature and humidity via Bluetooth Low Energy (BLE) connection with an ESP32 device. Now featuring WiFi configuration, intelligent notifications, historical data tracking, and customizable threshold alerts.

## ✨ New Features Implemented

### 1. **🔌 WiFi Configuration via Bluetooth**
- Configure WiFi credentials securely via BLE
- One-time setup process to enable remote monitoring
- Device stores WiFi credentials in EEPROM
- Real-time feedback on configuration status
- **File:** `lib/screens/wifi_config_screen.dart`

**BLE Protocol:**
```
Command Format: "WIFI:SSID,PASSWORD"
Example: "WIFI:MyNetwork,MyPassword123"
Response: "WIFI_OK:SSID" or "WIFI_ERROR:REASON"
```

### 2. **🔔 Smart Notifications System**
- Local notifications for temperature/humidity alerts
- Push notifications support via Firebase (configured)
- Customizable alert types:
  - High Temperature (turn on AC)
  - Low Temperature (check heating)
  - High Humidity (ventilation warning)
  - Low Humidity (dry air warning)
  - Device disconnection alerts
  - WiFi configuration success
- **File:** `lib/services/notification_service.dart`

### 3. **📊 Historical Data & Analytics**
- SQLite database for persistent storage
- Stores climate readings with timestamps
- Tracks alert history
- 7-day data retention by default (configurable)
- Query data by device, time range, or alert type
- **File:** `lib/database/database_service.dart`

### 4. **⚙️ Customizable Device Settings**
- Adjustable temperature thresholds (min/max)
- Adjustable humidity thresholds (min/max)
- Device naming for multi-device setups
- Enable/disable notifications per device
- Settings persist across app sessions
- Settings sync to ESP32 device
- **File:** `lib/screens/settings_screen.dart`

### 5. **📱 Advanced State Management**
- Provider package for efficient state management
- Real-time data updates across UI
- Automatic provider initialization
- Clean separation of concerns
- **File:** `lib/services/climate_data_provider.dart`

## 📁 Project Architecture

```
lib/
├── main.dart                          # Entry point with Provider setup
├── models/
│   ├── climate_reading.dart          # Temperature/humidity data model
│   ├── device_settings.dart          # Device configuration model
│   └── alert_event.dart              # Alert event model
├── services/
│   ├── ble_service.dart              # Bluetooth LE communication
│   ├── notification_service.dart     # Local/push notifications
│   └── climate_data_provider.dart    # State management & data processing
├── screens/
│   ├── scanner_screen.dart           # Device discovery UI
│   ├── device_screen_new.dart        # Main monitoring dashboard
│   ├── wifi_config_screen.dart       # WiFi setup UI
│   └── settings_screen.dart          # Threshold customization UI
├── database/
│   └── database_service.dart         # SQLite operations
├── widgets/                          # Reusable UI components (future)
└── utils/                            # Helper functions (future)
```

## 🔌 BLE Communication Protocol

The app communicates with ESP32 using UTF-8 encoded text messages:

### Commands (App → Device)

| Command | Format | Example |
|---------|--------|---------|
| WiFi Config | `WIFI:SSID,PASSWORD` | `WIFI:HomeNetwork,Pass123` |
| Set Thresholds | `THRESHOLDS:MAX_T,MIN_T,MAX_H,MIN_H` | `THRESHOLDS:35.0,5.0,80.0,20.0` |
| Calibration | `CALIBRATE:TEMP,HUMIDITY` | `CALIBRATE:25.0,50.0` |
| Request Info | `INFO` | `INFO` |

### Responses (Device → App)

| Response | Format | Example |
|----------|--------|---------|
| Climate Data | `CLIMATE:TEMP,HUMIDITY` | `CLIMATE:28.5,65.2` |
| Device Info | `INFO:MODEL,FW_VERSION,MAC` | `INFO:ESP32,v1.0,AA:BB:CC:DD:EE:FF` |
| WiFi Success | `WIFI_OK:SSID` | `WIFI_OK:HomeNetwork` |
| WiFi Error | `WIFI_ERROR:REASON` | `WIFI_ERROR:TIMEOUT` |

## 📦 New Dependencies

```yaml
# State Management
provider: ^6.0.0

# Notifications
firebase_core: ^2.24.0
firebase_messaging: ^14.6.0
flutter_local_notifications: ^17.1.0

# Database
sqflite: ^2.3.0
path: ^1.8.3

# Charts (for future analytics)
fl_chart: ^0.65.0

# UI Utilities
fluttertoast: ^8.2.4
intl: ^0.19.0
uuid: ^4.0.0
```

## 🚀 Installation & Setup

### 1. **Install Dependencies**
```bash
flutter pub get
```

### 2. **Android Configuration**
- ✅ Permissions added to AndroidManifest.xml
- Includes: Bluetooth, Location, Network, Notifications
- Android 13+ notification permission support

### 3. **iOS Configuration**
- ✅ Permissions added to Info.plist
- Includes: Bluetooth, Location descriptions
- Ready for TestFlight distribution

### 4. **Database Setup**
- Automatically created on first run
- SQLite database at: `~DatabasesPath/climate_monitor.db`
- 3 tables: climate_readings, device_settings, alert_events

### 5. **Notification Setup** (Optional for Firebase)
```bash
# Configure Firebase if using push notifications
firebase setup ios
firebase setup android
```

## 💾 Database Schema

### climate_readings
```sql
CREATE TABLE climate_readings(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  temperature REAL NOT NULL,
  humidity REAL NOT NULL,
  timestamp TEXT NOT NULL,
  deviceId TEXT NOT NULL
)
```

### device_settings
```sql
CREATE TABLE device_settings(
  deviceId TEXT PRIMARY KEY,
  deviceName TEXT NOT NULL,
  maxTempThreshold REAL,
  minTempThreshold REAL,
  maxHumidityThreshold REAL,
  minHumidityThreshold REAL,
  notificationsEnabled INTEGER,
  wifiSSID TEXT,
  isWifiConfigured INTEGER
)
```

### alert_events
```sql
CREATE TABLE alert_events(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  deviceId TEXT NOT NULL,
  type INTEGER NOT NULL,
  message TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  temperature REAL,
  humidity REAL,
  isResolved INTEGER
)
```

## 🛠️ ESP32 Firmware Requirements

Your ESP32 firmware should:

1. **Advertise BLE with a readable name**
2. **Implement GATT characteristics:**
   - **Notify characteristic** (for sending climate data)
   - **Write characteristic** (for receiving commands)

3. **Send climate data periodically** (every 2-5 seconds)
   - Format: `CLIMATE:TEMP,HUMIDITY`
   - Example: `CLIMATE:28.5,65.2`

4. **Respond to commands**
   - Parse WiFi config command and store in EEPROM
   - Store threshold values in EEPROM
   - Send acknowledgment responses

### Example ESP32 Code Snippet

```cpp
// Send climate data
void sendClimateData() {
  String data = "CLIMATE:" + String(temperature, 1) + "," + String(humidity, 1);
  pCharacteristic->setValue(data.c_str());
  pCharacteristic->notify();
}

// Receive WiFi config
void onWrite(BLEServer* pServer, BLEServerCallbacks* pCallbacks) {
  std::string value = pCharacteristic->getValue();
  if (value.substr(0, 5) == "WIFI:") {
    // Parse SSID and password
    // Connect to WiFi
    // Send: "WIFI_OK:SSID"
  }
}
```

## 📱 User Flow

### First Time Setup
1. **Launch App** → BLE Scanner
2. **Scan & Connect** to ESP32 device
3. **Configure WiFi** (optional but recommended)
   - Enter network SSID and password
   - Device stores credentials
4. **Adjust Thresholds** in Settings
5. **Start Monitoring** - receive real-time alerts

### Regular Usage
- Monitor temperature/humidity on dashboard
- View active alerts and historical data
- Receive notifications on threshold violations
- Adjust device settings as needed
- Historical data persists for 7 days

## 🎯 Recommended ESP32 Features

For optimal experience, your ESP32 should support:

1. **Battery Monitoring**
   - Send battery level via BLE
   - Command: `BATTERY_LEVEL:85` (percentage)

2. **Device Information**
   - Model, firmware version, MAC address
   - Command response to `INFO` query

3. **Calibration Support**
   - Accept calibration values via BLE
   - Command: `CALIBRATE:25.0,50.0`

4. **Connected LED Indicator**
   - LED on when WiFi connected
   - Blink pattern for device status

5. **EEPROM Storage**
   - Persist WiFi credentials
   - Persist threshold settings
   - Retain data across power cycles

6. **Error Reporting**
   - Send error messages via BLE
   - Help with troubleshooting

## 🔒 Security Considerations

1. **Bluetooth Security**
   - Add pairing/bonding for production
   - Implement BLE encryption if sensitive data

2. **WiFi Storage**
   - Currently stored in plaintext on device
   - For production: implement encryption

3. **Notification Permissions**
   - App requests permissions at startup
   - User must grant for alerts to work

4. **Data Privacy**
   - Data stored locally on device
   - No cloud sync by default
   - User controls data retention

## 🐛 Troubleshooting

### App won't connect to device
- Ensure Bluetooth is enabled
- Grant location permission (required for BLE scan on Android)
- Try restarting both app and device

### Notifications not working
- Ensure POST_NOTIFICATIONS permission is granted
- Check notification settings in device settings
- Disable and re-enable notifications

### Settings not syncing to device
- Ensure device is still connected (blue indicator)
- Try disconnecting and reconnecting
- Check device logs for BLE write errors

### Database errors
- Clear app data: `adb shell pm clear com.example.esp32_climate_app`
- Database will recreate on next launch

## 📈 Future Enhancements

- [ ] Charts/graphs for historical data visualization
- [ ] Firebase Cloud integration for cloud backup
- [ ] Multiple device management dashboard
- [ ] Over-the-air (OTA) firmware updates
- [ ] Advanced analytics (trends, averages, etc.)
- [ ] Voice assistant integration
- [ ] Export data to CSV/PDF
- [ ] Smart scheduling and automation

## 📚 Files Reference

| File | Purpose |
|------|---------|
| `main.dart` | App entry point, Provider setup |
| `ble_service.dart` | Bluetooth communication |
| `database_service.dart` | SQLite operations |
| `notification_service.dart` | Local notifications |
| `climate_data_provider.dart` | State management |
| `device_screen_new.dart` | Main UI dashboard |
| `wifi_config_screen.dart` | WiFi setup UI |
| `settings_screen.dart` | Settings UI |
| `climate_reading.dart` | Data model |
| `device_settings.dart` | Config model |
| `alert_event.dart` | Alert model |

## 🤝 Support & Feedback

For issues or feature requests:
1. Check troubleshooting section
2. Review ESP32 firmware implementation
3. Check BLE communication logs

---

**App Version:** 1.0.0  
**Last Updated:** April 2026  
**Developed with Flutter** 🚀
