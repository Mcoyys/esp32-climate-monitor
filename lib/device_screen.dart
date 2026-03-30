import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  String humidityValue = "-- %";
  String tempValue = "-- °C";
  bool isWarningActive = false;
  
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
  void processData(List<int> rawData) {
    String decodedString = utf8.decode(rawData).trim();
    List<String> splitData = decodedString.split(',');

    if (splitData.length >= 2) {
      setState(() {
        humidityValue = "${splitData[0]} %";
        tempValue = "${splitData[1]} °C";
      });

      checkExtremeHeat(double.tryParse(splitData[1]) ?? 0.0);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red[50],
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text('EXTREME HEAT', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(
            'Temperature has reached $tempValue.\n\nPlease OPEN THE AC immediately to prevent hardware damage or discomfort.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ACKNOWLEDGE', style: TextStyle(color: Colors.red)),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.water_drop, size: 80, color: Colors.blue),
            const SizedBox(height: 10),
            const Text("Current Humidity", style: TextStyle(fontSize: 20, color: Colors.grey)),
            Text(humidityValue, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 50),
            
            Icon(Icons.thermostat, size: 80, color: isWarningActive ? Colors.red : Colors.orange),
            const SizedBox(height: 10),
            const Text("Current Temperature", style: TextStyle(fontSize: 20, color: Colors.grey)),
            Text(tempValue, style: TextStyle(
              fontSize: 48, 
              fontWeight: FontWeight.bold,
              color: isWarningActive ? Colors.red : Colors.black
            )),
          ],
        ),
      ),
    );
  }
}