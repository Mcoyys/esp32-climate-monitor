enum AlertType {
  maxTemp,
  minTemp,
  maxHumidity,
  minHumidity,
  deviceDisconnected,
  wifiConfigured,
  other,
}

class AlertEvent {
  final int id;
  final String deviceId;
  final AlertType type;
  final String message;
  final DateTime timestamp;
  final double? temperature;
  final double? humidity;
  final bool isResolved;

  AlertEvent({
    this.id = 0,
    required this.deviceId,
    required this.type,
    required this.message,
    required this.timestamp,
    this.temperature,
    this.humidity,
    this.isResolved = false,
  });

  String get typeString {
    switch (type) {
      case AlertType.maxTemp:
        return 'High Temperature';
      case AlertType.minTemp:
        return 'Low Temperature';
      case AlertType.maxHumidity:
        return 'High Humidity';
      case AlertType.minHumidity:
        return 'Low Humidity';
      case AlertType.deviceDisconnected:
        return 'Device Disconnected';
      case AlertType.wifiConfigured:
        return 'WiFi Configured';
      case AlertType.other:
        return 'Alert';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceId': deviceId,
      'type': type.index,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'isResolved': isResolved ? 1 : 0,
    };
  }

  factory AlertEvent.fromMap(Map<String, dynamic> map) {
    return AlertEvent(
      id: map['id'] ?? 0,
      deviceId: map['deviceId'] ?? '',
      type: AlertType.values[map['type'] ?? 0],
      message: map['message'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      temperature: map['temperature'],
      humidity: map['humidity'],
      isResolved: map['isResolved'] == 1,
    );
  }
}
