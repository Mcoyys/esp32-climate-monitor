import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:esp32_climate_app/services/ble_service.dart';
import 'package:esp32_climate_app/services/notification_service.dart';
import 'package:esp32_climate_app/services/app_settings_provider.dart';
import 'package:esp32_climate_app/database/database_service.dart';
import 'package:esp32_climate_app/screens/scanner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  final databaseService = DatabaseService();
  await databaseService.database;
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.requestNotificationPermissions();
  
  final appSettingsProvider = AppSettingsProvider();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<BLEService>(create: (_) => BLEService()),
        ChangeNotifierProvider<AppSettingsProvider>.value(value: appSettingsProvider),
      ],
      child: const ClimateMonitorApp(),
    ),
  );
}

class ClimateMonitorApp extends StatelessWidget {
  const ClimateMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettingsProvider>();

    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0366D6),
        secondary: const Color(0xFF00BFA6),
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0097A7),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF10121A),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F1724),
        foregroundColor: Colors.white,
      ),
    );

    return MaterialApp(
      title: 'ESP32 Climate Monitor',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: appSettings.themeMode,
      home: const BLEScannerScreen(),
    );
  }
}