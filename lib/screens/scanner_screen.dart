import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:esp32_climate_app/services/app_settings_provider.dart';
import 'package:esp32_climate_app/device_screen.dart';
import 'package:esp32_climate_app/mock_screen.dart';

class BLEScannerScreen extends StatefulWidget {
  const BLEScannerScreen({super.key});

  @override
  State<BLEScannerScreen> createState() => _BLEScannerScreenState();
}

class _BLEScannerScreenState extends State<BLEScannerScreen> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
    }
  }

  void startScan() async {
    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    try {
      // Start scanning for 4 seconds
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          scanResults = results;
        });
      });

      await Future.delayed(const Duration(seconds: 4));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e')),
        );
      }
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<AppSettingsProvider>();
    final isDark = themeProvider.isDarkMode;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find ESP32 Device'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Scan Bluetooth',
            onPressed: isScanning ? null : startScan,
          ),
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: () {
              themeProvider.setDarkMode(!themeProvider.isDarkMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Open Simulator',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MockDeviceScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0A1128), const Color(0xFF121B3A)]
                    : [const Color(0xFFE3F2FD), const Color(0xFF90CAF9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            right: -50,
            top: 40,
            child: Icon(
              Icons.device_hub,
              size: 220,
              color: onSurface.withAlpha(15),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: isScanning
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Scanning for Bluetooth devices...',
                            style: TextStyle(color: onSurface),
                          ),
                        ],
                      ),
                    )
                  : scanResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bluetooth_disabled,
                                  size: 72, color: onSurface.withAlpha(128)),
                              const SizedBox(height: 18),
                              Text(
                                'No devices found',
                                style: TextStyle(
                                  color: onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the search button to start scanning',
                                style: TextStyle(color: onSurface.withAlpha(191), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: scanResults.length,
                          itemBuilder: (context, index) {
                            final result = scanResults[index];
                            final device = result.device;
                            final rssi = result.rssi;
                            if (device.platformName.isEmpty) return const SizedBox.shrink();

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Icon(
                                    Icons.network_wifi,
                                    color: _signalColor(rssi),
                                  ),
                                ),
                                title: Text(device.platformName, style: TextStyle(color: onSurface)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device.remoteId.toString(),
                                      style: TextStyle(color: onSurface.withAlpha(204), fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Chip(
                                          label: Text(
                                            _deviceTypeLabel(device.platformName),
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Chip(
                                          label: Text(
                                            'RSSI $rssi',
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                          backgroundColor: Theme.of(context).colorScheme.secondary,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    FlutterBluePlus.stopScan();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DeviceScreen(device: device),
                                      ),
                                    );
                                  },
                                  child: const Text('Connect'),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? null : startScan,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: isScanning
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.search),
      ),
    );
  }

  Color _signalColor(int rssi) {
    if (rssi >= -70) return Colors.green;
    if (rssi >= -85) return Colors.orange;
    return Colors.red;
  }

  String _deviceTypeLabel(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('esp') || lower.contains('32')) return 'ESP32';
    if (lower.contains('sensor')) return 'Sensor';
    return 'BLE Device';
  }
}
