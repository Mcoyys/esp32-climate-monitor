import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esp32_climate_app/models/climate_reading.dart';
import 'package:esp32_climate_app/models/device_settings.dart';
import 'package:esp32_climate_app/models/alert_event.dart';
import 'package:esp32_climate_app/services/ble_service.dart';
import 'package:esp32_climate_app/services/notification_service.dart';
import 'package:esp32_climate_app/database/database_service.dart';

class ClimateDataProvider extends ChangeNotifier {
  final BLEService bleService;
  final DatabaseService databaseService;
  final NotificationService notificationService;

  ClimateReading? _currentReading;
  DeviceSettings? _deviceSettings;
  List<ClimateReading> _readings = [];
  List<AlertEvent> _alerts = [];
  bool _isConnected = false;
  String? _error;
  late StreamSubscription<String> _dataSubscription;
  late StreamSubscription<bool> _connectionSubscription;

  ClimateDataProvider({
    required this.bleService,
    required this.databaseService,
    required this.notificationService,
    required String deviceId,
  }) {
    _subscribeToDataUpdates();
    _loadSettings(deviceId);
  }

  // Getters
  ClimateReading? get currentReading => _currentReading;
  DeviceSettings? get deviceSettings => _deviceSettings;
  List<ClimateReading> get readings => _readings;
  List<AlertEvent> get alerts => _alerts;
  bool get isConnected => _isConnected;
  String? get error => _error;

  void _subscribeToDataUpdates() {
    _dataSubscription = bleService.dataStream.listen((data) {
      _processIncomingData(data);
    });

    _connectionSubscription = bleService.connectionStatusStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });
  }

  Future<void> _loadSettings(String deviceId) async {
    try {
      _deviceSettings = await databaseService.getDeviceSettings(deviceId);
      _deviceSettings ??= DeviceSettings(
        deviceId: deviceId,
        deviceName: 'Climate Monitor',
      );
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load settings: $e';
      notifyListeners();
    }
  }

  void _processIncomingData(String rawData) async {
    // Parse climate data
    Map<String, double>? climateData = BLEService.parseClimateData(rawData);

    if (climateData != null) {
      double temperature = climateData['temperature']!;
      double humidity = climateData['humidity']!;

      // Create new reading
      _currentReading = ClimateReading(
        temperature: temperature,
        humidity: humidity,
        timestamp: DateTime.now(),
        deviceId: _deviceSettings?.deviceId ?? '',
      );

      // Save to database
      await databaseService.insertClimateReading(_currentReading!);

      // Refresh readings
      await _loadReadings();

      // Check thresholds
      await _checkThresholds(temperature, humidity);

      notifyListeners();
    }

    // Parse WiFi response
    Map<String, String>? wifiResponse = BLEService.parseWiFiResponse(rawData);
    if (wifiResponse != null && wifiResponse['status'] == 'ok') {
      await _handleWiFiConfigured(
        wifiResponse['ssid'] ?? 'Unknown',
        wifiResponse['ip'],
      );
    }
  }

  Future<void> _checkThresholds(double temperature, double humidity) async {
    if (_deviceSettings == null || !_deviceSettings!.notificationsEnabled) {
      return;
    }

    // Temperature checks
    if (temperature >= _deviceSettings!.maxTempThreshold) {
      await _createAlert(
        AlertType.maxTemp,
        'Temperature reached ${temperature.toStringAsFixed(1)}°C. Turn on AC!',
        temperature,
        humidity,
      );
      await notificationService.showHighTempWarning(
        temperature,
        _deviceSettings!.deviceName,
      );
    } else if (temperature <= _deviceSettings!.minTempThreshold) {
      await _createAlert(
        AlertType.minTemp,
        'Temperature dropped to ${temperature.toStringAsFixed(1)}°C.',
        temperature,
        humidity,
      );
      await notificationService.showLowTempWarning(
        temperature,
        _deviceSettings!.deviceName,
      );
    }

    // Humidity checks
    if (humidity >= _deviceSettings!.maxHumidityThreshold) {
      await _createAlert(
        AlertType.maxHumidity,
        'Humidity reached ${humidity.toStringAsFixed(1)}%. Check ventilation.',
        temperature,
        humidity,
      );
      await notificationService.showHighHumidityWarning(
        humidity,
        _deviceSettings!.deviceName,
      );
    } else if (humidity <= _deviceSettings!.minHumidityThreshold) {
      await _createAlert(
        AlertType.minHumidity,
        'Humidity dropped to ${humidity.toStringAsFixed(1)}%. Air is dry.',
        temperature,
        humidity,
      );
      await notificationService.showLowHumidityWarning(
        humidity,
        _deviceSettings!.deviceName,
      );
    }
  }

  Future<void> _createAlert(
    AlertType type,
    String message,
    double temperature,
    double humidity,
  ) async {
    try {
      AlertEvent alert = AlertEvent(
        deviceId: _deviceSettings?.deviceId ?? '',
        type: type,
        message: message,
        timestamp: DateTime.now(),
        temperature: temperature,
        humidity: humidity,
      );

      await databaseService.insertAlertEvent(alert);
      await _loadAlerts();
    } catch (e) {
      print('Error creating alert: $e');
    }
  }

  Future<void> _handleWiFiConfigured(String ssid, [String? ipAddress]) async {
    try {
      if (_deviceSettings != null) {
        DeviceSettings updated = _deviceSettings!.copyWith(
          wifiSSID: ssid,
          wifiIpAddress: ipAddress,
          isWifiConfigured: true,
        );
        await databaseService.saveDeviceSettings(updated);
        _deviceSettings = updated;
        notifyListeners();
      }

      await notificationService.showWiFiConfiguredSuccess(
        _deviceSettings?.deviceName ?? 'Device',
        ssid,
        ipAddress: ipAddress,
      );
    } catch (e) {
      print('Error handling WiFi configuration: $e');
    }
  }

  Future<void> _loadReadings() async {
    try {
      if (_deviceSettings != null) {
        _readings = await databaseService.getClimateReadings(
          _deviceSettings!.deviceId,
          limit: 100,
          durationBack: const Duration(days: 7),
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to load readings: $e';
      notifyListeners();
    }
  }

  Future<void> _loadAlerts() async {
    try {
      if (_deviceSettings != null) {
        _alerts = await databaseService.getAlertEvents(
          _deviceSettings!.deviceId,
          limit: 50,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to load alerts: $e';
      notifyListeners();
    }
  }

  Future<void> updateDeviceSettings(DeviceSettings settings) async {
    try {
      await databaseService.saveDeviceSettings(settings);
      _deviceSettings = settings;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update settings: $e';
      notifyListeners();
    }
  }

  Future<void> markAlertAsResolved(int alertId) async {
    try {
      await databaseService.markAlertAsResolved(alertId);
      await _loadAlerts();
    } catch (e) {
      _error = 'Failed to resolve alert: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dataSubscription.cancel();
    _connectionSubscription.cancel();
    super.dispose();
  }
}
