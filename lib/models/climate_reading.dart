class ClimateReading {
  final int id;
  final double temperature;
  final double humidity;
  final DateTime timestamp;
  final String deviceId;

  ClimateReading({
    this.id = 0,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    required this.deviceId,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
    };
  }

  // Create from JSON
  factory ClimateReading.fromJson(Map<String, dynamic> json) {
    return ClimateReading(
      id: json['id'] ?? 0,
      temperature: json['temperature'] ?? 0.0,
      humidity: json['humidity'] ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      deviceId: json['deviceId'] ?? '',
    );
  }

  // Create from database map
  factory ClimateReading.fromMap(Map<String, dynamic> map) {
    return ClimateReading(
      id: map['id'],
      temperature: map['temperature'],
      humidity: map['humidity'],
      timestamp: DateTime.parse(map['timestamp']),
      deviceId: map['deviceId'],
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
    };
  }

  @override
  String toString() {
    return 'ClimateReading(temp: ${temperature.toStringAsFixed(1)}°C, humidity: ${humidity.toStringAsFixed(1)}%)';
  }
}
