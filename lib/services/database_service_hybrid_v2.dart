import 'dart:async';
import '../models/event.dart';
import '../models/category.dart' as model;
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
  
  bool _isOnline = false;
  bool _isSyncing = false;
  
  // Callbacks para notificar cambios
  Function()? onDataChanged;
  
  // Stream controller para estado de sincronización
  final StreamController<SyncStatus> _syncStatusController = 
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  SyncStatus _currentSyncStatus = SyncStatus.idle;
  
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
