import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:esp32_climate_app/services/ble_service.dart';
import 'package:esp32_climate_app/services/notification_service.dart';
import 'package:esp32_climate_app/services/climate_data_provider.dart';
import 'package:esp32_climate_app/database/database_service.dart';
import 'package:esp32_climate_app/screens/wifi_config_screen.dart';
import 'package:esp32_climate_app/screens/settings_screen.dart';

class DeviceScreenNew extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreenNew({super.key, required this.device});

  @override
  State<DeviceScreenNew> createState() => _DeviceScreenNewState();
}

class _DeviceScreenNewState extends State<DeviceScreenNew> {
  late BLEService bleService;
  late DatabaseService databaseService;
  late NotificationService notificationService;
  late ClimateDataProvider climateProvider;

  bool _isInitializing = true;
  bool _isProviderReady = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      bleService = context.read<BLEService>();
      databaseService = context.read<DatabaseService>();
      notificationService = context.read<NotificationService>();

      await bleService.connectToDevice(widget.device);

      climateProvider = ClimateDataProvider(
        bleService: bleService,
        databaseService: databaseService,
        notificationService: notificationService,
        deviceId: widget.device.remoteId.toString(),
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isProviderReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    if (_isProviderReady) {
      climateProvider.dispose();
    }
    bleService.disconnectDevice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connecting...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider.value(
      value: climateProvider,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.device.platformName.isEmpty
                ? 'Climate Monitor'
                : widget.device.platformName,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      device: widget.device,
                      bleService: bleService,
                      databaseService: databaseService,
                      onSettingsSaved: (settings) {
                        climateProvider.updateDeviceSettings(settings);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.primary.withAlpha(24),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                left: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withAlpha(90),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -70,
                right: -50,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary.withAlpha(70),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
              Consumer<ClimateDataProvider>(
                builder: (context, provider, _) {
                  final reading = provider.currentReading;
                  final settings = provider.deviceSettings;
                  final connected = provider.isConnected;
                  final readings = provider.readings;
                  final primary = Theme.of(context).colorScheme.primary;
                  final onSurface = Theme.of(context).colorScheme.onSurface;

                  return Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withAlpha(18),
                              blurRadius: 26,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.device.platformName.isEmpty
                                            ? 'Climate Monitor'
                                            : widget.device.platformName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Chip(
                                            label: Text(connected
                                                ? 'Connected'
                                                : 'Disconnected'),
                                            backgroundColor: connected
                                                ? Colors.green
                                                : Colors.red,
                                            labelStyle:
                                                const TextStyle(color: Colors.white),
                                          ),
                                          Chip(
                                            label: Text(
                                              settings?.isWifiConfigured == true
                                                  ? 'WiFi ready'
                                                  : 'WiFi not set',
                                            ),
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                            labelStyle:
                                                const TextStyle(color: Colors.white),
                                          ),
                                          if (settings?.wifiIpAddress != null)
                                            Chip(
                                              label: Text(
                                                'IP ${settings!.wifiIpAddress}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer,
                                              labelStyle:
                                                  const TextStyle(color: Colors.black),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: connected
                                        ? Colors.green.withAlpha(40)
                                        : Colors.red.withAlpha(40),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    connected ? Icons.wifi : Icons.wifi_off,
                                    color: connected ? Colors.green : Colors.red,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primary.withAlpha(240),
                              Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withAlpha(220),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withAlpha(90),
                              blurRadius: 32,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 20,
                        ),
                        child: reading == null
                              ? Center(
                                  child: Text(
                                    'Waiting for live sensor data...',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(220),
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '🌡️ Temperature',
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(220),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${reading.temperature.toStringAsFixed(1)}°C',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 44,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withAlpha(128),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      height: 80,
                                      width: 1,
                                      color: Colors.white.withAlpha(64),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '💧 Humidity',
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(220),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${reading.humidity.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 44,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withAlpha(128),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                      ),

                      const SizedBox(height: 16),

                      _buildStatusRings(context, reading, settings),

                      const SizedBox(height: 16),

                      _buildHistoryChart(context, readings),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.wifi),
                  label: const Text("Configure WiFi"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WiFiConfigScreen(
                          device: widget.device,
                          bleService: bleService,
                          databaseService: databaseService,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              Consumer<ClimateDataProvider>(
                builder: (context, provider, _) {
                  final s = provider.deviceSettings;
                  if (s == null) return const SizedBox();

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Thresholds",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          _row("Max Temp", "${s.maxTempThreshold}°C"),
                          _row("Min Temp", "${s.minTempThreshold}°C"),
                          _row("Max Humidity", "${s.maxHumidityThreshold}%"),
                          _row("Min Humidity", "${s.minHumidityThreshold}%"),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              Consumer<ClimateDataProvider>(
                builder: (context, provider, _) {
                  final alerts = provider.alerts;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Recent Alerts",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),

                          if (alerts.isEmpty)
                            const Text("No alerts yet")
                          else
                            ...alerts.take(5).map((alert) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.orange),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              alert.typeString,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(alert.message),
                                            Text(
                                              alert.timestamp.toString().split('.')[0],
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!alert.isResolved)
                                        IconButton(
                                          icon: const Icon(Icons.check),
                                          onPressed: () {
                                            provider.markAlertAsResolved(alert.id);
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildStatusRings(BuildContext context, dynamic reading, dynamic deviceSettings) {
    final tempValue = reading == null ? 0.0 : (reading.temperature as double) / 50.0;
    final humidityValue = reading == null ? 0.0 : (reading.humidity as double) / 100.0;

    return Row(
      children: [
        Expanded(
          child: _buildRingCard(
            context,
            label: 'Temp progress',
            value: tempValue.clamp(0.0, 1.0),
            display: reading == null ? '—' : '${reading.temperature.toStringAsFixed(1)}°C',
            color: Colors.orangeAccent,
            subtitle: 'out of 50°C',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildRingCard(
            context,
            label: 'Humidity',
            value: humidityValue.clamp(0.0, 1.0),
            display: reading == null ? '—' : '${reading.humidity.toStringAsFixed(1)}%',
            color: Colors.cyanAccent,
            subtitle: 'out of 100%',
          ),
        ),
      ],
    );
  }

  Widget _buildRingCard(
    BuildContext context, {
    required String label,
    required double value,
    required String display,
    required Color color,
    required String subtitle,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(200),
            Theme.of(context).colorScheme.surface.withAlpha(245),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: onSurface.withAlpha(14),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(color: onSurface.withAlpha(18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: onSurface.withAlpha(200), fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 98,
                    height: 98,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 10,
                      color: color,
                      backgroundColor: color.withAlpha(55),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        display,
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(80),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: onSurface.withAlpha(160), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryChart(BuildContext context, List readings) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final recent = readings.take(8).toList();
    final tempSpots = recent.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.temperature as double);
    }).toList();
    final humiditySpots = recent.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.humidity as double);
    }).toList();

    if (recent.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Waiting for temperature and humidity history...',
              style: TextStyle(color: onSurface.withAlpha(204)),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface.withAlpha(235),
        boxShadow: [
          BoxShadow(
            color: onSurface.withAlpha(14),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History', style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: onSurface.withAlpha(31),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 10,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(color: onSurface.withAlpha(179), fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 60,
                  lineBarsData: [
                    LineChartBarData(
                      spots: tempSpots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [Colors.orangeAccent, Colors.deepOrangeAccent],
                      ),
                      barWidth: 4,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [Colors.orangeAccent.withAlpha(100), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    LineChartBarData(
                      spots: humiditySpots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [Colors.cyanAccent, Colors.lightBlueAccent],
                      ),
                      barWidth: 4,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [Colors.cyanAccent.withAlpha(100), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _legendDot(context, Colors.orangeAccent, 'Temp'),
                _legendDot(context, Colors.cyanAccent, 'Humidity'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: onSurface.withAlpha(204))),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }
}