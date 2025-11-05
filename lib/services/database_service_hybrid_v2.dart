import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../models/category.dart' as model;
import '../models/task.dart';
import '../models/pomodoro_session.dart';
import '../models/task_template.dart';
import 'firebase_service.dart';
import 'database_service.dart';
import 'database_interface.dart';
import 'connectivity_service.dart';
import 'sync_queue_service.dart';

/// Estado de sincronización
enum SyncStatus {
  idle,           // Sin actividad
  syncing,        // Sincronizando
  synchronized,   // Sincronizado correctamente
  error,          // Error en sincronización
}

/// Servicio híbrido mejorado con:
/// - Soporte completo offline
/// - Sincronización automática bidireccional
/// - Listeners en tiempo real de Firebase
/// - Cola de operaciones pendientes
class DatabaseServiceHybridV2 implements DatabaseInterface {
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseService _localService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncQueueService _syncQueue = SyncQueueService();
  
  /// Obtener el ID del usuario actual de Firebase Auth
  String? get _currentUserId => _firebaseService.currentUserId;
  
  /// Getter público para que los controllers puedan acceder al userId
  @override
  String? get currentUserId => _currentUserId;
  
  /// Validar que hay un usuario autenticado
  void _ensureAuthenticated() {
    if (_currentUserId == null) {
      throw Exception('⚠️  No hay usuario autenticado. Debes iniciar sesión primero.');
    }
  }
  
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _pomodoroSubscription;
  StreamSubscription? _templatesSubscription;
  
  bool _isOnline = false;
  bool _isSyncing = false;
  
  // Callbacks para notificar cambios
  Function()? onDataChanged;
  
  // Stream controller para estado de sincronización
  final StreamController<SyncStatus> _syncStatusController = 
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  SyncStatus _currentSyncStatus = SyncStatus.idle;
  
  // Getter para el estado actual de sincronización
  SyncStatus get currentSyncStatus => _currentSyncStatus;
  
  DatabaseServiceHybridV2() {
    _initialize();
  }
  
  /// Inicializar servicio
  Future<void> _initialize() async {
    // Cargar cola de sincronización
    await _syncQueue.loadQueue();
    
    // Verificar conectividad inicial
    _isOnline = await _connectivityService.checkConnectivity();
    
    // Si está online, verificar si Firebase tiene datos y limpiar cola obsoleta
    if (_isOnline) {
      await _cleanupObsoleteQueueOnStartup();
    }
    
    // Escuchar cambios de conectividad
    _connectivitySubscription = _connectivityService.connectionStream.listen((isOnline) {
      _isOnline = isOnline;
      if (isOnline && !_isSyncing) {
        _syncPendingOperations();
        _setupFirebaseListeners();
      }
    });
    
    // Si está online, configurar listeners
    if (_isOnline) {
      _setupFirebaseListeners();
    }
  }
  
  /// Configurar listeners en tiempo real de Firebase
  void _setupFirebaseListeners() {
    // Listener para eventos
    _eventsSubscription = _firebaseService.getEventsStream().listen(
      (events) {
        _syncFirebaseToLocal(events);
      },
      onError: (error) {
        print('Error en stream de eventos: $error');
      },
    );
    
    // Listener para categorías
    _categoriesSubscription = _firebaseService.getCategoriesStream().listen(
      (categories) {
        _syncCategoriesToLocal(categories);
      },
      onError: (error) {
        print('Error en stream de categorías: $error');
      },
    );
    
    // Listener para tareas
    _tasksSubscription = _firebaseService.getTasksStream().listen(
      (tasks) {
        print('✅ TASKS LISTENER: Recibidas ${tasks.length} tareas de Firebase');
        _syncTasksToLocal(tasks);
      },
      onError: (error) {
        print('❌ ERROR EN STREAM DE TAREAS: $error');
        print('⚠️  SI VES "failed-precondition" o "requires an index", EL ÍNDICE NO ESTÁ FUNCIONANDO');
      },
    );
    
    // Listener para sesiones Pomodoro
    _pomodoroSubscription = _firebaseService.getPomodoroSessionsStream().listen(
      (sessions) {
        print('✅ POMODORO LISTENER: Recibidas ${sessions.length} sesiones de Firebase');
        _syncPomodoroToLocal(sessions);
      },
      onError: (error) {
        print('❌ ERROR EN STREAM DE POMODORO: $error');
        print('⚠️  SI VES "failed-precondition" o "requires an index", EL ÍNDICE NO ESTÁ FUNCIONANDO');
      },
    );
  }
  
