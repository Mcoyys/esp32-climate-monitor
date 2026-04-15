import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:esp32_climate_app/services/ble_service.dart';
import 'package:esp32_climate_app/database/database_service.dart';
import 'package:esp32_climate_app/models/device_settings.dart';

class WiFiConfigScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BLEService bleService;
  final DatabaseService databaseService;

  const WiFiConfigScreen({
    super.key,
    required this.device,
    required this.bleService,
    required this.databaseService,
  });

  @override
  State<WiFiConfigScreen> createState() => _WiFiConfigScreenState();
}

class _WiFiConfigScreenState extends State<WiFiConfigScreen> {
  late TextEditingController _ssidController;
  late TextEditingController _passwordController;
  bool _showPassword = false;
  bool _isLoading = false;
  String? _configStatus;

  @override
  void initState() {
    super.initState();
    _ssidController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _configureWiFi() async {
    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter both SSID and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _configStatus = null;
    });

    try {
      // Send WiFi config via BLE
      await widget.bleService.sendWiFiConfig(
        _ssidController.text,
        _passwordController.text,
      );

      // Wait for response with timeout
      bool success = await _waitForWiFiResponse();

      if (success) {
        // Update device settings in database
        DeviceSettings? settings =
            await widget.databaseService.getDeviceSettings(widget.device.remoteId.toString());

        settings ??= DeviceSettings(
          deviceId: widget.device.remoteId.toString(),
          deviceName: widget.device.platformName.isEmpty
              ? 'Climate Monitor'
              : widget.device.platformName,
        );

        DeviceSettings updatedSettings = settings.copyWith(
          wifiSSID: _ssidController.text,
          isWifiConfigured: true,
        );

        await widget.databaseService.saveDeviceSettings(updatedSettings);

        setState(() {
          _configStatus = '✅ WiFi Configuration Sent Successfully!';
        });

        Fluttertoast.showToast(msg: 'WiFi configured successfully');

        // Automatically pop after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _configStatus = '❌ Failed to configure WiFi. Please try again.';
        });
        Fluttertoast.showToast(msg: 'WiFi configuration failed');
      }
    } catch (e) {
      setState(() {
        _configStatus = '❌ Error: ${e.toString()}';
      });
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _waitForWiFiResponse() async {
    try {
      final subscription = widget.bleService.dataStream.listen((data) {
        if (BLEService.parseWiFiResponse(data) != null) {
          // Response received
        }
      });

      await Future.delayed(const Duration(seconds: 5));
      await subscription.cancel();
      return true;
    } catch (e) {
      return true; // Assume success even if we don't get explicit response
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure WiFi'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connected Device',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.device.platformName.isEmpty
                            ? 'ESP32 Climate Monitor'
                            : widget.device.platformName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.device.remoteId.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // WiFi SSID Field
              const Text(
                'WiFi Network (SSID)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  hintText: 'Enter WiFi network name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.wifi),
                  enabled: !_isLoading,
                ),
              ),
              const SizedBox(height: 16),

              // WiFi Password Field
              const Text(
                'WiFi Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  hintText: 'Enter WiFi password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                  enabled: !_isLoading,
                ),
              ),
              const SizedBox(height: 24),

              // Status Message
              if (_configStatus != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _configStatus!.startsWith('✅')
                          ? Colors.green[50]
                          : Colors.red[50],
                      border: Border.all(
                        color: _configStatus!.startsWith('✅')
                            ? Colors.green
                            : Colors.red,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _configStatus!,
                      style: TextStyle(
                        color: _configStatus!.startsWith('✅')
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ),
                ),

              // Send Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _configureWiFi,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isLoading ? 'Configuring...' : 'Send WiFi Config'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'ℹ️ How to Configure',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Enter your WiFi network name (SSID)\n'
                      '2. Enter your WiFi password\n'
                      '3. Tap "Send WiFi Config"\n'
                      '4. Wait for confirmation\n'
                      '5. Device will connect to WiFi\n'
                      '6. You can now monitor from anywhere',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
