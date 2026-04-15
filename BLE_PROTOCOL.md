# BLE Protocol Documentation

## Overview

The ESP32 Climate Monitor uses Bluetooth Low Energy (BLE) for device communication. All commands and responses use UTF-8 encoded text transmitted over BLE characteristics.

## Connection Setup

### BLE Advertising
- **Device Name:** `ESP32-Climate`
- **Service UUID:** `180A` (Device Information Service)
- **Notify Characteristic:** `2A19` (Battery Level - repurposed for climate data)
- **Write Characteristic:** `2A29` (Manufacturer Name String - repurposed for commands)

### Device Discovery Flow
```
1. Scan for BLE devices
2. Filter by name containing "Climate" or "ESP32"
3. Connect to selected device
4. Discover characteristics
5. Enable notifications on notification characteristic
6. Ready to send commands and receive data
```

## Command Protocol

### General Format
- **Delimiter:** `:` (colon)
- **Sub-delimiter:** `,` (comma) for multiple values
- **Encoding:** UTF-8
- **Termination:** None required (handled by BLE packet boundaries)
- **Response Time:** < 500ms typical

### Command Categories

## 1. Climate Data Transmission

### Climate Data (Device → App)
**Sent automatically every 5 seconds**

```
Format: CLIMATE:TEMP,HUMIDITY
Example: CLIMATE:28.5,65.2
```

| Field | Type | Range | Unit |
|-------|------|-------|------|
| TEMP | Float | -40 to 85°C | °C |
| HUMIDITY | Float | 0 to 100 | % |

**Flutter Code:**
```dart
Map<String, double>? data = BLEService.parseClimateData("CLIMATE:28.5,65.2");
// Returns: {'temperature': 28.5, 'humidity': 65.2}
```

---

## 2. WiFi Configuration

### Send WiFi Credentials (App → Device)

```
Format: WIFI:SSID,PASSWORD
Example: WIFI:MyHomeNetwork,SecurePass123!
Maximum lengths: SSID=32 chars, Password=64 chars
```

**Device Actions:**
1. Parse SSID and password
2. Store in EEPROM
3. Attempt WiFi connection
4. Send response

### WiFi Success Response (Device → App)

```
Format: WIFI_OK:SSID
Example: WIFI_OK:MyHomeNetwork
```

### WiFi Error Response (Device → App)

```
Format: WIFI_ERROR:REASON
Example: WIFI_ERROR:TIMEOUT
```

**Common Error Reasons:**
- `TIMEOUT` - WiFi not found
- `WRONG_PASS` - Incorrect password
- `CONNECT_FAILED` - Other connection issue
- `INVALID_PARAMS` - Bad SSID/password format

**Flutter Code:**
```dart
// Send WiFi config
await bleService.sendWiFiConfig("MyNetwork", "MyPassword");

// Parse response
Map<String, String>? response = BLEService.parseWiFiResponse("WIFI_OK:MyNetwork");
// Returns: {'status': 'ok', 'ssid': 'MyNetwork'}
```

---

## 3. Threshold Configuration

### Set Thresholds (App → Device)

```
Format: THRESHOLDS:MAX_TEMP,MIN_TEMP,MAX_HUMIDITY,MIN_HUMIDITY
Example: THRESHOLDS:35.0,5.0,80.0,20.0
```

| Parameter | Type | Range | Unit |
|-----------|------|-------|------|
| MAX_TEMP | Float | 0-50 | °C |
| MIN_TEMP | Float | -40-25 | °C |
| MAX_HUMIDITY | Float | 60-100 | % |
| MIN_HUMIDITY | Float | 0-40 | % |

**Validation on Device:**
- MAX_TEMP > MIN_TEMP
- MAX_HUMIDITY > MIN_HUMIDITY
- Values within specified ranges

### Threshold Acknowledgement (Device → App)

```
Format: THRESHOLDS_OK
```

**Device Actions:**
1. Validate parameters
2. Store in EEPROM
3. Apply thresholds (use for future alerts)
4. Send confirmation

**Flutter Code:**
```dart
await bleService.sendThresholds(
  maxTemp: 35.0,
  minTemp: 5.0,
  maxHumidity: 80.0,
  minHumidity: 20.0,
);
```

---

## 4. Device Information

### Request Device Info (App → Device)

```
Format: INFO
```

### Device Info Response (Device → App)

```
Format: INFO:MODEL,FIRMWARE_VERSION,MAC_ADDRESS
Example: INFO:ESP32-DHT22,v1.0.0,AA:BB:CC:DD:EE:FF
```

| Field | Description |
|-------|-------------|
| MODEL | Device model identifier |
| FIRMWARE_VERSION | Current firmware version |
| MAC_ADDRESS | Device MAC address (BLE) |

**Flutter Code:**
```dart
await bleService.requestDeviceInfo();

// Parse response
Map<String, String>? info = BLEService.parseDeviceInfo(
  "INFO:ESP32-DHT22,v1.0,AA:BB:CC:DD:EE:FF"
);
// Returns: {
//   'model': 'ESP32-DHT22',
//   'firmware': 'v1.0',
//   'mac': 'AA:BB:CC:DD:EE:FF'
// }
```

---

## 5. Calibration

### Send Calibration Data (App → Device)

```
Format: CALIBRATE:TEMP_OFFSET,HUMIDITY_OFFSET
Example: CALIBRATE:0.5,-2.0
```

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| TEMP_OFFSET | Float | -5 to +5 | Temperature adjustment in °C |
| HUMIDITY_OFFSET | Float | -20 to +20 | Humidity adjustment in % |

**Device Actions:**
1. Store calibration offsets in EEPROM
2. Apply offsets to future sensor readings
3. Send confirmation

### Calibration Acknowledgement (Device → App)

