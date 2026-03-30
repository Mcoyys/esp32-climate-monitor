import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device_screen.dart'; 
import 'mock_screen.dart'; // ADDED: So the simulator button knows what to open

void main() {
  runApp(const ClimateMonitorApp());
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

    // Start scanning for 4 seconds
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await Future.delayed(const Duration(seconds: 4));
    setState(() {
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find ESP32 Device'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          // --- THIS IS THE NEW TEST BUTTON ---
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
          // -----------------------------------
        ],
      ),
      body: ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (context, index) {
          final device = scanResults[index].device;
          // Filter to show named devices to avoid clutter
          if (device.platformName.isEmpty) return const SizedBox.shrink();
          
          return ListTile(
            title: Text(device.platformName),
            subtitle: Text(device.remoteId.toString()),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? null : startScan,
        child: isScanning ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.search),
      ),
    );
  }
}