  /// Sincronizar eventos de Firebase a SQLite
  Future<void> _syncFirebaseToLocal(List<Event> firebaseEvents) async {
    try {
      _updateSyncStatus(SyncStatus.syncing);
      bool hasChanges = false;
      
      final localEvents = await _localService.getAllEvents();
      final localEventsMap = {for (var e in localEvents) e.id: e};
      
      // Actualizar o insertar eventos de Firebase en SQLite
      for (final firebaseEvent in firebaseEvents) {
        final localEvent = localEventsMap[firebaseEvent.id];
        
        if (localEvent == null) {
          // No existe localmente, insertar
          await _localService.insertEvent(firebaseEvent);
          print('✅ Nuevo evento desde Firebase: ${firebaseEvent.title}');
          hasChanges = true;
        } else if (_hasEventChanged(localEvent, firebaseEvent)) {
          // Detectar si hay diferencias en el contenido
          await _localService.updateEvent(firebaseEvent);
          print('🔄 Evento actualizado desde Firebase: ${firebaseEvent.title}');
          hasChanges = true;
        }
        
        localEventsMap.remove(firebaseEvent.id);
      }
      
      // Los eventos que quedaron en el map local no están en Firebase
      // Esto significa que fueron borrados en Firebase
      for (final orphanEvent in localEventsMap.values) {
        await _localService.deleteEvent(orphanEvent.id);
        print('🗑️ Eliminado evento desde Firebase: ${orphanEvent.title}');
        hasChanges = true;
      }
      
      // Notificar cambios al UI
      if (hasChanges && onDataChanged != null) {
        onDataChanged!();
      }
      
      _updateSyncStatus(SyncStatus.synchronized);
      
    } catch (e) {
      print('Error sincronizando Firebase -> Local: $e');
      _updateSyncStatus(SyncStatus.error);
    }
  }
  
  /// Verificar si un evento cambió comparando sus campos
  bool _hasEventChanged(Event local, Event firebase) {
    return local.title != firebase.title ||
           local.description != firebase.description ||
           local.startTime != firebase.startTime ||
           local.endTime != firebase.endTime ||
           local.category != firebase.category ||
           local.isCompleted != firebase.isCompleted ||
           firebase.updatedAt.isAfter(local.updatedAt);
  }
  
  /// Sincronizar categorías de Firebase a SQLite
  Future<void> _syncCategoriesToLocal(List<model.Category> firebaseCategories) async {
    try {
      print('🔄 Iniciando sincronización de categorías...');
      print('📦 Categorías en Firebase: ${firebaseCategories.length}');
      
      _updateSyncStatus(SyncStatus.syncing);
      bool hasChanges = false;
      
      // Si Firebase tiene datos, limpiar operaciones de creación de categorías pendientes
      // porque Firebase es la fuente de verdad
      if (firebaseCategories.isNotEmpty) {
        await _cleanupCategoryCreateOperations();
      }
      
      // Obtener categorías locales para comparar
      final localCategories = await _localService.getAllCategories();
      print('📱 Categorías locales: ${localCategories.length}');
      final localCategoriesMap = {for (var c in localCategories) c.id: c};
      
      // Sincronizar categorías de Firebase a SQLite
      for (final firebaseCategory in firebaseCategories) {
        final localCategory = localCategoriesMap[firebaseCategory.id];
        
        if (localCategory == null) {
          // Categoría nueva en Firebase, agregar localmente
          print('➕ Nueva categoría desde Firebase: ${firebaseCategory.name}');
          await _localService.insertCategory(firebaseCategory);
          hasChanges = true;
        } else if (_hasCategoryChanged(localCategory, firebaseCategory)) {
          // Categoría modificada en Firebase, actualizar localmente
          print('🔄 Actualizando categoría desde Firebase: ${firebaseCategory.name}');
          await _localService.updateCategory(firebaseCategory);
          hasChanges = true;
        } else {
          print('✓ Categoría sin cambios: ${firebaseCategory.name}');
        }
        
        // Remover del map para identificar categorías eliminadas
        localCategoriesMap.remove(firebaseCategory.id);
      }
      
      // Las categorías que quedan en el map fueron eliminadas en Firebase
      for (final deletedCategory in localCategoriesMap.values) {
        print('⚠️ Eliminando categoría eliminada en Firebase: ${deletedCategory.name}');
        try {
          // Eliminar directamente sin verificar eventos asociados (sincronización forzada)
          final db = await _localService.database;
          await db.delete(
            'categories',
            where: 'id = ?',
            whereArgs: [deletedCategory.id],
          );
          hasChanges = true;
          print('✅ Categoría ${deletedCategory.name} eliminada exitosamente');
        } catch (e) {
          print('❌ No se pudo eliminar categoría ${deletedCategory.name}: $e');
        }
      }
      
      if (hasChanges) {
        print('✅ Sincronización de categorías completada con cambios');
        onDataChanged?.call();
        _updateSyncStatus(SyncStatus.synchronized);
      } else {
        print('✅ Sincronización de categorías completada sin cambios');
      }
    } catch (e) {
      print('❌ Error sincronizando categorías: $e');
      _updateSyncStatus(SyncStatus.error);
    }
  }
  
