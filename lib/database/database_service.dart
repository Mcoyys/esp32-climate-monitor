import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:esp32_climate_app/models/climate_reading.dart';
import 'package:esp32_climate_app/models/device_settings.dart';
import 'package:esp32_climate_app/models/alert_event.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'climate_monitor.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Climate readings table
    await db.execute('''
      CREATE TABLE climate_readings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        temperature REAL NOT NULL,
        humidity REAL NOT NULL,
        timestamp TEXT NOT NULL,
        deviceId TEXT NOT NULL
      )
    ''');

    // Device settings table
    await db.execute('''
      CREATE TABLE device_settings(
        deviceId TEXT PRIMARY KEY,
        deviceName TEXT NOT NULL,
        maxTempThreshold REAL,
        minTempThreshold REAL,
        maxHumidityThreshold REAL,
        minHumidityThreshold REAL,
        notificationsEnabled INTEGER,
        wifiSSID TEXT,
        wifiIpAddress TEXT,
        isWifiConfigured INTEGER
      )
    ''');

    // Alert events table
    await db.execute('''
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
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_climate_deviceId ON climate_readings(deviceId)');
    await db.execute('CREATE INDEX idx_climate_timestamp ON climate_readings(timestamp)');
    await db.execute('CREATE INDEX idx_alert_deviceId ON alert_events(deviceId)');
    await db.execute('CREATE INDEX idx_alert_timestamp ON alert_events(timestamp)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE device_settings ADD COLUMN wifiIpAddress TEXT');
    }
  }

  // ===== CLIMATE READINGS =====
  Future<int> insertClimateReading(ClimateReading reading) async {
    final db = await database;
    return await db.insert('climate_readings', reading.toMap());
  }

  Future<List<ClimateReading>> getClimateReadings(String deviceId,
      {int limit = 100, Duration? durationBack}) async {
    final db = await database;
    String query = 'SELECT * FROM climate_readings WHERE deviceId = ?';
    List<dynamic> args = [deviceId];

    if (durationBack != null) {
      DateTime cutoffTime = DateTime.now().subtract(durationBack);
      query += ' AND timestamp >= ?';
      args.add(cutoffTime.toIso8601String());
    }

    query += ' ORDER BY timestamp DESC LIMIT ?';
    args.add(limit);

    final result = await db.rawQuery(query, args);
    return result.map((map) => ClimateReading.fromMap(map)).toList();
  }

  Future<ClimateReading?> getLatestReading(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'climate_readings',
      where: 'deviceId = ?',
      whereArgs: [deviceId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return result.isEmpty ? null : ClimateReading.fromMap(result.first);
  }

  Future<void> deleteOldReadings(String deviceId, Duration age) async {
    final db = await database;
    DateTime cutoff = DateTime.now().subtract(age);
    await db.delete(
      'climate_readings',
      where: 'deviceId = ? AND timestamp < ?',
      whereArgs: [deviceId, cutoff.toIso8601String()],
    );
  }

  // ===== DEVICE SETTINGS =====
  Future<void> saveDeviceSettings(DeviceSettings settings) async {
    final db = await database;
    await db.insert(
      'device_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DeviceSettings?> getDeviceSettings(String deviceId) async {
    final db = await database;
    final result = await db.query(
      'device_settings',
      where: 'deviceId = ?',
      whereArgs: [deviceId],
    );
    return result.isEmpty ? null : DeviceSettings.fromMap(result.first);
  }

  Future<List<DeviceSettings>> getAllDeviceSettings() async {
    final db = await database;
    final result = await db.query('device_settings');
    return result.map((map) => DeviceSettings.fromMap(map)).toList();
  }

  Future<void> deleteDeviceSettings(String deviceId) async {
    final db = await database;
    await db.delete(
      'device_settings',
      where: 'deviceId = ?',
      whereArgs: [deviceId],
    );
  }

  // ===== ALERT EVENTS =====
  Future<int> insertAlertEvent(AlertEvent event) async {
    final db = await database;
    return await db.insert('alert_events', event.toMap());
  }

  Future<List<AlertEvent>> getAlertEvents(String deviceId,
      {int limit = 50, bool onlyUnresolved = false}) async {
    final db = await database;
    String query = 'SELECT * FROM alert_events WHERE deviceId = ?';
    List<dynamic> args = [deviceId];

    if (onlyUnresolved) {
      query += ' AND isResolved = 0';
    }

    query += ' ORDER BY timestamp DESC LIMIT ?';
    args.add(limit);

    final result = await db.rawQuery(query, args);
    return result.map((map) => AlertEvent.fromMap(map)).toList();
  }

  Future<void> markAlertAsResolved(int alertId) async {
    final db = await database;
    await db.update(
      'alert_events',
      {'isResolved': 1},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  Future<void> deleteOldAlerts(Duration age) async {
    final db = await database;
    DateTime cutoff = DateTime.now().subtract(age);
    await db.delete(
      'alert_events',
      where: 'timestamp < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  // ===== CLEANUP =====
  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('climate_readings');
    await db.delete('device_settings');
    await db.delete('alert_events');
  }

  Future<void> deleteDeviceAllData(String deviceId) async {
    final db = await database;
    await db.delete('climate_readings', where: 'deviceId = ?', whereArgs: [deviceId]);
    await db.delete('alert_events', where: 'deviceId = ?', whereArgs: [deviceId]);
    await deleteDeviceSettings(deviceId);
  }
}
