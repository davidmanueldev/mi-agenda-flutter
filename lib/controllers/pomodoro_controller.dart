import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pomodoro_session.dart';
import '../services/database_interface.dart';
import '../services/database_service_hybrid_v2.dart';
import '../services/notification_service.dart';
import '../utils/security_utils.dart';

/// Controlador para la gestión del temporizador Pomodoro
/// Implementa patrón Provider para gestión de estado
class PomodoroController with ChangeNotifier {
  final DatabaseInterface _database;
  final NotificationService _notificationService;

  // Estado del timer
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  SessionType _currentSessionType = SessionType.work;
  
  // Sesión actual
  PomodoroSession? _currentSession;
  String? _linkedTaskId;
  
  // Configuración de duraciones (en segundos)
  int _workDuration = 25 * 60; // 25 minutos
  int _shortBreakDuration = 5 * 60; // 5 minutos
  int _longBreakDuration = 15 * 60; // 15 minutos
  
  // Contador de sesiones completadas (para descanso largo cada 4 sesiones)
  int _completedWorkSessions = 0;
  
  // Historial y estadísticas
  List<PomodoroSession> _sessions = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  SessionType get currentSessionType => _currentSessionType;
  int get completedWorkSessions => _completedWorkSessions;
  List<PomodoroSession> get sessions => List.unmodifiable(_sessions);
  Map<String, dynamic> get stats => Map.unmodifiable(_stats);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get linkedTaskId => _linkedTaskId;
  
  // Duraciones configurables
  int get workDuration => _workDuration;
  int get shortBreakDuration => _shortBreakDuration;
  int get longBreakDuration => _longBreakDuration;
  
  // Getters de progreso
  double get progress {
    final totalDuration = _getDurationForSessionType(_currentSessionType);
    if (totalDuration == 0) return 0.0;
    return 1.0 - (_remainingSeconds / totalDuration);
  }
  
  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Constructor con inyección de dependencias
  PomodoroController({
    required DatabaseInterface databaseService,
    required NotificationService notificationService,
  })  : _database = databaseService,
        _notificationService = notificationService {
    _initialize();
  }

  /// Inicializar controlador
  Future<void> _initialize() async {
    // Configurar listener para cambios de Firebase (solo si es DatabaseServiceHybridV2)
    if (_database is DatabaseServiceHybridV2) {
      (_database as DatabaseServiceHybridV2).onDataChanged = () async {
        await _loadSessions();
        await _loadStats();
        await _loadCompletedSessionsCount();
      };
    }
    
    // Cargar contador de sesiones persistido
    await _loadCompletedSessionsCount();
    
    // Cargar datos iniciales
    await _loadSessions();
    await _loadStats();
    
    // Inicializar timer con duración de trabajo
    _remainingSeconds = _workDuration;
  }

  /// Cargar sesiones desde la base de datos
  Future<void> _loadSessions() async {
    try {
      _sessions = await _database.getAllPomodoroSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando sesiones Pomodoro: $e');
    }
  }

  /// Cargar estadísticas
  Future<void> _loadStats() async {
    try {
      _stats = await _database.getPomodoroStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando estadísticas Pomodoro: $e');
    }
  }

  /// Iniciar timer
  Future<void> start({String? taskId}) async {
    if (_isRunning && !_isPaused) return;

    _linkedTaskId = taskId;
    
    if (_isPaused) {
      // Reanudar desde pausa
      _isPaused = false;
    } else {
      // Iniciar nueva sesión
      _remainingSeconds = _getDurationForSessionType(_currentSessionType);
      
      // Crear sesión en la base de datos
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}'; // Temporal
      _currentSession = PomodoroSession(
        id: SecurityUtils.generateSecureId(),
        userId: userId,
        sessionType: _currentSessionType,
        duration: _remainingSeconds,
        startTime: DateTime.now(),
        taskId: _linkedTaskId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _database.insertPomodoroSession(_currentSession!);
    }

    _isRunning = true;
    _startTimer();
    notifyListeners();
  }

  /// Pausar timer
  void pause() {
    if (!_isRunning || _isPaused) return;
    
    _isPaused = true;
    _timer?.cancel();
    notifyListeners();
  }

  /// Reanudar timer
  Future<void> resume() async {
    if (!_isPaused) return;
    await start();
  }

  /// Detener timer completamente
  Future<void> stop() async {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    
    // Si hay una sesión activa sin completar, marcarla como incompleta
    if (_currentSession != null && _currentSession!.endTime == null) {
      // No guardar sesiones incompletas, simplemente eliminarlas
      await _database.deletePomodoroSession(_currentSession!.id);
      _currentSession = null;
    }
    
    _remainingSeconds = _getDurationForSessionType(_currentSessionType);
    notifyListeners();
  }

  /// Resetear timer al inicio
  Future<void> reset() async {
    await stop();
    _remainingSeconds = _getDurationForSessionType(_currentSessionType);
    notifyListeners();
  }

  /// Saltar a la siguiente sesión
  Future<void> skipToNext() async {
    // Si hay una sesión activa, completarla antes de saltar
    if (_currentSession != null && _isRunning) {
      await _completeSession();
    } else {
      await stop();
      _switchToNextSessionType();
      notifyListeners();
    }
  }

