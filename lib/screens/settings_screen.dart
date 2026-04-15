import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:esp32_climate_app/services/ble_service.dart';
import 'package:esp32_climate_app/services/app_settings_provider.dart';
import 'package:esp32_climate_app/database/database_service.dart';
import 'package:esp32_climate_app/models/device_settings.dart';

class SettingsScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BLEService bleService;
  final DatabaseService databaseService;
  final Function(DeviceSettings) onSettingsSaved;

  const SettingsScreen({
    super.key,
    required this.device,
    required this.bleService,
    required this.databaseService,
    required this.onSettingsSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _deviceNameController;
  late DeviceSettings _currentSettings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _deviceNameController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      DeviceSettings? settings = await widget.databaseService.getDeviceSettings(
        widget.device.remoteId.toString(),
      );

      settings ??= DeviceSettings(
        deviceId: widget.device.remoteId.toString(),
        deviceName: widget.device.platformName.isEmpty
            ? 'Climate Monitor'
            : widget.device.platformName,
      );

      setState(() {
        _currentSettings = settings!;
        _deviceNameController.text = _currentSettings.deviceName;
        _isLoading = false;
      });
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      DeviceSettings updatedSettings = _currentSettings.copyWith(
        deviceName: _deviceNameController.text.isEmpty
            ? 'Climate Monitor'
            : _deviceNameController.text,
      );

      // Save to database
      await widget.databaseService.saveDeviceSettings(updatedSettings);

      // Send thresholds to device via BLE
      if (widget.bleService.isConnected) {
        await widget.bleService.sendThresholds(
          maxTemp: updatedSettings.maxTempThreshold,
          minTemp: updatedSettings.minTempThreshold,
          maxHumidity: updatedSettings.maxHumidityThreshold,
          minHumidity: updatedSettings.minHumidityThreshold,
        );
      }

      widget.onSettingsSaved(updatedSettings);
      Fluttertoast.showToast(msg: 'Settings saved successfully');

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error saving settings: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<AppSettingsProvider>();

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Device Settings'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Settings'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Name
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _deviceNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter device name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.devices),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Temperature Thresholds
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🌡️ Temperature Thresholds',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Max Temperature
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Max Temperature (Alert)'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              border: Border.all(color: Colors.orange),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_currentSettings.maxTempThreshold.toStringAsFixed(1)}°C',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _currentSettings.maxTempThreshold,
                        min: 20.0,
                        max: 50.0,
                        divisions: 30,
                        label:
                            '${_currentSettings.maxTempThreshold.toStringAsFixed(1)}°C',
                        onChanged: (value) {
                          setState(() {
                            _currentSettings = _currentSettings.copyWith(
                              maxTempThreshold: value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Min Temperature
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Min Temperature (Alert)'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_currentSettings.minTempThreshold.toStringAsFixed(1)}°C',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _currentSettings.minTempThreshold,
                        min: -10.0,
                        max: 20.0,
                        divisions: 30,
                        label:
                            '${_currentSettings.minTempThreshold.toStringAsFixed(1)}°C',
                        onChanged: (value) {
                          setState(() {
                            _currentSettings = _currentSettings.copyWith(
                              minTempThreshold: value,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Humidity Thresholds
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💧 Humidity Thresholds',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Max Humidity
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Max Humidity (Alert)'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_currentSettings.maxHumidityThreshold.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _currentSettings.maxHumidityThreshold,
                        min: 60.0,
                        max: 100.0,
                        divisions: 40,
                        label:
                            '${_currentSettings.maxHumidityThreshold.toStringAsFixed(1)}%',
                        onChanged: (value) {
                          setState(() {
                            _currentSettings = _currentSettings.copyWith(
                              maxHumidityThreshold: value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Min Humidity
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Min Humidity (Alert)'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              border: Border.all(color: Colors.orange),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_currentSettings.minHumidityThreshold.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _currentSettings.minHumidityThreshold,
                        min: 0.0,
                        max: 40.0,
                        divisions: 40,
                        label:
                            '${_currentSettings.minHumidityThreshold.toStringAsFixed(1)}%',
                        onChanged: (value) {
                          setState(() {
                            _currentSettings = _currentSettings.copyWith(
                              minHumidityThreshold: value,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notifications Toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🔔 Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Switch(
                        value: _currentSettings.notificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _currentSettings = _currentSettings.copyWith(
                              notificationsEnabled: value,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Automatic Theme Toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '⏰ Automatic Theme',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Use local time to switch between light and dark mode.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: themeProvider.useAutomaticTheme,
                        onChanged: (value) {
                          themeProvider.setUseAutomaticTheme(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dark Mode Toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🌙 Dark Mode',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (themeProvider.useAutomaticTheme)
                              const SizedBox(height: 4),
                            if (themeProvider.useAutomaticTheme)
                              const Text(
                                'Manual override is disabled while automatic theme is active.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: themeProvider.useAutomaticTheme
                            ? null
                            : (value) {
                                themeProvider.setDarkMode(value);
                              },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
