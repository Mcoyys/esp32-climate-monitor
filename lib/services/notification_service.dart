import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static FirebaseMessaging? _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotificationsPlugin;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    _initLocalNotifications();
  }

  void _initLocalNotifications() {
    _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      _initAndroidNotifications();
    } else if (Platform.isIOS) {
      _initIOSNotifications();
    }
  }

  void _initAndroidNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    _localNotificationsPlugin.initialize(
      InitializationSettings(android: initializationSettingsAndroid),
    );
  }

  void _initIOSNotifications() {
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    _localNotificationsPlugin.initialize(
      InitializationSettings(iOS: initializationSettingsIOS),
    );
  }

  Future<void> requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ requires explicit permission
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool urgent = false,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'climate_alerts',
      'Climate Alerts',
      channelDescription: 'Notifications about temperature, humidity, and device alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> showHighTempWarning(
    double temperature,
    String deviceName,
  ) async {
    await showLocalNotification(
      id: 1001,
      title: '🌡️ High Temperature Alert',
      body: '$deviceName has reached ${temperature.toStringAsFixed(1)}°C. Consider turning on AC.',
      payload: 'high_temp',
      urgent: true,
    );
  }

  Future<void> showLowTempWarning(
    double temperature,
    String deviceName,
  ) async {
    await showLocalNotification(
      id: 1002,
      title: '❄️ Low Temperature Alert',
      body: '$deviceName has dropped to ${temperature.toStringAsFixed(1)}°C. Check heating.',
      payload: 'low_temp',
      urgent: true,
    );
  }

  Future<void> showHighHumidityWarning(
    double humidity,
    String deviceName,
  ) async {
    await showLocalNotification(
      id: 1003,
      title: '💧 High Humidity Alert',
      body: '$deviceName humidity is at ${humidity.toStringAsFixed(1)}%. Check ventilation.',
      payload: 'high_humidity',
      urgent: true,
    );
  }

  Future<void> showLowHumidityWarning(
    double humidity,
    String deviceName,
  ) async {
    await showLocalNotification(
      id: 1004,
      title: '🏜️ Low Humidity Alert',
      body: '$deviceName humidity is at ${humidity.toStringAsFixed(1)}%. Air is dry.',
      payload: 'low_humidity',
      urgent: true,
    );
  }

  Future<void> showDeviceDisconnectedWarning(String deviceName) async {
    await showLocalNotification(
      id: 1005,
      title: '📴 Device Disconnected',
      body: '$deviceName has disconnected. Reconnect to resume monitoring.',
      payload: 'device_disconnected',
      urgent: true,
    );
  }

  Future<void> showWiFiConfiguredSuccess(String deviceName, String ssid) async {
    await showLocalNotification(
      id: 1006,
      title: '✅ WiFi Configured',
      body: '$deviceName successfully connected to $ssid.',
      payload: 'wifi_configured',
      urgent: false,
    );
  }

  Future<void> showDeviceReconnected(String deviceName) async {
    await showLocalNotification(
      id: 1007,
      title: '📱 Device Reconnected',
      body: '$deviceName is back online.',
      payload: 'device_reconnected',
      urgent: false,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _localNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotificationsPlugin.cancelAll();
  }
}
