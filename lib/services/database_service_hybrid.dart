import '../models/event.dart';
import '../models/category.dart' as model;
import 'firebase_service.dart';
import 'database_service.dart';
import 'database_interface.dart';

/// Servicio híbrido que combina Firebase (principal) con SQLite (backup)
/// Implementa fallback automático y sincronización
class DatabaseServiceHybrid implements DatabaseInterface {
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseService _localService = DatabaseService();
  
  bool _useFirebase = true;
  
  @override
  String? get currentUserId => _firebaseService.currentUserId;
  
  /// Alternar entre Firebase y SQLite
  void setUseFirebase(bool useFirebase) {
    _useFirebase = useFirebase;
  }

  // ==================== OPERACIONES DE EVENTOS ====================

  /// Insertar evento (Firebase principal, SQLite backup)
  @override
  Future<int> insertEvent(Event event) async {
    try {
      if (_useFirebase) {
        await _firebaseService.createEvent(event);
        // Backup en SQLite
        try {
          await _localService.insertEvent(event);
        } catch (e) {
          print('Warning: Backup local falló: $e');
        }
        return 1;
      } else {
        return await _localService.insertEvent(event);
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.insertEvent(event);
      }
      rethrow;
    }
  }

  /// Obtener todos los eventos
  @override
  Future<List<Event>> getAllEvents() async {
    try {
      if (_useFirebase) {
        final events = await _firebaseService.getAllEvents();
        
        // Sincronizar con backup local
        _syncWithLocal(events);
        
        return events;
      } else {
        return await _localService.getAllEvents();
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.getAllEvents();
      }
      rethrow;
    }
  }

  /// Actualizar evento
  @override
  Future<int> updateEvent(Event event) async {
    try {
      if (_useFirebase) {
        await _firebaseService.updateEvent(event);
        // Backup en SQLite
        try {
          await _localService.updateEvent(event);
        } catch (e) {
          print('Warning: Backup local falló: $e');
        }
        return 1;
      } else {
        return await _localService.updateEvent(event);
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.updateEvent(event);
      }
      rethrow;
    }
  }

  /// Eliminar evento
  @override
  Future<int> deleteEvent(String eventId) async {
    try {
      if (_useFirebase) {
        await _firebaseService.deleteEvent(eventId);
        // Backup en SQLite
        try {
          await _localService.deleteEvent(eventId);
        } catch (e) {
          print('Warning: Backup local falló: $e');
        }
        return 1;
      } else {
        return await _localService.deleteEvent(eventId);
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.deleteEvent(eventId);
      }
      rethrow;
    }
  }

  /// Obtener eventos por fecha
  @override
  Future<List<Event>> getEventsByDate(DateTime date) async {
    try {
      if (_useFirebase) {
        return await _firebaseService.getEventsByDate(date);
      } else {
        return await _localService.getEventsByDate(date);
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.getEventsByDate(date);
      }
      rethrow;
    }
  }

