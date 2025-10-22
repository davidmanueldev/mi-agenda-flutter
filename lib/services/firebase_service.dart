import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/event.dart';
import '../models/category.dart' as model;
import '../firebase_options.dart';

/// Servicio Firebase para gestión de datos en la nube
/// Reemplaza SQLite con Firestore como base de datos principal
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  
  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  // Referencias a las colecciones de Firestore
  final CollectionReference _eventsCollection = FirebaseFirestore.instance.collection('events');
  final CollectionReference _categoriesCollection = FirebaseFirestore.instance.collection('categories');
  
  // Instancia de Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Inicializar Firebase
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Autenticación anónima para simplicidad
      final FirebaseService service = FirebaseService();
      await service._ensureAuthenticated();
    } catch (e) {
      print('Error al inicializar Firebase: $e');
      // En modo development, continuar sin Firebase
      rethrow;
    }
  }

  /// Asegurar que el usuario esté autenticado
  Future<void> _ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      try {
        // Intentar autenticación anónima primero para simplicidad
        await _auth.signInAnonymously();
        print('Usuario autenticado anónimamente: ${_auth.currentUser?.uid}');
      } catch (e) {
        // Si falla anónima, podemos implementar email/password después
        print('Autenticación anónima falló: $e');
        throw FirebaseServiceException('Error en autenticación: $e');
      }
    }
  }

  /// Registrar usuario con email y password
  Future<UserCredential?> registerWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Usuario registrado: ${credential.user?.email}');
      return credential;
    } catch (e) {
      throw FirebaseServiceException('Error al registrar usuario: $e');
    }
  }

  /// Iniciar sesión con email y password
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Usuario autenticado: ${credential.user?.email}');
      return credential;
    } catch (e) {
      throw FirebaseServiceException('Error al iniciar sesión: $e');
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('Usuario cerró sesión');
    } catch (e) {
      throw FirebaseServiceException('Error al cerrar sesión: $e');
    }
  }

  /// Verificar si el usuario está autenticado
  bool get isAuthenticated => _auth.currentUser != null;

  /// Obtener email del usuario actual
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Obtener ID del usuario actual (para filtrar datos por usuario)
  String? get currentUserId => _auth.currentUser?.uid;

  // ==================== OPERACIONES DE EVENTOS ====================

  /// Crear un nuevo evento
  Future<void> createEvent(Event event) async {
    await _ensureAuthenticated();
    
    try {
      final eventData = event.toMap();
      eventData['userId'] = currentUserId; // Asociar con usuario
      
      await _eventsCollection.doc(event.id).set(eventData);
    } catch (e) {
      throw FirebaseServiceException('Error al crear evento: $e');
    }
  }

  /// Actualizar un evento existente
  Future<void> updateEvent(Event event) async {
    await _ensureAuthenticated();
    
    try {
      final eventData = event.toMap();
      eventData['userId'] = currentUserId;
      
      await _eventsCollection.doc(event.id).update(eventData);
    } catch (e) {
      throw FirebaseServiceException('Error al actualizar evento: $e');
    }
  }

  /// Eliminar un evento
  Future<void> deleteEvent(String eventId) async {
    await _ensureAuthenticated();
    
    try {
      await _eventsCollection.doc(eventId).delete();
    } catch (e) {
      throw FirebaseServiceException('Error al eliminar evento: $e');
    }
  }

  /// Obtener todos los eventos del usuario actual
  Future<List<Event>> getAllEvents() async {
    await _ensureAuthenticated();
    
    try {
      final QuerySnapshot snapshot = await _eventsCollection
          .where('userId', isEqualTo: currentUserId)
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Event.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener eventos: $e');
    }
  }

  /// Obtener eventos por rango de fechas
  Future<List<Event>> getEventsByDateRange(DateTime startDate, DateTime endDate) async {
    await _ensureAuthenticated();
    
    try {
      final QuerySnapshot snapshot = await _eventsCollection
          .where('userId', isEqualTo: currentUserId)
          .where('startTime', isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
          .where('startTime', isLessThanOrEqualTo: endDate.millisecondsSinceEpoch)
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Event.fromMap(data);
      }).toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener eventos por fecha: $e');
    }
  }

  /// Obtener eventos por fecha específica
  Future<List<Event>> getEventsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return getEventsByDateRange(startOfDay, endOfDay);
  }

  /// Buscar eventos por texto
  Future<List<Event>> searchEvents(String query) async {
    await _ensureAuthenticated();
    
    try {
      // Nota: Firestore no soporta búsqueda de texto completa nativa
      // Esta implementación filtra del lado cliente
      final allEvents = await getAllEvents();
      
      return allEvents.where((event) {
        return event.title.toLowerCase().contains(query.toLowerCase()) ||
               event.description.toLowerCase().contains(query.toLowerCase());
      }).toList();
    } catch (e) {
      throw FirebaseServiceException('Error al buscar eventos: $e');
    }
  }

  /// Stream de eventos en tiempo real
  Stream<List<Event>> getEventsStream() {
    return _eventsCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Event.fromMap(data);
      }).toList();
    });
  }

  // ==================== OPERACIONES DE CATEGORÍAS ====================
  
  /// Stream de categorías en tiempo real
  Stream<List<model.Category>> getCategoriesStream() {
    return _categoriesCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return model.Category.fromMap(data);
      }).toList();
    });
  }

  /// Crear una nueva categoría
  Future<void> createCategory(model.Category category) async {
    await _ensureAuthenticated();
    
    try {
      final categoryData = category.toMap();
      categoryData['userId'] = currentUserId;
      
      await _categoriesCollection.doc(category.id).set(categoryData);
    } catch (e) {
      throw FirebaseServiceException('Error al crear categoría: $e');
    }
  }

  /// Obtener todas las categorías del usuario
  Future<List<model.Category>> getAllCategories() async {
    await _ensureAuthenticated();
    
    try {
      final QuerySnapshot snapshot = await _categoriesCollection
          .where('userId', isEqualTo: currentUserId)
          .orderBy('name')
          .get();

      List<model.Category> categories = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return model.Category.fromMap(data);
      }).toList();

      // Si no hay categorías, crear las predeterminadas
      if (categories.isEmpty) {
        await _createDefaultCategories();
        categories = model.Category.defaultCategories;
      }

      return categories;
    } catch (e) {
      throw FirebaseServiceException('Error al obtener categorías: $e');
    }
  }

  /// Crear categorías predeterminadas
  Future<void> _createDefaultCategories() async {
    final defaultCategories = model.Category.defaultCategories;
    
    for (final category in defaultCategories) {
      await createCategory(category);
    }
  }

  /// Eliminar una categoría
  Future<void> deleteCategory(String categoryId) async {
    await _ensureAuthenticated();
    
    try {
      // Verificar si hay eventos asociados
      final eventsWithCategory = await _eventsCollection
          .where('userId', isEqualTo: currentUserId)
          .where('category', isEqualTo: categoryId)
          .get();

      if (eventsWithCategory.docs.isNotEmpty) {
        throw FirebaseServiceException(
          'No se puede eliminar la categoría: tiene ${eventsWithCategory.docs.length} eventos asociados'
        );
      }

      await _categoriesCollection.doc(categoryId).delete();
    } catch (e) {
      throw FirebaseServiceException('Error al eliminar categoría: $e');
    }
  }

  // ==================== OPERACIONES DE SINCRONIZACIÓN ====================

  /// Sincronizar datos offline (para implementación futura)
  Future<void> enableOfflinePersistence() async {
    try {
      await FirebaseFirestore.instance.enablePersistence();
    } catch (e) {
      print('Error al habilitar persistencia offline: $e');
    }
  }

  /// Obtener estadísticas del usuario
  Future<Map<String, int>> getUserStats() async {
    await _ensureAuthenticated();
    
    try {
      final events = await getAllEvents();
      final categories = await getAllCategories();
      
      final completedEvents = events.where((e) => e.isCompleted).length;
      final pendingEvents = events.length - completedEvents;
      
      return {
        'totalEvents': events.length,
        'completedEvents': completedEvents,
        'pendingEvents': pendingEvents,
        'totalCategories': categories.length,
      };
    } catch (e) {
      throw FirebaseServiceException('Error al obtener estadísticas: $e');
    }
  }

  /// Limpiar eventos antiguos
  Future<int> cleanupOldEvents() async {
    await _ensureAuthenticated();
    
    try {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      
      final QuerySnapshot oldEvents = await _eventsCollection
          .where('userId', isEqualTo: currentUserId)
          .where('endTime', isLessThan: oneYearAgo.millisecondsSinceEpoch)
          .get();

      // Eliminar eventos antiguos en lote
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in oldEvents.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      return oldEvents.docs.length;
    } catch (e) {
      throw FirebaseServiceException('Error al limpiar eventos antiguos: $e');
    }
  }
}

/// Excepción personalizada para errores de Firebase
class FirebaseServiceException implements Exception {
  final String message;
  
  FirebaseServiceException(this.message);
  
  @override
  String toString() => 'FirebaseServiceException: $message';
}
