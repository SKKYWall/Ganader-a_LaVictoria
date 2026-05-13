// lib/services/notification_service.dart

import 'package:flutter/material.dart'; // <-- AGREGADO para que reconozca "Color"
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // Patrón Singleton para usar la misma instancia en toda la app
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Inicializar zonas horarias (necesario para programar fechas)
    tz.initializeTimeZones();

    // Configuración para Android
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS
    const DarwinInitializationSettings initSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    // CORRECCIÓN: Ahora exige el nombre "settings:"
    await _notificationsPlugin.initialize(settings: initSettings);
    _isInitialized = true;
  }

  // 1. NOTIFICACIÓN INMEDIATA (Ej: Alerta de inventario bajo)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ganadero_alerts',
      'Alertas Ganaderas',
      channelDescription: 'Notificaciones importantes del rancho',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFc99450),
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  // 2. NOTIFICACIÓN PROGRAMADA (Ej: Partos, Calendario)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Si la fecha ya pasó, no programar
    if (scheduledDate.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ganadero_scheduled',
      'Recordatorios Programados',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // CORRECCIÓN: Todos los parámetros ahora llevan nombre (id:, title:, etc.)
    // y se eliminó uiLocalNotificationDateInterpretation porque el paquete ya no lo necesita.
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // CANCELAR NOTIFICACIÓN (Si borras un evento o un animal)
  Future<void> cancelNotification(int id) async {
    // CORRECCIÓN: Ahora exige el nombre "id:"
    await _notificationsPlugin.cancel(id: id);
  }

  // ── Pedir Permisos ──────────────────────────────────
  Future<void> requestPermissions() async {
    // 1. Permisos para iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // 2. Permisos para Android 13+ (Mostrar notificaciones)
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();

    // 3. FALTA ESTO: Permiso para ALARMAS EXACTAS en Android 12+
    // (Sin esto, la app crashea al intentar programar un parto o vacuna)
    await androidImplementation?.requestExactAlarmsPermission();
  }
}
