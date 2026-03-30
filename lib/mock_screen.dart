import 'dart:async';
import 'package:flutter/material.dart';

class MockDeviceScreen extends StatefulWidget {
  const MockDeviceScreen({super.key});

  @override
  State<MockDeviceScreen> createState() => _MockDeviceScreenState();
}

class _MockDeviceScreenState extends State<MockDeviceScreen> {
  double currentTemp = 30.0;
  double currentHumidity = 55.0;
  bool isWarningActive = false;
  
  final double extremeHeatThreshold = 35.0; 
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    startSimulation();
  }

  void startSimulation() {
    // This timer acts like the BLE notifications from the ESP32
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        // Increase temp by 1.5 degrees every 2 seconds to test the warning
        currentTemp += 1.5; 
        
        // Fluctuate humidity slightly for realism
        currentHumidity = currentHumidity > 70 ? 55.0 : currentHumidity + 2.5;

        // Reset loop if it gets too hot so we can test the warning clearing
        if (currentTemp > 39.0) {
          currentTemp = 28.0; 
        }
      });

      checkExtremeHeat(currentTemp);
    });
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
            'Temperature has reached ${currentTemp.toStringAsFixed(1)} °C.\n\nPlease OPEN THE AC immediately.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ACKNOWLEDGE', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel(); // Stop the timer when we leave the screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SIMULATOR MODE"),
        backgroundColor: isWarningActive ? Colors.red : Colors.purple, // Purple to indicate test mode
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("NO HARDWARE REQUIRED", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 30),
            
            const Icon(Icons.water_drop, size: 80, color: Colors.blue),
            const SizedBox(height: 10),
            const Text("Simulated Humidity", style: TextStyle(fontSize: 20, color: Colors.grey)),
            Text("${currentHumidity.toStringAsFixed(1)} %", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 50),
            
            Icon(Icons.thermostat, size: 80, color: isWarningActive ? Colors.red : Colors.orange),
            const SizedBox(height: 10),
            const Text("Simulated Temperature", style: TextStyle(fontSize: 20, color: Colors.grey)),
            Text("${currentTemp.toStringAsFixed(1)} °C", style: TextStyle(
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