```
Format: CALIBRATE_OK
or CALIBRATE_ERROR:REASON
```

**Flutter Code:**
```dart
await bleService.sendCalibration(0.5, -2.0);
```

---

## 6. Data Request

### Request Current Reading (App → Device)

```
Format: UPDATE
```

### Immediate Climate Response (Device → App)

```
Format: CLIMATE:TEMP,HUMIDITY
Example: CLIMATE:28.5,65.2
Sent immediately (not waiting for 5-second interval)
```

**Flutter Code:**
```dart
await bleService.sendCommand("UPDATE");
```

---

## Error Handling

### Response Timeout
**Default:** 5 seconds

**App Behavior:**
- Display "Connection timeout" message
- Allow retry
- Suggest reconnection if multiple timeouts

### Connection Lost
**App Behavior:**
1. Detect disconnection
2. Show reconnection prompt
3. Offer to rescan devices
4. Save last known device for quick reconnect

### Invalid Format
**Device Behavior:**
- Ignore malformed commands
- Log error if debugging enabled
- Stay connected

**App Behavior:**
- Validate input before sending
- Handle unexpected responses gracefully

---

## State Diagram

```
Connected ────────────────────────────────────────► Disconnected
   ▲                                                      ▲
   │                                                      │
   └──► [Send Command]                                   │
        [Wait for Response]                              │
        [Handle Response]                                │
        [Continue]                                       │
               │                                         │
               └─────────────────────────────────────────┘
```

---

## Timing Specifications

### Climate Data
- **Frequency:** Every 5 seconds (default)
- **Jitter:** ±500ms acceptable
- **Latency:** < 100ms expected

### Commands
- **Send:** Immediate
- **Device Processing:** < 100ms
- **Response Time:** < 500ms
- **Max Retries:** 3

### Connection
- **Advertising Duration:** Continuous
- **Connection Timeout:** 30 seconds
- **Reconnect Wait:** Exponential backoff (1s → 30s)

---

## EEPROM Storage

### Storage Offsets (ESP32)

| Offset | Size | Data |
|--------|------|------|
| 0 | 32 | WiFi SSID |
| 32 | 64 | WiFi Password |
| 96 | 4 | Max Temperature |
| 100 | 4 | Min Temperature |
| 104 | 4 | Max Humidity |
| 108 | 4 | Min Humidity |

### Persistence
- Settings persist across power cycles
- EEPROM updated on each configuration change
- Checksum validation recommended

---

## Example Communication Sequence

### Scenario: First-time Setup

```
App                                  ESP32
 │                                    │
 ├──────── Connect (BLE) ────────────►│
 │                                    │
 │◄───── Climate:25.0,50.0 ──────────┤
 │                                    │
 ├─────WIFI:HomeNet,Pass123─────────►│ (Store in EEPROM)
 │                                    │ (Connect to WiFi)
 │◄──── WIFI_OK:HomeNet ─────────────┤
 │                                    │
 ├─THRESHOLDS:35.0,5.0,80.0,20.0───►│ (Store in EEPROM)
 │                                    │
 │◄────── THRESHOLDS_OK ──────────────┤
 │                                    │
 ├────────── INFO ───────────────────►│
 │                                    │
 │◄─ INFO:ESP32,v1.0,AA:BB:CC:DD:EE:FF
 │                                    │
 └─ [Status: Connected & Configured] ┘
```

### Scenario: Receiving Alert

```
Periodic Updates:
ESP32 ──► CLIMATE:28.5,65.2  (Normal)
ESP32 ──► CLIMATE:29.0,66.0  (Normal)
ESP32 ──► CLIMATE:35.2,67.0  (⚠️ Exceeds threshold!)

App Receives:
1. Parse temperature = 35.2°C
2. Compare with maxTemp = 35.0°C
3. Trigger alert (High Temperature)
4. Show notification: "Turn on AC!"
5. Store in database
6. Update UI with alert
```

---

## Testing Commands

### BLE Terminal Testing

Use a BLE terminal app to test:

```
# Test climate data format
CLIMATE:25.5,60.0

# Test WiFi config
WIFI:TestSSID,TestPassword

# Test threshold config
THRESHOLDS:35.0,5.0,80.0,20.0

# Test info request
INFO

# Test calibration
CALIBRATE:0.0,0.0
```

---

## Troubleshooting

### Device not responding

**Check:**
1. Device is powered on
2. BLE is advertising
3. Connection is active (green indicator)
4. Command format is correct (no spaces)

**Solution:**
```dart
// Verify connection
if (!bleService.isConnected) {
  // Reconnect
  await bleService.connectToDevice(device);
}
```

### Commands timing out

**Likely causes:**
1. Device is processing long operation
2. Connection is unstable
3. Device crashed/needs reset

**Solution:**
- Increase timeout (in BLEService)
- Implement retry logic
- Add exponential backoff

### Incomplete data reception

**Check:**
1. Data packets aren't being fragmented
2. MTU size is sufficient (default 23 bytes → recommended 247+ bytes)
3. No command collisions

---

## Best Practices

1. **Always** validate input before sending
2. **Always** handle timeouts gracefully
3. **Don't** send commands faster than 100ms apart
4. **Do** implement exponential backoff for reconnections
5. **Do** cache device info (don't request repeatedly)
6. **Do** log BLE commands for debugging
7. **Don't** assume WiFi will work immediately after config

---

## Performance Metrics

- **Memory Usage:** ~5KB per active connection
- **Throughput:** ~2KB/s typical
- **Power Consumption (Device):** ~50mA connected, ~10mA advertising
- **Latency:** < 100ms typical for commands

---

**Document Version:** 1.0  
**Last Updated:** April 2026  
**Protocol Version:** 1.0