  /// Verificar si una categoría cambió
  bool _hasCategoryChanged(model.Category local, model.Category firebase) {
    return local.name != firebase.name ||
           local.description != firebase.description ||
           local.color.value != firebase.color.value ||
           local.icon.codePoint != firebase.icon.codePoint;
  }
  
  /// Sincronizar tareas de Firebase a SQLite
  Future<void> _syncTasksToLocal(List<Task> firebaseTasks) async {
    try {
      print('🔄 ✅ TASKS INDEX WORKING: Iniciando sincronización de tareas...');
      print('📦 ✅ TASKS: Tareas en Firebase: ${firebaseTasks.length}');
      
      _updateSyncStatus(SyncStatus.syncing);
      bool hasChanges = false;
      
      final localTasks = await _localService.getAllTasks();
      final localTasksMap = {for (var t in localTasks) t.id: t};
      
      print('📱 ✅ TASKS: Tareas locales: ${localTasks.length}');
      
      // Actualizar o insertar tareas de Firebase en SQLite
      for (final firebaseTask in firebaseTasks) {
        final localTask = localTasksMap[firebaseTask.id];
        
        if (localTask == null) {
          // No existe localmente, insertar
          await _localService.insertTask(firebaseTask);
          print('✅ Nueva tarea desde Firebase: ${firebaseTask.title}');
          hasChanges = true;
        } else if (_hasTaskChanged(localTask, firebaseTask)) {
          // Detectar si hay diferencias en el contenido
          await _localService.updateTask(firebaseTask);
          print('🔄 Tarea actualizada desde Firebase: ${firebaseTask.title}');
          hasChanges = true;
        }
        
        localTasksMap.remove(firebaseTask.id);
      }
      
      // Las tareas que quedaron en el map local no están en Firebase
      // Esto significa que fueron borradas en Firebase
      for (final orphanTask in localTasksMap.values) {
        await _localService.deleteTask(orphanTask.id);
        print('🗑️ Eliminada tarea desde Firebase: ${orphanTask.title}');
        hasChanges = true;
      }
      
      // Notificar cambios al UI
      if (hasChanges && onDataChanged != null) {
        onDataChanged!();
      }
      
      _updateSyncStatus(SyncStatus.synchronized);
      
    } catch (e) {
      print('Error sincronizando tareas Firebase -> Local: $e');
      _updateSyncStatus(SyncStatus.error);
    }
  }
  
  /// Verificar si una tarea cambió comparando sus campos
  bool _hasTaskChanged(Task local, Task firebase) {
    return local.title != firebase.title ||
           local.description != firebase.description ||
           local.dueDate != firebase.dueDate ||
           local.category != firebase.category ||
           local.priority != firebase.priority ||
           local.status != firebase.status ||
           local.steps.length != firebase.steps.length ||
           firebase.updatedAt.isAfter(local.updatedAt);
  }
  
  /// Sincronizar sesiones Pomodoro de Firebase a SQLite
  Future<void> _syncPomodoroToLocal(List<PomodoroSession> firebaseSessions) async {
    try {
      print('🔄 ✅ POMODORO INDEX WORKING: Iniciando sincronización de sesiones...');
      print('📦 ✅ POMODORO: Sesiones en Firebase: ${firebaseSessions.length}');
      
      _updateSyncStatus(SyncStatus.syncing);
      bool hasChanges = false;
      
      final localSessions = await _localService.getAllPomodoroSessions();
      final localSessionsMap = {for (var s in localSessions) s.id: s};
      
      print('📱 ✅ POMODORO: Sesiones locales: ${localSessions.length}');
      
      // Actualizar o insertar sesiones de Firebase en SQLite
      for (final firebaseSession in firebaseSessions) {
        final localSession = localSessionsMap[firebaseSession.id];
        
        if (localSession == null) {
          // No existe localmente, insertar
          await _localService.insertPomodoroSession(firebaseSession);
          print('✅ Nueva sesión Pomodoro desde Firebase: ${firebaseSession.sessionType}');
          hasChanges = true;
        } else if (_hasPomodoroSessionChanged(localSession, firebaseSession)) {
          // Detectar si hay diferencias en el contenido
          await _localService.updatePomodoroSession(firebaseSession);
          print('🔄 Sesión Pomodoro actualizada desde Firebase: ${firebaseSession.sessionType}');
          hasChanges = true;
        }
        
        localSessionsMap.remove(firebaseSession.id);
      }
      
      // Las sesiones que quedaron en el map local no están en Firebase
      // Esto significa que fueron borradas en Firebase
      for (final orphanSession in localSessionsMap.values) {
        await _localService.deletePomodoroSession(orphanSession.id);
        print('🗑️ Eliminada sesión Pomodoro desde Firebase');
        hasChanges = true;
      }
      
      // Limpiar operaciones obsoletas de createPomodoroSession del queue
      if (firebaseSessions.isNotEmpty) {
        print('🔍 Firebase tiene ${firebaseSessions.length} sesiones. Limpiando operaciones de creación local obsoletas...');
        final queue = _syncQueue.getQueue();
        for (final item in queue) {
          if (item.operation == SyncOperation.createPomodoroSession) {
            await _syncQueue.removeFromQueue(item.id);
            print('🧹 Limpiada operación de createPomodoroSession obsoleta del queue');
          }
        }
      }
      
      // Notificar cambios al UI
      if (hasChanges && onDataChanged != null) {
        onDataChanged!();
      }
      
      _updateSyncStatus(SyncStatus.synchronized);
      
    } catch (e) {
      print('Error sincronizando sesiones Pomodoro Firebase -> Local: $e');
      _updateSyncStatus(SyncStatus.error);
    }
  }
  
