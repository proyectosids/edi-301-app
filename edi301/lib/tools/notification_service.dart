import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  // ✅ Canal nuevo (si el anterior quedó con baja importancia, este lo "resetea")
  static const String _channelId = 'edi301_high_v1';
  static const String _channelName = 'Notificaciones EDI-301';
  static const String _channelDesc = 'Avisos importantes de EDI-301';

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
    } catch (_) {}

    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('ic_notification');

    const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initIOS,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );

    // ✅ Crear canal en Android con importancia MAX (heads-up)
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await androidPlugin.createNotificationChannel(channel);
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      _platformDetails,
      payload: payload,
    );
  }

  // ✅ Usa el canal HIGH que sí creamos
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_notification',
        color: Color(0xFF13436B),
        playSound: true,
        enableVibration: true,
      );

  static const NotificationDetails _platformDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    ),
  );

  Future<void> scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      _platformDetails,
      payload: payload,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  Future<bool> requestPermissions() async {
    final plugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (plugin != null) {
      return await plugin.requestNotificationsPermission() ?? false;
    }

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }
}
