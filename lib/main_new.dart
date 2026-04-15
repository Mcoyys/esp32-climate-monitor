import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:esp32_climate_app/services/ble_service.dart';
import 'package:esp32_climate_app/services/notification_service.dart';
import 'package:esp32_climate_app/services/climate_data_provider.dart';
import 'package:esp32_climate_app/database/database_service.dart';
import 'package:esp32_climate_app/screens/scanner_screen.dart';
import 'package:esp32_climate_app/mock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  final databaseService = DatabaseService();
  await databaseService.database;
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.requestNotificationPermissions();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<BLEService>(create: (_) => BLEService()),
      ],
      child: const ClimateMonitorApp(),
    ),
  );
}

class ClimateMonitorApp extends StatelessWidget {
  const ClimateMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Climate Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BLEScannerScreen(),
    );
  }
}