  /// Verificar si una sesión Pomodoro cambió
  bool _hasPomodoroSessionChanged(PomodoroSession local, PomodoroSession firebase) {
    return local.sessionType != firebase.sessionType ||
           local.duration != firebase.duration ||
           local.startTime != firebase.startTime ||
           local.endTime != firebase.endTime ||
           local.taskId != firebase.taskId ||
           firebase.updatedAt.isAfter(local.updatedAt);
  }
  
  /// Sincronizar operaciones pendientes cuando hay conexión
  Future<void> _syncPendingOperations() async {
    if (_isSyncing || !_isOnline) return;
    
    _isSyncing = true;
    _updateSyncStatus(SyncStatus.syncing);
    print('Iniciando sincronización de ${_syncQueue.pendingCount} operaciones pendientes...');
    
    try {
      final queue = _syncQueue.getQueue();
      
      for (final item in queue) {
        try {
          switch (item.operation) {
            case SyncOperation.createEvent:
              final event = Event.fromJson(item.data);
              await _firebaseService.createEvent(event);
              break;
              
            case SyncOperation.updateEvent:
              final event = Event.fromJson(item.data);
              await _firebaseService.updateEvent(event);
              break;
              
            case SyncOperation.deleteEvent:
              await _firebaseService.deleteEvent(item.data['id']);
              break;
              
            case SyncOperation.createCategory:
              final category = model.Category.fromJson(item.data);
              await _firebaseService.createCategory(category);
              break;
              
            case SyncOperation.updateCategory:
              final category = model.Category.fromJson(item.data);
              await _firebaseService.updateCategory(category);
              break;
              
            case SyncOperation.deleteCategory:
              await _firebaseService.deleteCategory(item.data['id']);
              break;
              
            case SyncOperation.createTask:
              final task = Task.fromJson(item.data);
              await _firebaseService.createTask(task);
              break;
              
            case SyncOperation.updateTask:
              final task = Task.fromJson(item.data);
              await _firebaseService.updateTask(task);
              break;
              
            case SyncOperation.deleteTask:
              await _firebaseService.deleteTask(item.data['id']);
              break;
              
            case SyncOperation.createPomodoroSession:
              final session = PomodoroSession.fromMap(item.data);
              await _firebaseService.createPomodoroSession(session);
              break;
              
            case SyncOperation.updatePomodoroSession:
              final session = PomodoroSession.fromMap(item.data);
              await _firebaseService.updatePomodoroSession(session);
              break;
              
            case SyncOperation.deletePomodoroSession:
              await _firebaseService.deletePomodoroSession(item.data['id']);
              break;
          }
          
          // Si tuvo éxito, remover de la cola
          await _syncQueue.removeFromQueue(item.id);
          print('Sincronizado: ${item.operation}');
          
        } catch (e) {
          print('Error sincronizando ${item.operation}: $e');
          _updateSyncStatus(SyncStatus.error);
          // Mantener en cola para reintentar después
        }
      }
      
      print('Sincronización completada');
      _updateSyncStatus(SyncStatus.synchronized);
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Actualizar estado de sincronización
  void _updateSyncStatus(SyncStatus status) {
    _currentSyncStatus = status;
    _syncStatusController.add(status);
  }
  
  /// Limpiar operaciones de creación de categorías de la cola cuando Firebase tiene datos
  /// Firebase es la fuente de verdad, por lo que las categorías locales deben ser eliminadas
  Future<void> _cleanupCategoryCreateOperations() async {
    final queue = _syncQueue.getQueue();
    final categoryCreateOps = queue.where(
      (item) => item.operation == SyncOperation.createCategory
    ).toList();
    
    if (categoryCreateOps.isNotEmpty) {
      print('🧹 Limpiando ${categoryCreateOps.length} operaciones obsoletas de creación de categorías...');
      for (final op in categoryCreateOps) {
        await _syncQueue.removeFromQueue(op.id);
        print('   ✓ Removida operación obsoleta: ${op.data['name']}');
      }
    }
  }
  
  /// Limpiar operaciones obsoletas de la cola al iniciar
  /// Si Firebase tiene datos, las operaciones de creación local son obsoletas
  Future<void> _cleanupObsoleteQueueOnStartup() async {
    try {
      // Verificar si Firebase tiene categorías
      final firebaseCategories = await _firebaseService.getAllCategories();
      
      if (firebaseCategories.isNotEmpty) {
        print('🔍 Firebase tiene ${firebaseCategories.length} categorías. Limpiando operaciones de creación local obsoletas...');
        await _cleanupCategoryCreateOperations();
      }
    } catch (e) {
      print('Error al limpiar cola obsoleta: $e');
    }
  }
  
  // ==================== OPERACIONES DE EVENTOS ====================
  
  @override
  Future<int> insertEvent(Event event) async {
    // SIEMPRE guardar en SQLite primero (para modo offline)
    await _localService.insertEvent(event);
    
    // Si está online, intentar Firebase
    if (_isOnline) {
      try {
        await _firebaseService.createEvent(event);
      } catch (e) {
        print('Firebase falló, agregando a cola: $e');
        await _syncQueue.addToQueue(SyncOperation.createEvent, event.toJson());
      }
    } else {
      // Offline: agregar a cola
      await _syncQueue.addToQueue(SyncOperation.createEvent, event.toJson());
    }
    
    return 1;
  }
  
  @override
  Future<List<Event>> getAllEvents() async {
    _ensureAuthenticated();
    
    // SIEMPRE leer de SQLite (más rápido y funciona offline)
    final allEvents = await _localService.getAllEvents();
    
    // Filtrar solo los eventos del usuario actual
    return allEvents.where((event) => event.userId == _currentUserId).toList();
  }
  
  @override
  Future<int> updateEvent(Event event) async {
    // Actualizar en SQLite
    await _localService.updateEvent(event);
    
    // Si está online, intentar Firebase
    if (_isOnline) {
      try {
        await _firebaseService.updateEvent(event);
      } catch (e) {
        print('Firebase falló, agregando a cola: $e');
        await _syncQueue.addToQueue(SyncOperation.updateEvent, event.toJson());
      }
    } else {
      // Offline: agregar a cola
      await _syncQueue.addToQueue(SyncOperation.updateEvent, event.toJson());
    }
    
    return 1;
  }
  
  @override
  Future<int> deleteEvent(String eventId) async {
    // Eliminar de SQLite
    await _localService.deleteEvent(eventId);
    
    // Si está online, intentar Firebase
    if (_isOnline) {
      try {
        await _firebaseService.deleteEvent(eventId);
      } catch (e) {
        print('Firebase falló, agregando a cola: $e');
        await _syncQueue.addToQueue(
          SyncOperation.deleteEvent,
          {'id': eventId},
        );
      }
    } else {
      // Offline: agregar a cola
      await _syncQueue.addToQueue(
        SyncOperation.deleteEvent,
        {'id': eventId},
      );
    }
    
    return 1;
  }
  
  @override
  Future<List<Event>> getEventsByDate(DateTime date) async {
    _ensureAuthenticated();
    
    final events = await _localService.getEventsByDate(date);
    
    // Filtrar solo los eventos del usuario actual
    return events.where((event) => event.userId == _currentUserId).toList();
  }
  
  @override
  Future<List<Event>> getEventsByDateRange(DateTime startDate, DateTime endDate) async {
    _ensureAuthenticated();
    
    final events = await _localService.getEventsByDateRange(startDate, endDate);
    
    // Filtrar solo los eventos del usuario actual
    return events.where((event) => event.userId == _currentUserId).toList();
  }
  
  @override
  Future<Event?> getEventById(String id) async {
    _ensureAuthenticated();
    
    final event = await _localService.getEventById(id);
    
    // Verificar que el evento pertenece al usuario actual
    if (event != null && event.userId != _currentUserId) {
      return null; // No tiene permiso para ver este evento
    }
    
    return event;
  }
  
  @override
  Future<List<Event>> searchEvents(String query) async {
    _ensureAuthenticated();
    
    final events = await _localService.searchEvents(query);
    
    // Filtrar solo los eventos del usuario actual
    return events.where((event) => event.userId == _currentUserId).toList();
  }
  
  // ==================== OPERACIONES DE CATEGORÍAS ====================
  
  @override
  Future<int> insertCategory(model.Category category) async {
    // Insertar en SQLite
    await _localService.insertCategory(category);
    
    // Si está online, intentar Firebase
    if (_isOnline) {
      try {
        await _firebaseService.createCategory(category);
      } catch (e) {
        print('Firebase falló, agregando a cola: $e');
        await _syncQueue.addToQueue(SyncOperation.createCategory, category.toJson());
      }
    } else {
      await _syncQueue.addToQueue(SyncOperation.createCategory, category.toJson());
    }
    
    return 1;
  }
  
  @override
  Future<int> updateCategory(model.Category category) async {
    // Actualizar en SQLite
    await _localService.updateCategory(category);
    
    // Si está online, intentar Firebase
    if (_isOnline) {
      try {
        await _firebaseService.updateCategory(category);
      } catch (e) {
        print('Firebase falló, agregando a cola: $e');
        await _syncQueue.addToQueue(SyncOperation.updateCategory, category.toJson());
      }
    } else {
      await _syncQueue.addToQueue(SyncOperation.updateCategory, category.toJson());
    }
    
    return 1;
  }
  
  @override
  Future<List<model.Category>> getAllCategories() async {
    _ensureAuthenticated();
    
    final allCategories = await _localService.getAllCategories();
    
    // Filtrar: categorías del usuario actual + categorías del sistema (userId == null)
    return allCategories.where((category) => 
      category.userId == null || category.userId == _currentUserId
    ).toList();
  }
  
  @override
  Future<model.Category?> getCategoryById(String id) async {
    _ensureAuthenticated();
    
    final category = await _localService.getCategoryById(id);
    
    // Verificar que la categoría pertenece al usuario o es del sistema
    if (category != null && 
        category.userId != null && 
        category.userId != _currentUserId) {
      return null; // No tiene permiso para ver esta categoría
    }
    
    return category;
  }
  
  @override
  Future<int> deleteCategory(String categoryId) async {
    await _localService.deleteCategory(categoryId);
    
    if (_isOnline) {
      try {
        await _firebaseService.deleteCategory(categoryId);
      } catch (e) {
        await _syncQueue.addToQueue(
          SyncOperation.deleteCategory,
          {'id': categoryId},
        );
      }
    } else {
      await _syncQueue.addToQueue(
        SyncOperation.deleteCategory,
        {'id': categoryId},
      );
    }
    
    return 1;
  }
  
  // ==================== OPERACIONES DE TAREAS ====================

  /// Insertar nueva tarea (offline-first)
  @override
  Future<int> insertTask(Task task) async {
    // SIEMPRE guardar en SQLite primero
    await _localService.insertTask(task);
    
    // Si está online, intentar Firebase
    if (_isOnline) {
      try {
        await _firebaseService.createTask(task);
      } catch (e) {
        await _syncQueue.addToQueue(SyncOperation.createTask, task.toJson());
      }
    } else {
      await _syncQueue.addToQueue(SyncOperation.createTask, task.toJson());
    }
    
    return 1;
  }

  /// Actualizar tarea existente (offline-first)
  @override
  Future<int> updateTask(Task task) async {
    await _localService.updateTask(task);
    
    if (_isOnline) {
      try {
        await _firebaseService.updateTask(task);
      } catch (e) {
        await _syncQueue.addToQueue(SyncOperation.updateTask, task.toJson());
      }
    } else {
      await _syncQueue.addToQueue(SyncOperation.updateTask, task.toJson());
    }
    
    return 1;
  }

  /// Eliminar tarea (offline-first)
  @override
  Future<int> deleteTask(String taskId) async {
    await _localService.deleteTask(taskId);
    
    if (_isOnline) {
      try {
        await _firebaseService.deleteTask(taskId);
      } catch (e) {
        await _syncQueue.addToQueue(
          SyncOperation.deleteTask,
          {'id': taskId},
        );
      }
    } else {
      await _syncQueue.addToQueue(
        SyncOperation.deleteTask,
        {'id': taskId},
      );
    }
    
    return 1;
  }

  /// Obtener todas las tareas
  @override
  Future<List<Task>> getAllTasks() async {
    _ensureAuthenticated();
    
    final tasks = await _localService.getAllTasks();
    
    // Filtrar solo las tareas del usuario actual
    return tasks.where((task) => task.userId == _currentUserId).toList();
  }

  /// Obtener tarea por ID
  @override
  Future<Task?> getTaskById(String id) async {
    _ensureAuthenticated();
    
    final task = await _localService.getTaskById(id);
    
    // Verificar que la tarea pertenece al usuario actual
    if (task != null && task.userId != _currentUserId) {
      return null; // No tiene permiso para ver esta tarea
    }
    
    return task;
  }

  /// Obtener tareas por estado
  @override
  Future<List<Task>> getTasksByStatus(TaskStatus status) async {
    _ensureAuthenticated();
    
    final tasks = await _localService.getTasksByStatus(status);
    
    // Filtrar solo las tareas del usuario actual
    return tasks.where((task) => task.userId == _currentUserId).toList();
  }

  /// Obtener tareas por prioridad
  @override
  Future<List<Task>> getTasksByPriority(TaskPriority priority) async {
    _ensureAuthenticated();
    
    final tasks = await _localService.getTasksByPriority(priority);
    
    // Filtrar solo las tareas del usuario actual
    return tasks.where((task) => task.userId == _currentUserId).toList();
  }

  /// Obtener tareas por categoría
  @override
  Future<List<Task>> getTasksByCategory(String category) async {
    _ensureAuthenticated();
    
    final tasks = await _localService.getTasksByCategory(category);
    
    // Filtrar solo las tareas del usuario actual
    return tasks.where((task) => task.userId == _currentUserId).toList();
  }

  /// Obtener tareas vencidas
  @override
  Future<List<Task>> getOverdueTasks() async {
    _ensureAuthenticated();
    
    final tasks = await _localService.getOverdueTasks();
    
    // Filtrar solo las tareas del usuario actual
    return tasks.where((task) => task.userId == _currentUserId).toList();
  }

  /// Obtener tareas de hoy
  @override
  Future<List<Task>> getTodayTasks() async {
    _ensureAuthenticated();
    
    final tasks = await _localService.getTodayTasks();
    
    // Filtrar solo las tareas del usuario actual
    return tasks.where((task) => task.userId == _currentUserId).toList();
  }

  /// Buscar tareas
  @override
  Future<List<Task>> searchTasks(String query) async {
    _ensureAuthenticated();
    
    final tasks = await _localService.searchTasks(query);
    
    // Filtrar solo las tareas del usuario actual
    return tasks.where((task) => task.userId == _currentUserId).toList();
  }

  /// Marcar tarea como completada
  Future<int> completeTask(String taskId) async {
    await _localService.completeTask(taskId);
    
    if (_isOnline) {
      try {
        await _firebaseService.completeTask(taskId);
      } catch (e) {
        // La tarea ya está marcada localmente, se sincronizará después
        final task = await _localService.getTaskById(taskId);
        if (task != null) {
          await _syncQueue.addToQueue(SyncOperation.updateTask, task.toJson());
        }
      }
    }
    
    return 1;
  }

  /// Archivar tarea
  Future<int> archiveTask(String taskId) async {
    await _localService.archiveTask(taskId);
    
    if (_isOnline) {
      try {
        await _firebaseService.archiveTask(taskId);
      } catch (e) {
        // La tarea ya está archivada localmente, se sincronizará después
        final task = await _localService.getTaskById(taskId);
        if (task != null) {
          await _syncQueue.addToQueue(SyncOperation.updateTask, task.toJson());
        }
      }
    }
    
    return 1;
  }

  // ==================== OTROS MÉTODOS ====================
  
  @override
  Future<Map<String, int>> getDatabaseStats() async {
    return await _localService.getDatabaseStats();
  }
  
  @override
  Future<int> cleanupOldEvents() async {
    final localDeleted = await _localService.cleanupOldEvents();
    
    if (_isOnline) {
      try {
        await _firebaseService.cleanupOldEvents();
      } catch (e) {
        print('Error limpiando eventos en Firebase: $e');
      }
    }
    
    return localDeleted;
  }
  
  @override
  Future<void> closeDatabase() async {
    await _connectivitySubscription?.cancel();
    await _eventsSubscription?.cancel();
    await _categoriesSubscription?.cancel();
    await _tasksSubscription?.cancel();
    await _pomodoroSubscription?.cancel();
    await _templatesSubscription?.cancel();
    await _localService.closeDatabase();
  }
  
  /// Forzar sincronización manual
  Future<void> forceSync() async {
    if (_isOnline) {
      await _syncPendingOperations();
    }
  }
  
  // ==================== OPERACIONES DE POMODORO ====================
  
  @override
  Future<int> insertPomodoroSession(PomodoroSession session) async {
    // Guardar primero en SQLite
    final result = await _localService.insertPomodoroSession(session);
    
    // Intentar sincronizar con Firebase
    if (_isOnline) {
      try {
        await _firebaseService.createPomodoroSession(session);
      } catch (e) {
        // Si falla, agregar a cola
        await _syncQueue.addToQueue(
          SyncOperation.createPomodoroSession,
          session.toMap(),
        );
      }
    } else {
      // Sin conexión, agregar a cola
      await _syncQueue.addToQueue(
        SyncOperation.createPomodoroSession,
        session.toMap(),
      );
    }
    
    return result;
  }
  
  @override
  Future<int> updatePomodoroSession(PomodoroSession session) async {
    // Actualizar en SQLite
    final result = await _localService.updatePomodoroSession(session);
    
    // Intentar sincronizar con Firebase
    if (_isOnline) {
      try {
        await _firebaseService.updatePomodoroSession(session);
      } catch (e) {
        await _syncQueue.addToQueue(
          SyncOperation.updatePomodoroSession,
          session.toMap(),
        );
      }
    } else {
      await _syncQueue.addToQueue(
        SyncOperation.updatePomodoroSession,
        session.toMap(),
      );
    }
    
    return result;
  }
  
  @override
  Future<int> deletePomodoroSession(String id) async {
    // Eliminar de SQLite
    final result = await _localService.deletePomodoroSession(id);
    
    // Intentar sincronizar con Firebase
    if (_isOnline) {
      try {
        await _firebaseService.deletePomodoroSession(id);
      } catch (e) {
        await _syncQueue.addToQueue(
          SyncOperation.deletePomodoroSession,
          {'id': id},
        );
      }
    } else {
      await _syncQueue.addToQueue(
        SyncOperation.deletePomodoroSession,
        {'id': id},
      );
    }
    
    return result;
  }
  
  @override
  Future<List<PomodoroSession>> getAllPomodoroSessions() async {
    _ensureAuthenticated();
    
    final sessions = await _localService.getAllPomodoroSessions();
    
    // Filtrar solo las sesiones del usuario actual
    return sessions.where((session) => session.userId == _currentUserId).toList();
  }
  
  @override
  Future<PomodoroSession?> getPomodoroSessionById(String id) async {
    _ensureAuthenticated();
    
    final session = await _localService.getPomodoroSessionById(id);
    
    // Verificar que la sesión pertenece al usuario actual
    if (session != null && session.userId != _currentUserId) {
      return null; // No tiene permiso para ver esta sesión
    }
    
    return session;
  }
  
  @override
  Future<List<PomodoroSession>> getPomodoroSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    _ensureAuthenticated();
    
    final sessions = await _localService.getPomodoroSessionsByDateRange(startDate, endDate);
    
    // Filtrar solo las sesiones del usuario actual
    return sessions.where((session) => session.userId == _currentUserId).toList();
  }
  
  @override
  Future<List<PomodoroSession>> getTodayPomodoroSessions() async {
    _ensureAuthenticated();
    
    final sessions = await _localService.getTodayPomodoroSessions();
    
    // Filtrar solo las sesiones del usuario actual
    return sessions.where((session) => session.userId == _currentUserId).toList();
  }
  
  @override
  Future<List<PomodoroSession>> getPomodoroSessionsByTask(String taskId) async {
    _ensureAuthenticated();
    
    final sessions = await _localService.getPomodoroSessionsByTask(taskId);
    
    // Filtrar solo las sesiones del usuario actual
    return sessions.where((session) => session.userId == _currentUserId).toList();
  }
  
  @override
  Future<Map<String, dynamic>> getPomodoroStats() async {
    return await _localService.getPomodoroStats();
  }
  
  // ==================== OPERACIONES DE TEMPLATES ====================
  
  @override
  Future<int> insertTaskTemplate(TaskTemplate template) async {
    // Guardar localmente primero
    final result = await _localService.insertTaskTemplate(template);
    
    // Intentar sincronizar con Firebase si estamos online
    if (_isOnline) {
      try {
        await _firebaseService.createTaskTemplate(template);
        debugPrint('✅ Template sincronizado con Firebase: ${template.name}');
      } catch (e) {
        debugPrint('⚠️ Error al sincronizar template con Firebase: $e');
        // Agregar a cola de sincronización
        await _syncQueue.addToQueue(
          SyncOperation.createTask, // Reutilizamos esta operación
          template.toJson(),
        );
      }
    } else {
      // Si estamos offline, agregar a la cola
      await _syncQueue.addToQueue(
        SyncOperation.createTask,
        template.toJson(),
      );
    }
    
    return result;
  }
  
  @override
  Future<int> updateTaskTemplate(TaskTemplate template) async {
    final result = await _localService.updateTaskTemplate(template);
    
    if (_isOnline) {
      try {
        await _firebaseService.updateTaskTemplate(template);
        debugPrint('✅ Template actualizado en Firebase: ${template.name}');
      } catch (e) {
        debugPrint('⚠️ Error al actualizar template en Firebase: $e');
        await _syncQueue.addToQueue(
          SyncOperation.updateTask,
          template.toJson(),
        );
      }
    } else {
      await _syncQueue.addToQueue(
        SyncOperation.updateTask,
        template.toJson(),
      );
    }
    
    return result;
  }
  
  @override
  Future<int> deleteTaskTemplate(String templateId) async {
    final result = await _localService.deleteTaskTemplate(templateId);
    
    if (_isOnline) {
      try {
        await _firebaseService.deleteTaskTemplate(templateId);
        debugPrint('✅ Template eliminado de Firebase: $templateId');
      } catch (e) {
        debugPrint('⚠️ Error al eliminar template de Firebase: $e');
        await _syncQueue.addToQueue(
          SyncOperation.deleteTask,
          {'id': templateId},
        );
      }
    } else {
      await _syncQueue.addToQueue(
        SyncOperation.deleteTask,
        {'id': templateId},
      );
    }
    
    return result;
  }
  
  @override
  Future<List<TaskTemplate>> getAllTaskTemplates() async {
    _ensureAuthenticated();
    
    final templates = await _localService.getAllTaskTemplates();
    
    // Filtrar solo los templates del usuario actual
    return templates.where((template) => template.userId == _currentUserId).toList();
  }
  
  @override
  Future<TaskTemplate?> getTaskTemplateById(String id) async {
    _ensureAuthenticated();
    
    final template = await _localService.getTaskTemplateById(id);
    
    // Verificar que el template pertenece al usuario actual
    if (template != null && template.userId != _currentUserId) {
      return null; // No tiene permiso para ver este template
    }
    
    return template;
  }
  
  /// Obtener estado de sincronización
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  int get pendingSyncCount => _syncQueue.pendingCount;
}
