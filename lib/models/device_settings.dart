class DeviceSettings {
  final String deviceId;
  final String deviceName;
  final double maxTempThreshold;
  final double minTempThreshold;
  final double maxHumidityThreshold;
  final double minHumidityThreshold;
  final bool notificationsEnabled;
  final String? wifiSSID;
  final String? wifiIpAddress;
  final bool isWifiConfigured;

  DeviceSettings({
    required this.deviceId,
    required this.deviceName,
    this.maxTempThreshold = 35.0,
    this.minTempThreshold = 5.0,
    this.maxHumidityThreshold = 80.0,
    this.minHumidityThreshold = 20.0,
    this.notificationsEnabled = true,
    this.wifiSSID,
    this.wifiIpAddress,
    this.isWifiConfigured = false,
  });

  // Create a copy with modified fields
  DeviceSettings copyWith({
    String? deviceId,
    String? deviceName,
    double? maxTempThreshold,
    double? minTempThreshold,
    double? maxHumidityThreshold,
    double? minHumidityThreshold,
    bool? notificationsEnabled,
    String? wifiSSID,
    String? wifiIpAddress,
    bool? isWifiConfigured,
  }) {
    return DeviceSettings(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      maxTempThreshold: maxTempThreshold ?? this.maxTempThreshold,
      minTempThreshold: minTempThreshold ?? this.minTempThreshold,
      maxHumidityThreshold: maxHumidityThreshold ?? this.maxHumidityThreshold,
      minHumidityThreshold: minHumidityThreshold ?? this.minHumidityThreshold,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      wifiSSID: wifiSSID ?? this.wifiSSID,
      wifiIpAddress: wifiIpAddress ?? this.wifiIpAddress,
      isWifiConfigured: isWifiConfigured ?? this.isWifiConfigured,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'maxTempThreshold': maxTempThreshold,
      'minTempThreshold': minTempThreshold,
      'maxHumidityThreshold': maxHumidityThreshold,
      'minHumidityThreshold': minHumidityThreshold,
      'notificationsEnabled': notificationsEnabled,
      'wifiSSID': wifiSSID,
      'wifiIpAddress': wifiIpAddress,
      'isWifiConfigured': isWifiConfigured,
    };
  }

  factory DeviceSettings.fromJson(Map<String, dynamic> json) {
    return DeviceSettings(
      deviceId: json['deviceId'] ?? '',
      deviceName: json['deviceName'] ?? 'Climate Monitor',
      maxTempThreshold: json['maxTempThreshold'] ?? 35.0,
      minTempThreshold: json['minTempThreshold'] ?? 5.0,
      maxHumidityThreshold: json['maxHumidityThreshold'] ?? 80.0,
      minHumidityThreshold: json['minHumidityThreshold'] ?? 20.0,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      wifiSSID: json['wifiSSID'],
      wifiIpAddress: json['wifiIpAddress'],
      isWifiConfigured: json['isWifiConfigured'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'maxTempThreshold': maxTempThreshold,
      'minTempThreshold': minTempThreshold,
      'maxHumidityThreshold': maxHumidityThreshold,
      'minHumidityThreshold': minHumidityThreshold,
      'notificationsEnabled': notificationsEnabled,
      'wifiSSID': wifiSSID,
      'wifiIpAddress': wifiIpAddress,
      'isWifiConfigured': isWifiConfigured,
    };
  }

  factory DeviceSettings.fromMap(Map<String, dynamic> map) {
    return DeviceSettings(
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? 'Climate Monitor',
      maxTempThreshold: map['maxTempThreshold'] ?? 35.0,
      minTempThreshold: map['minTempThreshold'] ?? 5.0,
      maxHumidityThreshold: map['maxHumidityThreshold'] ?? 80.0,
      minHumidityThreshold: map['minHumidityThreshold'] ?? 20.0,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      wifiSSID: map['wifiSSID'],
      wifiIpAddress: map['wifiIpAddress'],
      isWifiConfigured: map['isWifiConfigured'] ?? false,
    );
  }
}
