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
  bool _tzInitialized = false;

  // Carga la base de zonas horarias SOLO cuando se necesita (al programar una
  // notificación). Es una operación síncrona pesada (~900 KB); si se hiciera en
  // el arranque, bloquearía el hilo principal y podría congelar la app.
  void _ensureTimezones() {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    _tzInitialized = true;
  }

  Future<void> init() async {
    if (_isInitialized) return;

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
    await init();
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
    await init();
    if (scheduledDate.isBefore(DateTime.now())) return;

    // Carga zonas horarias solo aquí (cuando de verdad se programa algo).
    _ensureTimezones();

    // Solicita permiso de alarma exacta justo antes de programar (Android 12+).
    // Se hace lazy aquí y no en startup para no abrir Settings de sorpresa.
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestExactAlarmsPermission();
    } catch (_) {}

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
    await init();
    await _notificationsPlugin.cancel(id: id);
  }

  // ── Pedir Permisos ──────────────────────────────────
  // Solo pide el permiso de notificaciones (diálogo normal).
  // requestExactAlarmsPermission se llama de forma lazy en scheduleNotification
  // porque abre la app de Settings del sistema, lo que rompe el flujo normal.
  Future<void> requestPermissions() async {
    await init();
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }
}
