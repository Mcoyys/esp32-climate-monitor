import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:esp32_climate_app/services/notification_service.dart';
import 'package:esp32_climate_app/services/app_settings_provider.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  String humidityValue = "-- %";
  String tempValue = "-- °C";
  double currentTemp = 0.0;
  double currentHumidity = 0.0;
  bool isWarningActive = false;
  String? wifiIpAddress;

  // Set your extreme heat threshold here (e.g., 35.0 °C)
  final double extremeHeatThreshold = 35.0;

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect();
      discoverServices();
    } catch (e) {
      print("Connection error: $e");
    }
  }

  Future<void> discoverServices() async {
    List<BluetoothService> services = await widget.device.discoverServices();

    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        // We look for characteristics that support 'notify' or 'read'
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((value) {
            processData(value);
          });
        }
      }
    }
  }

  // EXPECTED DATA FORMAT FROM ESP32: "Humidity,Temperature" (e.g., "45.2,36.5")
  // Or WiFi format: "WIFI_OK:SSID,IP" or "WIFI_CONNECTED:IP" or just "IP:192.168.1.100"
  void processData(List<int> rawData) {
    String decodedString = utf8.decode(rawData).trim();
    print("Received data: '$decodedString'");
    
    // Check if it's WiFi data - try multiple formats
    if (decodedString.contains("WIFI")) {
      print("WiFi data detected");
      String? ip;
      
      // Try format: WIFI_OK:SSID,IP
      if (decodedString.contains("WIFI_OK")) {
        final parts = decodedString.split(':');
        if (parts.length > 1) {
          final wifiParts = parts[1].split(',');
          if (wifiParts.length > 1) {
            ip = wifiParts[1].trim();
          }
        }
      }
      // Try format: WIFI_CONNECTED:IP
      else if (decodedString.contains("WIFI_CONNECTED")) {
        final parts = decodedString.split(':');
        if (parts.length > 1) {
          ip = parts[1].trim();
        }
      }
      // Try format: IP:192.168.1.100
      else if (decodedString.startsWith("IP:")) {
        final parts = decodedString.split(':');
        if (parts.length > 1) {
          ip = parts[1].trim();
        }
      }
      
      if (ip != null && ip.isNotEmpty) {
        setState(() {
          wifiIpAddress = ip;
        });
        print("WiFi IP set to: $ip");
      return;
    }

    // Normal climate data
    List<String> splitData = decodedString.split(',');

    if (splitData.length >= 2) {
      currentHumidity = double.tryParse(splitData[0]) ?? 0.0;
      currentTemp = double.tryParse(splitData[1]) ?? 0.0;
      setState(() {
        humidityValue = "${currentHumidity.toStringAsFixed(1)} %";
        tempValue = "${currentTemp.toStringAsFixed(1)} °C";
      });

      checkExtremeHeat(currentTemp);
    }
  }

  void checkExtremeHeat(double temperature) {
    if (temperature >= extremeHeatThreshold && !isWarningActive) {
      setState(() => isWarningActive = true);
      showHeatWarning();
    } else if (temperature < extremeHeatThreshold && isWarningActive) {
      setState(() => isWarningActive = false);
    }
  }

  void showHeatWarning() {
    NotificationService().showHighTempWarning(
      currentTemp,
      widget.device.platformName,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 57, 50, 51),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text('EXTREME HEAT', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(
            'Temperature has reached $tempValue.\n\nPlease OPEN THE AC immediately to prevent hardware damage or discomfort.',
            // Added Colors.red here so it shows up clearly in dark mode
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'ACKNOWLEDGE',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // We keep isWarningActive = true so the dialog doesn't spam loop
                // until the temperature naturally drops below the threshold.
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        backgroundColor: isWarningActive ? Colors.red : Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // WiFi Status and Automatic Theme Toggle at the top
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // WiFi IP Display - Always show the chip
                    Chip(
                      avatar: wifiIpAddress != null 
                        ? const Icon(Icons.wifi, color: Colors.green)
                        : const Icon(Icons.wifi_off, color: Colors.grey),
                      label: Text(
                        wifiIpAddress != null 
                          ? 'WiFi: $wifiIpAddress'
                          : 'WiFi: Not Connected'
                      ),
                      backgroundColor: wifiIpAddress != null 
                        ? Colors.green.shade100 
                        : Colors.grey.shade200,
                    ),

                    const SizedBox(height: 12),

                    // Theme Controls - Both Automatic and Manual
                    Consumer<AppSettingsProvider>(
                      builder: (context, settings, _) {
                        return Column(
                          children: [
                            // Automatic Theme Toggle
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blueAccent),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Automatic Theme',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        settings.useAutomaticTheme
                                            ? '7am-7pm Light, 7pm-7am Dark'
                                            : 'Manual Mode',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: settings.useAutomaticTheme,
                                    onChanged: (value) {
                                      settings.setUseAutomaticTheme(value);
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Manual Dark Mode Toggle (only show when automatic is OFF)
                            if (!settings.useAutomaticTheme)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.purpleAccent),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Dark Mode',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Switch(
                                      value: settings.isDarkMode,
                                      onChanged: (value) {
                                        settings.setDarkMode(value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Temperature and Humidity Display (centered)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.water_drop, size: 80, color: Colors.blue),
                  const SizedBox(height: 10),
                  const Text(
                    "Current Humidity",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  Text(
                    humidityValue,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 50),

                  Icon(
                    Icons.thermostat,
                    size: 80,
                    color: isWarningActive ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Current Temperature",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  Text(
                    tempValue,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isWarningActive ? Colors.red : Colors.yellow,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
