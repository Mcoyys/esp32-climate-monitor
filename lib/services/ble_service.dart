import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BLECommandType {
  setWiFiConfig,
  requestClimateData,
  requestDeviceInfo,
  setThresholds,
  calibrate,
}

class BLEService {
  static final BLEService _instance = BLEService._internal();
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _notifyCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;

  late StreamController<String> _dataStreamController;
  late StreamController<bool> _connectionStatusController;

  factory BLEService() {
    return _instance;
  }

  BLEService._internal() {
    _dataStreamController = StreamController<String>.broadcast();
    _connectionStatusController = StreamController<bool>.broadcast();
  }

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  Stream<String> get dataStream => _dataStreamController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // ===== CONNECTION MANAGEMENT =====
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _connectedDevice = device;
      await device.connect(timeout: const Duration(seconds: 10));
      _connectionStatusController.add(true);
      
      await _discoverCharacteristics();
      await _setupNotifications();
    } catch (e) {
      _connectedDevice = null;
      _connectionStatusController.add(false);
      rethrow;
    }
  }

  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _notifyCharacteristic = null;
      _writeCharacteristic = null;
      _connectionStatusController.add(false);
    }
  }

  Future<void> _discoverCharacteristics() async {
    if (_connectedDevice == null) return;

    try {
      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Look for characteristic with notify property (for receiving data)
          if (characteristic.properties.notify) {
            _notifyCharacteristic = characteristic;
          }
          // Look for characteristic with write property (for sending commands)
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
          }
        }
      }

      if (_notifyCharacteristic == null && _writeCharacteristic == null) {
        throw Exception('Required BLE characteristics not found');
      }
    } catch (e) {
      throw Exception('Failed to discover characteristics: $e');
    }
  }

  Future<void> _setupNotifications() async {
    if (_notifyCharacteristic == null) return;

    try {
      await _notifyCharacteristic!.setNotifyValue(true);
      _notifyCharacteristic!.lastValueStream.listen((value) {
        String data = utf8.decode(value).trim();
        _dataStreamController.add(data);
      });
    } catch (e) {
      print('Failed to setup notifications: $e');
    }
  }

  // ===== SENDING COMMANDS TO ESP32 =====
  Future<void> sendCommand(String command) async {
    if (_writeCharacteristic == null) {
      throw Exception('Write characteristic not available');
    }

    try {
      List<int> bytes = utf8.encode(command);
      await _writeCharacteristic!.write(bytes);
    } catch (e) {
      throw Exception('Failed to send command: $e');
    }
  }

  // ===== WIFI CONFIGURATION =====
  /// Format: "WIFI:SSID,PASSWORD"
  /// Example: "WIFI:MyNetwork,MyPassword123"
  Future<void> sendWiFiConfig(String ssid, String password) async {
    String command = 'WIFI:$ssid,$password';
    await sendCommand(command);
  }

  // ===== CALIBRATION =====
  /// Format: "CALIBRATE:TEMP,HUMIDITY"
  /// Example: "CALIBRATE:25.0,50.0"
  Future<void> sendCalibration(double temperature, double humidity) async {
    String command = 'CALIBRATE:$temperature,$humidity';
    await sendCommand(command);
  }

  // ===== THRESHOLD SETTINGS =====
  /// Format: "THRESHOLDS:MAX_TEMP,MIN_TEMP,MAX_HUMID,MIN_HUMID"
  /// Example: "THRESHOLDS:35.0,5.0,80.0,20.0"
  Future<void> sendThresholds({
    required double maxTemp,
    required double minTemp,
    required double maxHumidity,
    required double minHumidity,
  }) async {
    String command = 'THRESHOLDS:$maxTemp,$minTemp,$maxHumidity,$minHumidity';
    await sendCommand(command);
  }

  // ===== REQUEST DEVICE INFO =====
  Future<void> requestDeviceInfo() async {
    await sendCommand('INFO');
  }

  // ===== PARSING INCOMING DATA =====
  /// Parse climate data: "CLIMATE:TEMP,HUMIDITY"
  /// Example: "CLIMATE:28.5,65.2"
  static Map<String, double>? parseClimateData(String rawData) {
    try {
      if (rawData.startsWith('CLIMATE:')) {
        String cleanData = rawData.substring(8);
        List<String> parts = cleanData.split(',');
        if (parts.length >= 2) {
          return {
            'temperature': double.parse(parts[0]),
            'humidity': double.parse(parts[1]),
          };
        }
      }
      return null;
    } catch (e) {
      print('Error parsing climate data: $e');
      return null;
    }
  }

  /// Parse device info: "INFO:MODEL,FW_VERSION,MAC_ADDRESS"
  static Map<String, String>? parseDeviceInfo(String rawData) {
    try {
      if (rawData.startsWith('INFO:')) {
        String cleanData = rawData.substring(5);
        List<String> parts = cleanData.split(',');
        if (parts.length >= 3) {
          return {
            'model': parts[0],
            'firmware': parts[1],
            'mac': parts[2],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error parsing device info: $e');
      return null;
    }
  }

  /// Parse WiFi config acknowledgement: "WIFI_OK:SSID" or "WIFI_OK:SSID,IP" or "WIFI_ERROR:REASON"
  static Map<String, String>? parseWiFiResponse(String rawData) {
    try {
      if (rawData.startsWith('WIFI_OK:')) {
        String payload = rawData.substring(8);
        List<String> parts = payload.split(',');
        final result = <String, String>{'status': 'ok', 'ssid': parts[0]};
        if (parts.length >= 2) {
          result['ip'] = parts[1];
        }
        return result;
      } else if (rawData.startsWith('WIFI_ERROR:')) {
        return {'status': 'error', 'reason': rawData.substring(11)};
      }
      return null;
    } catch (e) {
      print('Error parsing WiFi response: $e');
      return null;
    }
  }

  // ===== CLEANUP =====
  void dispose() {
    disconnectDevice();
    _dataStreamController.close();
    _connectionStatusController.close();
  }
}
