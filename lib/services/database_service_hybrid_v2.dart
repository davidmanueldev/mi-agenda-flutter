import 'dart:async';
import '../models/event.dart';
import '../models/category.dart' as model;
import '../models/task.dart';
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
  
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _tasksSubscription;
  
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
    _tasksSubscription = _firebaseService.tasksStream().listen(
      (tasks) {
        _syncTasksToLocal(tasks);
      },
      onError: (error) {
        print('Error en stream de tareas: $error');
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
      for (final category in firebaseCategories) {
        try {
          await _localService.insertCategory(category);
        } catch (e) {
          // Ignorar si ya existe
        }
      }
    } catch (e) {
      print('Error sincronizando categorías: $e');
    }
  }
  
  /// Sincronizar tareas de Firebase a SQLite
  Future<void> _syncTasksToLocal(List<Task> firebaseTasks) async {
    try {
      _updateSyncStatus(SyncStatus.syncing);
      bool hasChanges = false;
      
      final localTasks = await _localService.getAllTasks();
      final localTasksMap = {for (var t in localTasks) t.id: t};
      
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
    // SIEMPRE leer de SQLite (más rápido y funciona offline)
    return await _localService.getAllEvents();
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
    return await _localService.getEventsByDate(date);
  }
  
  @override
  Future<List<Event>> getEventsByDateRange(DateTime startDate, DateTime endDate) async {
    return await _localService.getEventsByDateRange(startDate, endDate);
  }
  
  @override
  Future<Event?> getEventById(String id) async {
    return await _localService.getEventById(id);
  }
  
  @override
  Future<List<Event>> searchEvents(String query) async {
    return await _localService.searchEvents(query);
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
  Future<List<model.Category>> getAllCategories() async {
    return await _localService.getAllCategories();
  }
  
  @override
  Future<model.Category?> getCategoryById(String id) async {
    return await _localService.getCategoryById(id);
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
  Future<List<Task>> getAllTasks() async {
    return await _localService.getAllTasks();
  }

  /// Obtener tarea por ID
  Future<Task?> getTaskById(String id) async {
    return await _localService.getTaskById(id);
  }

  /// Obtener tareas por estado
  Future<List<Task>> getTasksByStatus(TaskStatus status) async {
    return await _localService.getTasksByStatus(status);
  }

  /// Obtener tareas por prioridad
  Future<List<Task>> getTasksByPriority(TaskPriority priority) async {
    return await _localService.getTasksByPriority(priority);
  }

  /// Obtener tareas por categoría
  Future<List<Task>> getTasksByCategory(String category) async {
    return await _localService.getTasksByCategory(category);
  }

  /// Obtener tareas vencidas
  Future<List<Task>> getOverdueTasks() async {
    return await _localService.getOverdueTasks();
  }

  /// Obtener tareas de hoy
  Future<List<Task>> getTodayTasks() async {
    return await _localService.getTodayTasks();
  }

  /// Buscar tareas
  Future<List<Task>> searchTasks(String query) async {
    return await _localService.searchTasks(query);
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
    await _localService.closeDatabase();
  }
  
  /// Forzar sincronización manual
  Future<void> forceSync() async {
    if (_isOnline) {
      await _syncPendingOperations();
    }
  }
  
  /// Obtener estado de sincronización
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  int get pendingSyncCount => _syncQueue.pendingCount;
}
