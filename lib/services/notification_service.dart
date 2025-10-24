import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/event.dart';
import '../models/task.dart';

/// Servicio de notificaciones para recordatorios de eventos
/// Implementa mejores prácticas de seguridad y manejo de permisos
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Inicializar el servicio de notificaciones
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Inicializar timezone database
      tz.initializeTimeZones();
      
      // Configuración para Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Configuración para iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Configuración general
      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Inicializar plugin con manejo de respuesta a notificaciones
      final initialized = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        _isInitialized = true;
        await _requestPermissions();
      }

      return _isInitialized;
    } catch (e) {
      throw NotificationException('Error al inicializar notificaciones: $e');
    }
  }

  /// Solicitar permisos necesarios para notificaciones
  Future<bool> _requestPermissions() async {
    try {
      // Solicitar permiso de notificaciones
      final notificationStatus = await Permission.notification.request();
      
      // En Android 13+, solicitar permiso específico para notificaciones programadas
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }

      return notificationStatus.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Manejar toque en notificación
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // Aquí se puede implementar navegación específica basada en el evento
      // Por ejemplo, abrir el detalle del evento
      _handleNotificationAction(payload);
    }
  }

  /// Procesar acciones de notificación
  void _handleNotificationAction(String payload) {
    // Implementar lógica de navegación o acciones específicas
    // basadas en el payload del evento
  }

  /// Programar notificación para un evento
  Future<void> scheduleEventNotification(Event event) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Calcular tiempo de notificación (15 minutos antes del evento)
      final notificationTime = event.startTime.subtract(const Duration(minutes: 15));
      
      // Solo programar si es en el futuro
      if (notificationTime.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: event.id.hashCode,
          title: 'Recordatorio: ${event.title}',
          body: 'Tu evento comienza en 15 minutos',
          scheduledDate: notificationTime,
          payload: event.id,
        );
      }

      // Programar notificación adicional al inicio del evento
      if (event.startTime.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: ('${event.id}_start').hashCode,
          title: event.title,
          body: 'Tu evento está comenzando ahora',
          scheduledDate: event.startTime,
          payload: event.id,
        );
      }
    } catch (e) {
      throw NotificationException('Error al programar notificación: $e');
    }
  }

  /// Programar una notificación específica
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Detalles de notificación para Android
    const androidDetails = AndroidNotificationDetails(
      'event_reminders',
      'Recordatorios de Eventos',
      channelDescription: 'Notificaciones para recordatorios de eventos de la agenda',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF2196F3),
    );

    // Detalles de notificación para iOS
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Detalles generales
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Programar la notificación
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledDate),
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Convertir DateTime a TZDateTime para notificaciones programadas
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    // Obtener la zona horaria local
    final location = tz.local;
    
    // Convertir DateTime a TZDateTime en la zona horaria local
    return tz.TZDateTime.from(dateTime, location);
  }

  /// Actualizar notificación de evento
  Future<void> updateEventNotification(Event event) async {
    // Cancelar notificaciones existentes
    await cancelEventNotification(event.id);
    
    // Programar nuevas notificaciones
    await scheduleEventNotification(event);
  }

  /// Cancelar notificaciones de un evento
  Future<void> cancelEventNotification(String eventId) async {
    try {
      // Cancelar notificación de recordatorio
      await _notificationsPlugin.cancel(eventId.hashCode);
      
      // Cancelar notificación de inicio
      await _notificationsPlugin.cancel(('${eventId}_start').hashCode);
    } catch (e) {
      throw NotificationException('Error al cancelar notificaciones: $e');
    }
  }

  /// Programar notificación para una tarea
  Future<void> scheduleTaskNotification(Task task) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Si la tarea tiene recordatorio personalizado
      if (task.reminderDateTime != null && task.reminderDateTime!.isAfter(DateTime.now())) {
        await _scheduleTaskNotification(
          id: task.id.hashCode,
          title: 'Recordatorio: ${task.title}',
          body: task.description.isNotEmpty ? task.description : 'Tienes una tarea pendiente',
          scheduledDate: task.reminderDateTime!,
          payload: task.id,
        );
      } 
      // Si no tiene recordatorio pero tiene fecha de vencimiento, notificar 1 hora antes
      else if (task.dueDate != null) {
        final notificationTime = task.dueDate!.subtract(const Duration(hours: 1));
        
        if (notificationTime.isAfter(DateTime.now())) {
          await _scheduleTaskNotification(
            id: task.id.hashCode,
            title: 'Tarea por vencer: ${task.title}',
            body: 'Vence en 1 hora',
            scheduledDate: notificationTime,
            payload: task.id,
          );
        }

        // También notificar al momento del vencimiento
        if (task.dueDate!.isAfter(DateTime.now())) {
          await _scheduleTaskNotification(
            id: ('${task.id}_due').hashCode,
            title: '¡Tarea venciendo ahora!',
            body: task.title,
            scheduledDate: task.dueDate!,
            payload: task.id,
          );
        }
      }
    } catch (e) {
      throw NotificationException('Error al programar notificación de tarea: $e');
    }
  }

  /// Programar una notificación específica para tarea
  Future<void> _scheduleTaskNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Detalles de notificación para Android
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Recordatorios de Tareas',
      channelDescription: 'Notificaciones para recordatorios de tareas',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
    );

    // Detalles de notificación para iOS
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Detalles generales
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Programar la notificación
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledDate),
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Actualizar notificación de tarea
  Future<void> updateTaskNotification(Task task) async {
    // Cancelar notificaciones existentes
    await cancelTaskNotification(task.id);
    
    // Solo programar si la tarea está pendiente
    if (task.status == TaskStatus.pending) {
      await scheduleTaskNotification(task);
    }
  }

  /// Cancelar notificaciones de una tarea
  Future<void> cancelTaskNotification(String taskId) async {
    try {
      // Cancelar notificación de recordatorio
      await _notificationsPlugin.cancel(taskId.hashCode);
      
      // Cancelar notificación de vencimiento
      await _notificationsPlugin.cancel(('${taskId}_due').hashCode);
    } catch (e) {
      throw NotificationException('Error al cancelar notificaciones de tarea: $e');
    }
  }

  /// Mostrar notificación inmediata
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'immediate_notifications',
      'Notificaciones Inmediatas',
      channelDescription: 'Notificaciones que se muestran inmediatamente',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Obtener notificaciones pendientes
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Verificar si las notificaciones están habilitadas
  Future<bool> areNotificationsEnabled() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Crear canal de notificaciones (Android)
  Future<void> createNotificationChannels() async {
    // Canal para recordatorios de eventos
    const eventChannel = AndroidNotificationChannel(
      'event_reminders',
      'Recordatorios de Eventos',
      description: 'Notificaciones para recordatorios de eventos de la agenda',
      importance: Importance.high,
    );

    // Canal para recordatorios de tareas
    const taskChannel = AndroidNotificationChannel(
      'task_reminders',
      'Recordatorios de Tareas',
      description: 'Notificaciones para recordatorios de tareas',
      importance: Importance.high,
    );

    // Canal para notificaciones inmediatas
    const immediateChannel = AndroidNotificationChannel(
      'immediate_notifications',
      'Notificaciones Inmediatas',
      description: 'Notificaciones que se muestran inmediatamente',
      importance: Importance.high,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Crear canales en el dispositivo
    await androidImplementation?.createNotificationChannel(eventChannel);
    await androidImplementation?.createNotificationChannel(taskChannel);
    await androidImplementation?.createNotificationChannel(immediateChannel);
  }

  /// Limpiar recursos del servicio
  void dispose() {
    // Limpiar recursos si es necesario
  }
}

/// Excepción personalizada para errores de notificaciones
class NotificationException implements Exception {
  final String message;
  
  NotificationException(this.message);
  
  @override
  String toString() => 'NotificationException: $message';
}