  /// Obtener eventos por rango de fechas
  @override
  Future<List<Event>> getEventsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      if (_useFirebase) {
        return await _firebaseService.getEventsByDateRange(startDate, endDate);
      } else {
        return await _localService.getEventsByDateRange(startDate, endDate);
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.getEventsByDateRange(startDate, endDate);
      }
      rethrow;
    }
  }

  /// Obtener evento por ID
  @override
  Future<Event?> getEventById(String id) async {
    try {
      if (_useFirebase) {
        // Firebase no tiene este método implementado, usar local
        return await _localService.getEventById(id);
      } else {
        return await _localService.getEventById(id);
      }
    } catch (e) {
      return await _localService.getEventById(id);
    }
  }

  /// Buscar eventos
  @override
  Future<List<Event>> searchEvents(String query) async {
    try {
      if (_useFirebase) {
        return await _firebaseService.searchEvents(query);
      } else {
        return await _localService.searchEvents(query);
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.searchEvents(query);
      }
      rethrow;
    }
  }

  // ==================== OPERACIONES DE CATEGORÍAS ====================

  /// Insertar categoría
  @override
  Future<int> insertCategory(model.Category category) async {
    // IMPORTANTE: Siempre insertar en SQLite primero para evitar errores de FK
    try {
      await _localService.insertCategory(category);
    } catch (e) {
      // Si ya existe en SQLite, ignorar error
      if (!e.toString().contains('UNIQUE constraint failed')) {
        print('Warning: No se pudo insertar en SQLite: $e');
      }
    }
    
    // Luego intentar Firebase si está habilitado
    try {
      if (_useFirebase) {
        await _firebaseService.createCategory(category);
        return 1;
      } else {
        return 1; // Ya se insertó en SQLite arriba
      }
    } catch (e) {
      // Si Firebase falla, no importa porque ya está en SQLite
      if (_useFirebase) {
        print('Firebase falló al crear categoría, pero está en SQLite: $e');
      }
      return 1;
    }
  }

  /// Obtener todas las categorías
  @override
  Future<List<model.Category>> getAllCategories() async {
    try {
      if (_useFirebase) {
        // Intentar cargar de Firebase primero
        final firebaseCategories = await _firebaseService.getAllCategories();
        
        // Sincronizar con SQLite para tenerlas localmente
        for (final category in firebaseCategories) {
          try {
            await _localService.insertCategory(category);
          } catch (e) {
            // Ignorar si ya existe
          }
        }
        
        return firebaseCategories;
      } else {
        return await _localService.getAllCategories();
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.getAllCategories();
      }
      rethrow;
    }
  }

  /// Obtener categoría por ID
  @override
  Future<model.Category?> getCategoryById(String id) async {
    try {
      if (_useFirebase) {
        // Firebase no tiene este método implementado, usar local
        return await _localService.getCategoryById(id);
      } else {
        return await _localService.getCategoryById(id);
      }
    } catch (e) {
      return await _localService.getCategoryById(id);
    }
  }

  /// Eliminar categoría
  @override
  Future<int> deleteCategory(String categoryId) async {
    try {
      if (_useFirebase) {
        await _firebaseService.deleteCategory(categoryId);
        // Backup en SQLite
        try {
          await _localService.deleteCategory(categoryId);
        } catch (e) {
          print('Warning: Backup local falló: $e');
        }
        return 1;
      } else {
        return await _localService.deleteCategory(categoryId);
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.deleteCategory(categoryId);
      }
      rethrow;
    }
  }

  // ==================== OPERACIONES DE SINCRONIZACIÓN ====================

  /// Sincronizar eventos con storage local
  Future<void> _syncWithLocal(List<Event> firebaseEvents) async {
    try {
      for (final event in firebaseEvents) {
        final existingEvent = await _localService.getEventById(event.id);
        if (existingEvent == null) {
          await _localService.insertEvent(event);
        } else if (existingEvent.updatedAt.isBefore(event.updatedAt)) {
          await _localService.updateEvent(event);
        }
      }
    } catch (e) {
      print('Error en sincronización local: $e');
    }
  }

  /// Sincronizar datos locales con Firebase
  Future<void> syncLocalToFirebase() async {
    try {
      final localEvents = await _localService.getAllEvents();
      
      for (final event in localEvents) {
        try {
          await _firebaseService.updateEvent(event);
        } catch (e) {
          print('Error sincronizando evento ${event.id}: $e');
        }
      }
    } catch (e) {
      print('Error en sincronización a Firebase: $e');
    }
  }

  /// Obtener estadísticas
  @override
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      if (_useFirebase) {
        return await _firebaseService.getUserStats();
      } else {
        return await _localService.getDatabaseStats();
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.getDatabaseStats();
      }
      rethrow;
    }
  }

  /// Limpiar eventos antiguos
  @override
  Future<int> cleanupOldEvents() async {
    try {
      if (_useFirebase) {
        final firebaseDeleted = await _firebaseService.cleanupOldEvents();
        await _localService.cleanupOldEvents();
        return firebaseDeleted;
      } else {
        return await _localService.cleanupOldEvents();
      }
    } catch (e) {
      // Fallback a SQLite si Firebase falla
      if (_useFirebase) {
        print('Firebase falló, usando SQLite: $e');
        return await _localService.cleanupOldEvents();
      }
      rethrow;
    }
  }

  /// Cerrar conexiones
  @override
  Future<void> closeDatabase() async {
    await _localService.closeDatabase();
    // Firebase se cierra automáticamente
  }
}