  /// Iniciar el timer interno
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        // Timer completado
        await _completeSession();
      }
    });
  }

  /// Completar sesión actual
  Future<void> _completeSession() async {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;

    // Actualizar sesión con tiempo de fin
    if (_currentSession != null) {
      final completedSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _database.updatePomodoroSession(completedSession);
      
      // Incrementar contador si fue sesión de trabajo
      if (_currentSessionType == SessionType.work) {
        _completedWorkSessions++;
        await _saveCompletedSessionsCount();
      }
      
      // Mostrar notificación
      await _showCompletionNotification();
      
      // Recargar datos
      await _loadSessions();
      await _loadStats();
      
      _currentSession = null;
    }

    // Cambiar automáticamente al siguiente tipo de sesión
    _switchToNextSessionType();
    
    notifyListeners();
  }

  /// Cambiar al siguiente tipo de sesión
  void _switchToNextSessionType() {
    if (_currentSessionType == SessionType.work) {
      // Después de trabajo, determinar tipo de descanso
      if (_completedWorkSessions % 4 == 0 && _completedWorkSessions > 0) {
        _currentSessionType = SessionType.longBreak;
      } else {
        _currentSessionType = SessionType.shortBreak;
      }
    } else {
      // Después de descanso, volver a trabajo
      _currentSessionType = SessionType.work;
    }
    
    _remainingSeconds = _getDurationForSessionType(_currentSessionType);
  }

  /// Mostrar notificación al completar sesión
  Future<void> _showCompletionNotification() async {
    try {
      String title = '';
      String body = '';
      
      switch (_currentSessionType) {
        case SessionType.work:
          title = '¡Sesión de trabajo completada! 🎉';
          body = 'Buen trabajo. Es hora de tomar un descanso.';
          break;
        case SessionType.shortBreak:
          title = '¡Descanso corto completado! ☕';
          body = 'Listo para continuar trabajando.';
          break;
        case SessionType.longBreak:
          title = '¡Descanso largo completado! 🌟';
          body = 'Descansaste bien. ¡A trabajar con energía!';
          break;
      }
      
      await _notificationService.showImmediateNotification(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Error mostrando notificación: $e');
    }
  }

  /// Obtener duración para un tipo de sesión
  int _getDurationForSessionType(SessionType type) {
    switch (type) {
      case SessionType.work:
        return _workDuration;
      case SessionType.shortBreak:
        return _shortBreakDuration;
      case SessionType.longBreak:
        return _longBreakDuration;
    }
  }

  /// Configurar duración de sesión de trabajo
  void setWorkDuration(int minutes) {
    _workDuration = minutes * 60;
    if (_currentSessionType == SessionType.work && !_isRunning) {
      _remainingSeconds = _workDuration;
    }
    notifyListeners();
  }

  /// Configurar duración de descanso corto
  void setShortBreakDuration(int minutes) {
    _shortBreakDuration = minutes * 60;
    if (_currentSessionType == SessionType.shortBreak && !_isRunning) {
      _remainingSeconds = _shortBreakDuration;
    }
    notifyListeners();
  }

  /// Configurar duración de descanso largo
  void setLongBreakDuration(int minutes) {
    _longBreakDuration = minutes * 60;
    if (_currentSessionType == SessionType.longBreak && !_isRunning) {
      _remainingSeconds = _longBreakDuration;
    }
    notifyListeners();
  }

  /// Obtener sesiones de hoy
  Future<List<PomodoroSession>> getTodaySessions() async {
    try {
      return await _database.getTodayPomodoroSessions();
    } catch (e) {
      _setError('Error obteniendo sesiones de hoy: $e');
      return [];
    }
  }

  /// Obtener sesiones por rango de fechas
  Future<List<PomodoroSession>> getSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _database.getPomodoroSessionsByDateRange(startDate, endDate);
    } catch (e) {
      _setError('Error obteniendo sesiones: $e');
      return [];
    }
  }

  /// Obtener sesiones vinculadas a una tarea
  Future<List<PomodoroSession>> getSessionsByTask(String taskId) async {
    try {
      return await _database.getPomodoroSessionsByTask(taskId);
    } catch (e) {
      _setError('Error obteniendo sesiones de tarea: $e');
      return [];
    }
  }

  /// Recargar datos manualmente
  Future<void> refresh() async {
    _setLoading(true);
    await _loadSessions();
    await _loadStats();
    _setLoading(false);
  }

  /// Resetear contador de sesiones completadas
  Future<void> resetCompletedSessions() async {
    _completedWorkSessions = 0;
    await _saveCompletedSessionsCount();
    notifyListeners();
  }

  // ==================== MÉTODOS AUXILIARES ====================

  /// Cargar contador de sesiones de hoy desde la base de datos
  Future<void> _loadCompletedSessionsCount() async {
    try {
      // Obtener sesiones de trabajo completadas HOY desde la base de datos
      final todaySessions = await _database.getTodayPomodoroSessions();
      
      // Contar solo las sesiones de TRABAJO completadas
      _completedWorkSessions = todaySessions.where((session) {
        return session.sessionType == SessionType.work && session.isCompleted;
      }).length;
      
      print('💾 Contador cargado desde BD: $_completedWorkSessions sesiones de trabajo hoy');
      
      // Guardar en SharedPreferences para respaldo
      await _saveCompletedSessionsCount();
      
      notifyListeners();
    } catch (e) {
      print('❌ Error cargando contador de sesiones: $e');
      // Fallback: intentar cargar desde SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        _completedWorkSessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;
      } catch (_) {
        _completedWorkSessions = 0;
      }
    }
  }

  /// Guardar contador de sesiones en persistencia
  Future<void> _saveCompletedSessionsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pomodoro_completed_sessions', _completedWorkSessions);
      print('💾 Contador guardado: $_completedWorkSessions');
    } catch (e) {
      print('❌ Error guardando contador de sesiones: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
