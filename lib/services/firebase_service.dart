import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/event.dart';
import '../models/category.dart' as model;
import '../models/task.dart';
import '../models/pomodoro_session.dart';
import '../models/task_template.dart';
import '../models/user_profile.dart';
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
  final CollectionReference _templatesCollection = FirebaseFirestore.instance.collection('task_templates');
  
  // Instancia de Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Obtener el ID del usuario actual de Firebase Auth
  String? get currentUserId => _auth.currentUser?.uid;
  
  /// Inicializar Firebase
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      print('✅ Firebase inicializado correctamente');
      // NO hacer autenticación automática - dejar que AuthController maneje esto
    } catch (e) {
      print('❌ Error al inicializar Firebase: $e');
      // En modo development, continuar sin Firebase
      rethrow;
    }
  }

  /// Asegurar que el usuario esté autenticado
  /// IMPORTANTE: Este método ya NO hace login anónimo automático
  /// Solo verifica si hay un usuario autenticado
  Future<void> _ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      throw FirebaseServiceException(
        'No hay usuario autenticado. Por favor inicia sesión primero.'
      );
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

  // ==================== MÉTODOS DE AUTENTICACIÓN MEJORADOS ====================

  /// Registrar nuevo usuario con email y contraseña
  Future<UserProfile?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      // Actualizar displayName si se proporcionó
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();
      }

      final user = await _getCurrentUserFromFirebaseUser(credential.user!);
      
      // Guardar en colección users
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .set(user.toJson());
      }

      print('✅ Usuario registrado: ${user?.email}');
      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Error de autenticación: ${e.code} - ${e.message}');
      throw FirebaseServiceException(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('❌ Error al registrar usuario: $e');
      throw FirebaseServiceException('Error al registrar usuario: $e');
    }
  }

  /// Iniciar sesión con email y contraseña
  Future<UserProfile?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      final user = await _getCurrentUserFromFirebaseUser(credential.user!);
      
      // Actualizar lastLoginAt
      if (user != null) {
        final updatedUser = user.copyWith(
          lastLoginAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({'last_login_at': Timestamp.fromDate(updatedUser.lastLoginAt)});
        
        print('✅ Usuario autenticado: ${user.email}');
        return updatedUser;
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Error de autenticación: ${e.code} - ${e.message}');
      throw FirebaseServiceException(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('❌ Error al iniciar sesión: $e');
      throw FirebaseServiceException('Error al iniciar sesión: $e');
    }
  }

  /// Obtener usuario actual
  Future<UserProfile?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      
      if (firebaseUser == null) {
        print('🔍 getCurrentUser: No hay usuario en Firebase Auth');
        return null;
      }

      // Verificar si es usuario anónimo
      if (firebaseUser.isAnonymous) {
        print('⚠️  Usuario anónimo detectado, cerrando sesión...');
        await _auth.signOut();
        return null;
      }

      print('🔍 getCurrentUser: Usuario Firebase encontrado: ${firebaseUser.email} (UID: ${firebaseUser.uid})');
      return await _getCurrentUserFromFirebaseUser(firebaseUser);
    } catch (e) {
      print('❌ Error al obtener usuario actual: $e');
      return null;
    }
  }

  /// Enviar email de recuperación de contraseña
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Email de recuperación enviado a: $email');
    } on FirebaseAuthException catch (e) {
      print('❌ Error al enviar email: ${e.code} - ${e.message}');
      throw FirebaseServiceException(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('❌ Error al enviar email de recuperación: $e');
      throw FirebaseServiceException('Error al enviar email: $e');
    }
  }

  /// Actualizar perfil de usuario
  Future<UserProfile?> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      if (displayName != null) {
        await firebaseUser.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await firebaseUser.updatePhotoURL(photoURL);
      }

      await firebaseUser.reload();
      final updatedFirebaseUser = _auth.currentUser;
      if (updatedFirebaseUser == null) return null;

      final user = await _getCurrentUserFromFirebaseUser(updatedFirebaseUser);
      
      // Actualizar en Firestore
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({
          'display_name': displayName,
          'photo_url': photoURL,
          'updated_at': Timestamp.fromDate(DateTime.now()),
        });
      }

      print('✅ Perfil actualizado');
      return user;
    } catch (e) {
      print('❌ Error al actualizar perfil: $e');
      throw FirebaseServiceException('Error al actualizar perfil: $e');
    }
  }

  /// Cambiar contraseña del usuario actual
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null || firebaseUser.email == null) {
        throw FirebaseServiceException('No hay usuario autenticado');
      }

      // Re-autenticar usuario con contraseña actual
      final credential = EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: currentPassword,
      );

      await firebaseUser.reauthenticateWithCredential(credential);

      // Cambiar contraseña
      await firebaseUser.updatePassword(newPassword);

      print('✅ Contraseña actualizada correctamente');
    } on FirebaseAuthException catch (e) {
      print('❌ Error al cambiar contraseña: ${e.code} - ${e.message}');
      if (e.code == 'wrong-password') {
        throw FirebaseServiceException('La contraseña actual es incorrecta');
      } else if (e.code == 'weak-password') {
        throw FirebaseServiceException('La nueva contraseña es muy débil');
      }
      throw FirebaseServiceException(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('❌ Error al cambiar contraseña: $e');
      throw FirebaseServiceException('Error al cambiar contraseña: $e');
    }
  }

  /// Eliminar cuenta de usuario
  Future<void> deleteUserAccount() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw FirebaseServiceException('No hay usuario autenticado');
      }

      final userId = firebaseUser.uid;

      // Eliminar documento de usuario en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .delete();

      // Eliminar cuenta de Firebase Auth
      await firebaseUser.delete();

      print('✅ Cuenta eliminada correctamente');
    } on FirebaseAuthException catch (e) {
      print('❌ Error al eliminar cuenta: ${e.code} - ${e.message}');
      if (e.code == 'requires-recent-login') {
        throw FirebaseServiceException(
          'Por seguridad, debes volver a iniciar sesión antes de eliminar tu cuenta',
        );
      }
      throw FirebaseServiceException(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('❌ Error al eliminar cuenta: $e');
      throw FirebaseServiceException('Error al eliminar cuenta: $e');
    }
  }

  /// Convertir Firebase User a UserProfile
  Future<UserProfile?> _getCurrentUserFromFirebaseUser(User firebaseUser) async {
    try {
      // Intentar obtener de Firestore primero
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (doc.exists) {
        return UserProfile.fromJson(doc.data()!);
      }

      // Si no existe en Firestore, crear desde Firebase User
      final now = DateTime.now();
      final user = UserProfile(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoURL: firebaseUser.photoURL,
        createdAt: firebaseUser.metadata.creationTime ?? now,
        lastLoginAt: now,
        updatedAt: now,
      );

      // Guardar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set(user.toJson());

      return user;
    } catch (e) {
      print('❌ Error al convertir usuario: $e');
      return null;
    }
  }

  /// Obtener mensaje de error amigable
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este email ya está registrado';
      case 'invalid-email':
        return 'Email inválido';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres)';
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'user-disabled':
        return 'Usuario deshabilitado';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      default:
        return 'Error de autenticación: $code';
    }
  }

  /// Verificar si el usuario está autenticado
  bool get isAuthenticated => _auth.currentUser != null;

  /// Obtener email del usuario actual
  String? get currentUserEmail => _auth.currentUser?.email;

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
    print('🔍 getEventsStream: currentUserId = $currentUserId');
    
    if (currentUserId == null) {
      print('⚠️ getEventsStream: No hay usuario autenticado, retornando stream vacío');
      return Stream.value([]);
    }
    
    return _eventsCollection
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      print('📦 getEventsStream: Recibidos ${snapshot.docs.length} eventos de Firebase');
      
      final events = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Event.fromMap(data);
      }).toList();
      
      // Ordenar por startTime localmente (evitar índice compuesto)
      events.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      return events;
    });
  }

  // ==================== OPERACIONES DE CATEGORÍAS ====================
  
  /// Stream de categorías en tiempo real
  Stream<List<model.Category>> getCategoriesStream() {
    print('🔍 getCategoriesStream: currentUserId = $currentUserId');
    
    if (currentUserId == null) {
      print('⚠️ getCategoriesStream: No hay usuario autenticado, retornando stream vacío');
      return Stream.value([]);
    }
    
    return _categoriesCollection
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      print('📦 getCategoriesStream: Recibidas ${snapshot.docs.length} categorías de Firebase');
      
      final categories = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final category = model.Category.fromMap(data);
        print('   - ${category.name} (userId: ${category.userId})');
        return category;
      }).toList();
      
      // Ordenar por nombre localmente (evitar índice compuesto en Firebase)
      categories.sort((a, b) => a.name.compareTo(b.name));
      
      return categories;
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
    print('🔍 getTasksStream: currentUserId = $currentUserId');
    
    if (currentUserId == null) {
      print('⚠️ getTasksStream: No hay usuario autenticado, retornando stream vacío');
      return Stream.value([]);
    }
    
    return _tasksCollection
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      print('📦 getTasksStream: Recibidas ${snapshot.docs.length} tareas de Firebase');
      
      final tasks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Task.fromJson(data);
      }).toList();
      
      // Ordenar por createdAt localmente (evitar índice compuesto)
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return tasks;
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
      final sessionData = session.toJson();
      sessionData['userId'] = currentUserId; // Asociar con usuario autenticado
      
      await _pomodoroCollection.doc(session.id).set(sessionData);
    } catch (e) {
      throw FirebaseServiceException('Error al crear sesión Pomodoro: $e');
    }
  }
  
  /// Actualizar una sesión Pomodoro existente
  Future<void> updatePomodoroSession(PomodoroSession session) async {
    await _ensureAuthenticated();
    
    try {
      final sessionData = session.toJson();
      sessionData['userId'] = currentUserId; // Asociar con usuario autenticado
      
      await _pomodoroCollection.doc(session.id).update(sessionData);
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
    print('🔍 getPomodoroSessionsStream: currentUserId = $currentUserId');
    
    final userId = currentUserId;
    if (userId == null) {
      print('⚠️ getPomodoroSessionsStream: No hay usuario autenticado, retornando stream vacío');
      return Stream.value([]);
    }
    
    return _pomodoroCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      print('📦 getPomodoroSessionsStream: Recibidas ${snapshot.docs.length} sesiones de Firebase');
      
      final sessions = snapshot.docs
          .map((doc) => PomodoroSession.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      
      // Ordenar por startTime localmente (evitar índice compuesto)
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      return sessions;
    });
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
  
  // ==================== OPERACIONES DE TASK TEMPLATES ====================
  
  /// Crear un nuevo template
  Future<void> createTaskTemplate(TaskTemplate template) async {
    await _ensureAuthenticated();
    
    try {
      await _templatesCollection.doc(template.id).set(template.toJson());
      print('✅ Template creado en Firebase: ${template.name}');
    } catch (e) {
      throw FirebaseServiceException('Error al crear template: $e');
    }
  }
  
  /// Actualizar un template existente
  Future<void> updateTaskTemplate(TaskTemplate template) async {
    await _ensureAuthenticated();
    
    try {
      await _templatesCollection.doc(template.id).update(template.toJson());
      print('🔄 Template actualizado en Firebase: ${template.name}');
    } catch (e) {
      throw FirebaseServiceException('Error al actualizar template: $e');
    }
  }
  
  /// Eliminar un template
  Future<void> deleteTaskTemplate(String templateId) async {
    await _ensureAuthenticated();
    
    try {
      await _templatesCollection.doc(templateId).delete();
      print('🗑️ Template eliminado de Firebase: $templateId');
    } catch (e) {
      throw FirebaseServiceException('Error al eliminar template: $e');
    }
  }
  
  /// Obtener todos los templates del usuario
  Future<List<TaskTemplate>> getAllTaskTemplates() async {
    await _ensureAuthenticated();
    
    try {
      final userId = currentUserId;
      final QuerySnapshot snapshot = await _templatesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => TaskTemplate.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw FirebaseServiceException('Error al obtener templates: $e');
    }
  }
  
  /// Obtener template por ID
  Future<TaskTemplate?> getTaskTemplateById(String id) async {
    await _ensureAuthenticated();
    
    try {
      final doc = await _templatesCollection.doc(id).get();
      
      if (!doc.exists) return null;
      return TaskTemplate.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw FirebaseServiceException('Error al obtener template: $e');
    }
  }
  
  /// Stream de templates en tiempo real
  Stream<List<TaskTemplate>> getTaskTemplatesStream() {
    final userId = currentUserId;
    
    return _templatesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskTemplate.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }
}

/// Excepción personalizada para errores de Firebase
class FirebaseServiceException implements Exception {
  final String message;
  
  FirebaseServiceException(this.message);
  
  @override
  String toString() => 'FirebaseServiceException: $message';
}
