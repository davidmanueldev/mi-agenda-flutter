import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/event.dart';
import '../models/category.dart' as model;
import '../models/task.dart';
import '../models/pomodoro_session.dart';
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
  final CollectionReference _tasksCollection = FirebaseFirestore.instance.collection('tasks');
  final CollectionReference _pomodoroCollection = FirebaseFirestore.instance.collection('pomodoro_sessions');
  
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

  /// Actualizar una categoría existente
  Future<void> updateCategory(model.Category category) async {
    await _ensureAuthenticated();
    
    try {
      final categoryData = category.toMap();
      categoryData['userId'] = currentUserId;
      
      await _categoriesCollection.doc(category.id).update(categoryData);
    } catch (e) {
      throw FirebaseServiceException('Error al actualizar categoría: $e');
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

      return categories;
    } catch (e) {
      throw FirebaseServiceException('Error al obtener categorías: $e');
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

  // ==================== OPERACIONES DE TAREAS ====================
  
  /// Stream de tareas en tiempo real
  Stream<List<Task>> getTasksStream() {
    return _tasksCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Task.fromJson(data);
      }).toList();
    });
  }

  /// Crear una nueva tarea
  Future<void> createTask(Task task) async {
    await _ensureAuthenticated();
    
    try {
      final taskData = task.toJson();
      taskData['userId'] = currentUserId;
      
      await _tasksCollection.doc(task.id).set(taskData);
    } catch (e) {
      throw FirebaseServiceException('Error al crear tarea: $e');
    }
  }

  /// Actualizar una tarea existente
  Future<void> updateTask(Task task) async {
    await _ensureAuthenticated();
    
    try {
      final taskData = task.toJson();
      taskData['userId'] = currentUserId;
      
      await _tasksCollection.doc(task.id).update(taskData);
    } catch (e) {
      throw FirebaseServiceException('Error al actualizar tarea: $e');
    }
  }

  /// Eliminar una tarea
  Future<void> deleteTask(String taskId) async {
    await _ensureAuthenticated();
    
    try {
      await _tasksCollection.doc(taskId).delete();
    } catch (e) {
      throw FirebaseServiceException('Error al eliminar tarea: $e');
    }
  }

  /// Obtener todas las tareas del usuario
  Future<List<Task>> getAllTasks() async {
    await _ensureAuthenticated();
    
    try {
      final snapshot = await _tasksCollection
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Task.fromJson(data);
      }).toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener tareas: $e');
    }
  }

  /// Obtener tarea por ID
  Future<Task?> getTaskById(String id) async {
    await _ensureAuthenticated();
    
    try {
      final doc = await _tasksCollection.doc(id).get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      return Task.fromJson(data);
    } catch (e) {
      throw FirebaseServiceException('Error al obtener tarea: $e');
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

  /// Obtener tareas por estado
  Future<List<Task>> getTasksByStatus(TaskStatus status) async {
    await _ensureAuthenticated();
    
    try {
      final QuerySnapshot snapshot = await _tasksCollection
          .where('userId', isEqualTo: currentUserId)
          .where('status', isEqualTo: status.name)
          .orderBy('dueDate')
          .get();

      return snapshot.docs
          .map((doc) => Task.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener tareas por estado: $e');
    }
  }

  /// Obtener tareas por prioridad
  Future<List<Task>> getTasksByPriority(TaskPriority priority) async {
    await _ensureAuthenticated();
    
    try {
      final QuerySnapshot snapshot = await _tasksCollection
          .where('userId', isEqualTo: currentUserId)
          .where('priority', isEqualTo: priority.name)
          .orderBy('dueDate')
          .get();

      return snapshot.docs
          .map((doc) => Task.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener tareas por prioridad: $e');
    }
  }

  /// Obtener tareas por categoría
  Future<List<Task>> getTasksByCategory(String category) async {
    await _ensureAuthenticated();
    
    try {
      final QuerySnapshot snapshot = await _tasksCollection
          .where('userId', isEqualTo: currentUserId)
          .where('category', isEqualTo: category)
          .orderBy('dueDate')
          .get();

      return snapshot.docs
          .map((doc) => Task.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener tareas por categoría: $e');
    }
  }

  /// Obtener tareas vencidas
  Future<List<Task>> getOverdueTasks() async {
    await _ensureAuthenticated();
    
    try {
      final now = DateTime.now().toIso8601String();
      
      final QuerySnapshot snapshot = await _tasksCollection
          .where('userId', isEqualTo: currentUserId)
          .where('dueDate', isLessThan: now)
          .where('status', isNotEqualTo: TaskStatus.completed.name)
          .orderBy('status')
          .orderBy('dueDate')
          .get();

      return snapshot.docs
          .map((doc) => Task.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener tareas vencidas: $e');
    }
  }

  /// Obtener tareas de hoy
  Future<List<Task>> getTodayTasks() async {
    await _ensureAuthenticated();
    
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final QuerySnapshot snapshot = await _tasksCollection
          .where('userId', isEqualTo: currentUserId)
          .where('dueDate', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('dueDate', isLessThan: endOfDay.toIso8601String())
          .orderBy('dueDate')
          .get();

      return snapshot.docs
          .map((doc) => Task.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener tareas de hoy: $e');
    }
  }

  /// Marcar tarea como completada
  Future<void> completeTask(String taskId) async {
    await _ensureAuthenticated();
    
    try {
      await _tasksCollection.doc(taskId).update({
        'status': TaskStatus.completed.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw FirebaseServiceException('Error al completar tarea: $e');
    }
  }

  /// Archivar tarea
  Future<void> archiveTask(String taskId) async {
    await _ensureAuthenticated();
    
    try {
      await _tasksCollection.doc(taskId).update({
        'status': TaskStatus.completed.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw FirebaseServiceException('Error al archivar tarea: $e');
    }
  }

  /// Buscar tareas
  Future<List<Task>> searchTasks(String query) async {
    await _ensureAuthenticated();
    
    try {
      // Firebase no soporta búsqueda de texto completa directamente
      // Traemos todas las tareas del usuario y filtramos localmente
      final allTasks = await getAllTasks();
      
      final lowerQuery = query.toLowerCase();
      return allTasks.where((task) {
        return task.title.toLowerCase().contains(lowerQuery) ||
               task.description.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      throw FirebaseServiceException('Error al buscar tareas: $e');
    }
  }

  /// Limpiar tareas completadas antiguas (más de 30 días)
  Future<int> cleanupCompletedTasks() async {
    await _ensureAuthenticated();
    
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final QuerySnapshot completedTasks = await _tasksCollection
          .where('userId', isEqualTo: currentUserId)
          .where('status', isEqualTo: TaskStatus.completed.name)
          .where('updatedAt', isLessThan: thirtyDaysAgo.toIso8601String())
          .get();

      // Eliminar tareas completadas antiguas en lote
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in completedTasks.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      return completedTasks.docs.length;
    } catch (e) {
      throw FirebaseServiceException('Error al limpiar tareas completadas: $e');
    }
  }
  
  // ==================== OPERACIONES DE SESIONES POMODORO ====================
  
  /// Crear una nueva sesión Pomodoro
  Future<void> createPomodoroSession(PomodoroSession session) async {
    await _ensureAuthenticated();
    
    try {
      await _pomodoroCollection.doc(session.id).set(session.toJson());
    } catch (e) {
      throw FirebaseServiceException('Error al crear sesión Pomodoro: $e');
    }
  }
  
  /// Actualizar una sesión Pomodoro existente
  Future<void> updatePomodoroSession(PomodoroSession session) async {
    await _ensureAuthenticated();
    
    try {
      await _pomodoroCollection.doc(session.id).update(session.toJson());
    } catch (e) {
      throw FirebaseServiceException('Error al actualizar sesión Pomodoro: $e');
    }
  }
  
  /// Eliminar una sesión Pomodoro
  Future<void> deletePomodoroSession(String sessionId) async {
    await _ensureAuthenticated();
    
    try {
      await _pomodoroCollection.doc(sessionId).delete();
    } catch (e) {
      throw FirebaseServiceException('Error al eliminar sesión Pomodoro: $e');
    }
  }
  
  /// Obtener todas las sesiones Pomodoro del usuario actual
  Future<List<PomodoroSession>> getAllPomodoroSessions() async {
    await _ensureAuthenticated();
    final userId = currentUserId!;
    
    try {
      final snapshot = await _pomodoroCollection
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => PomodoroSession.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener sesiones Pomodoro: $e');
    }
  }
  
  /// Obtener sesión Pomodoro por ID
  Future<PomodoroSession?> getPomodoroSessionById(String id) async {
    await _ensureAuthenticated();
    
    try {
      final doc = await _pomodoroCollection.doc(id).get();
      
      if (!doc.exists) return null;
      return PomodoroSession.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw FirebaseServiceException('Error al obtener sesión Pomodoro por ID: $e');
    }
  }
  
  /// Obtener sesiones Pomodoro por rango de fechas
  Future<List<PomodoroSession>> getPomodoroSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _ensureAuthenticated();
    final userId = currentUserId!;
    
    try {
      final snapshot = await _pomodoroCollection
          .where('userId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('startTime', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => PomodoroSession.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener sesiones Pomodoro por rango: $e');
    }
  }
  
  /// Obtener sesiones Pomodoro de hoy
  Future<List<PomodoroSession>> getTodayPomodoroSessions() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return await getPomodoroSessionsByDateRange(startOfDay, endOfDay);
  }
  
  /// Obtener sesiones Pomodoro por tarea
  Future<List<PomodoroSession>> getPomodoroSessionsByTask(String taskId) async {
    await _ensureAuthenticated();
    final userId = currentUserId!;
    
    try {
      final snapshot = await _pomodoroCollection
          .where('userId', isEqualTo: userId)
          .where('taskId', isEqualTo: taskId)
          .orderBy('startTime', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => PomodoroSession.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener sesiones Pomodoro por tarea: $e');
    }
  }
  
  /// Stream de sesiones Pomodoro en tiempo real
  Stream<List<PomodoroSession>> getPomodoroSessionsStream() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }
    
    return _pomodoroCollection
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PomodoroSession.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }
  
  /// Obtener estadísticas de Pomodoro
  Future<Map<String, dynamic>> getPomodoroStats() async {
    await _ensureAuthenticated();
    final userId = currentUserId!;
    
    try {
      // Obtener todas las sesiones completadas
      final allSessions = await _pomodoroCollection
          .where('userId', isEqualTo: userId)
          .where('endTime', isNull: false)
          .get();
      
      final sessions = allSessions.docs
          .map((doc) => PomodoroSession.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      
      // Calcular estadísticas
      final totalSessions = sessions.length;
      final workSessions = sessions
          .where((s) => s.sessionType == SessionType.work)
          .length;
      
      final totalSeconds = sessions.fold<int>(
        0,
        (sum, session) => sum + session.duration,
      );
      final totalMinutes = totalSeconds ~/ 60;
      
      // Sesiones de hoy
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final todaySessions = sessions
          .where((s) => s.startTime.isAfter(startOfDay))
          .length;
      
      return {
        'totalSessions': totalSessions,
        'workSessions': workSessions,
        'totalMinutes': totalMinutes,
        'todaySessions': todaySessions,
      };
    } catch (e) {
      throw FirebaseServiceException('Error al obtener estadísticas Pomodoro: $e');
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
