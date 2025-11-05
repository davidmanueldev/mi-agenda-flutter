import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/event.dart';
import '../models/category.dart' as model;
import '../models/task.dart';
import '../models/pomodoro_session.dart';
import '../models/task_template.dart';
import '../models/user_profile.dart';
import 'database_interface.dart';

/// Servicio de base de datos para la gestión de persistencia
/// Implementa el patrón Singleton y mejores prácticas de SQLite
class DatabaseService implements DatabaseInterface {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();
  
  @override
  String? get currentUserId => null; // DatabaseService local no tiene concepto de usuario autenticado

  /// Getter para obtener la instancia de la base de datos
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Inicialización de la base de datos con creación de tablas
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'mi_agenda.db');

    return await openDatabase(
      path,
      version: 9, // Versión 9: Campo userId en categories para multi-usuario
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// Creación de las tablas principales
  Future<void> _createTables(Database db, int version) async {
    // Tabla de categorías
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Tabla de eventos
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER NOT NULL,
        category TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (category) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de tareas (mejorada)
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        dueDate INTEGER,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        steps TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        isMyDay INTEGER NOT NULL DEFAULT 0,
        reminderDateTime INTEGER,
        recurrence TEXT NOT NULL DEFAULT 'none',
        customRecurrence TEXT,
        estimatedPomodoros INTEGER NOT NULL DEFAULT 1,
        completedPomodoros INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (category) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Índices para optimizar consultas de eventos
    await db.execute('CREATE INDEX idx_events_userId ON events(userId)');
    await db.execute('CREATE INDEX idx_events_startTime ON events(startTime)');
    await db.execute('CREATE INDEX idx_events_category ON events(category)');
    await db.execute('CREATE INDEX idx_events_date ON events(startTime, endTime)');
    
    // Índices para optimizar consultas de tareas
    await db.execute('CREATE INDEX idx_tasks_dueDate ON tasks(dueDate)');
    await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
    await db.execute('CREATE INDEX idx_tasks_priority ON tasks(priority)');
    await db.execute('CREATE INDEX idx_tasks_category ON tasks(category)');
    
    // Tabla de sesiones Pomodoro
    await db.execute('''
      CREATE TABLE pomodoro_sessions (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        sessionType TEXT NOT NULL,
        duration INTEGER NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        taskId TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE SET NULL
      )
    ''');
    
    // Índices para optimizar consultas de Pomodoro
    await db.execute('CREATE INDEX idx_pomodoro_startTime ON pomodoro_sessions(startTime)');
    await db.execute('CREATE INDEX idx_pomodoro_userId ON pomodoro_sessions(userId)');
    await db.execute('CREATE INDEX idx_pomodoro_taskId ON pomodoro_sessions(taskId)');
    
    // Tabla de templates de tareas (v6)
    await db.execute('''
      CREATE TABLE task_templates (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        estimated_pomodoros INTEGER NOT NULL DEFAULT 1,
        steps TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    
    // Índice para optimizar consultas de templates
    await db.execute('CREATE INDEX idx_templates_userId ON task_templates(user_id)');
    
    // Tabla de usuarios (v7)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        display_name TEXT,
        photo_url TEXT,
        created_at INTEGER NOT NULL,
        last_login_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    
    // Índice para optimizar búsquedas por email
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
  }

  /// Manejo de actualizaciones de esquema de base de datos
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Migración de versión 1 a 2: Agregar tabla de tareas
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          dueDate INTEGER,
          category TEXT NOT NULL,
          priority TEXT NOT NULL,
          status TEXT NOT NULL,
          steps TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY (category) REFERENCES categories (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('CREATE INDEX idx_tasks_dueDate ON tasks(dueDate)');
      await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
      await db.execute('CREATE INDEX idx_tasks_priority ON tasks(priority)');
      await db.execute('CREATE INDEX idx_tasks_category ON tasks(category)');
    }
    
    // Migración de versión 2 a 3: Agregar nuevos campos a tareas
    if (oldVersion < 3) {
      // Verificar si la tabla tasks existe
      var tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tasks'"
      );
      
      if (tableExists.isEmpty) {
        // Si no existe, crearla directamente con el esquema completo
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            dueDate INTEGER,
            category TEXT NOT NULL,
            priority TEXT NOT NULL,
            status TEXT NOT NULL,
            steps TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            isMyDay INTEGER NOT NULL DEFAULT 0,
            reminderDateTime INTEGER,
            recurrence TEXT NOT NULL DEFAULT 'none',
            customRecurrence TEXT,
            FOREIGN KEY (category) REFERENCES categories (id) ON DELETE CASCADE
          )
        ''');
      } else {
        // Si existe, migrar datos
        // Verificar qué columnas existen
        var columns = await db.rawQuery('PRAGMA table_info(tasks)');
        var columnNames = columns.map((col) => col['name'] as String).toSet();
        
        // Crear nueva tabla temporal con el nuevo esquema
        await db.execute('''
          CREATE TABLE tasks_new (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            dueDate INTEGER,
            category TEXT NOT NULL,
            priority TEXT NOT NULL,
            status TEXT NOT NULL,
            steps TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            isMyDay INTEGER NOT NULL DEFAULT 0,
            reminderDateTime INTEGER,
            recurrence TEXT NOT NULL DEFAULT 'none',
            customRecurrence TEXT,
            FOREIGN KEY (category) REFERENCES categories (id) ON DELETE CASCADE
          )
        ''');
        
        // Construir query de copia basado en columnas existentes
        String stepsColumn = columnNames.contains('steps') ? 'steps' : 'NULL';
        String isMyDayColumn = columnNames.contains('isMyDay') ? 'isMyDay' : '0';
        String reminderColumn = columnNames.contains('reminderDateTime') ? 'reminderDateTime' : 'NULL';
        String recurrenceColumn = columnNames.contains('recurrence') ? 'recurrence' : "'none'";
        String customRecurrenceColumn = columnNames.contains('customRecurrence') ? 'customRecurrence' : 'NULL';
        
        // Copiar datos de la tabla antigua
        await db.execute('''
          INSERT INTO tasks_new (id, userId, title, description, dueDate, category, 
                                 priority, status, steps, createdAt, updatedAt,
                                 isMyDay, reminderDateTime, recurrence, customRecurrence)
          SELECT id, userId, title, description, dueDate, category, priority, status, 
                 $stepsColumn, createdAt, updatedAt, $isMyDayColumn, $reminderColumn, 
                 $recurrenceColumn, $customRecurrenceColumn
          FROM tasks
        ''');
        
        // Eliminar tabla antigua y renombrar
        await db.execute('DROP TABLE tasks');
        await db.execute('ALTER TABLE tasks_new RENAME TO tasks');
      }
      
      // Crear/Recrear índices
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_dueDate ON tasks(dueDate)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks(category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_isMyDay ON tasks(isMyDay)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_recurrence ON tasks(recurrence)');
    }
    
    // Migración de versión 3 a 4: Agregar tabla de sesiones Pomodoro
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE pomodoro_sessions (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          sessionType TEXT NOT NULL,
          duration INTEGER NOT NULL,
          startTime INTEGER NOT NULL,
          endTime INTEGER,
          taskId TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE SET NULL
        )
      ''');
      
      await db.execute('CREATE INDEX idx_pomodoro_startTime ON pomodoro_sessions(startTime)');
      await db.execute('CREATE INDEX idx_pomodoro_userId ON pomodoro_sessions(userId)');
      await db.execute('CREATE INDEX idx_pomodoro_taskId ON pomodoro_sessions(taskId)');
    }
    
    // Migración de versión 4 a 5: Agregar campos de Pomodoro a tareas
    if (oldVersion < 5) {
      // Verificar si las columnas ya existen
      var columns = await db.rawQuery('PRAGMA table_info(tasks)');
      var columnNames = columns.map((col) => col['name'] as String).toSet();
      
      // Agregar estimatedPomodoros si no existe
      if (!columnNames.contains('estimatedPomodoros')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN estimatedPomodoros INTEGER NOT NULL DEFAULT 1');
      }
      
      // Agregar completedPomodoros si no existe
      if (!columnNames.contains('completedPomodoros')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN completedPomodoros INTEGER NOT NULL DEFAULT 0');
      }
    }
    
    // Migración de versión 5 a 6: Agregar tabla de templates
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE task_templates (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          category TEXT NOT NULL,
          priority TEXT NOT NULL,
          estimated_pomodoros INTEGER NOT NULL DEFAULT 1,
          steps TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      await db.execute('CREATE INDEX idx_templates_userId ON task_templates(user_id)');
    }
    
    // Migración de versión 6 a 7: Agregar tabla de usuarios
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          email TEXT NOT NULL UNIQUE,
          display_name TEXT,
          photo_url TEXT,
          created_at INTEGER NOT NULL,
          last_login_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      await db.execute('CREATE INDEX idx_users_email ON users(email)');
    }
    
    // Migración de versión 7 a 8: Agregar campo userId a eventos
    if (oldVersion < 8) {
      // Verificar si la columna userId ya existe en events
      var columns = await db.rawQuery('PRAGMA table_info(events)');
      var columnNames = columns.map((col) => col['name'] as String).toSet();
      
      if (!columnNames.contains('userId')) {
        // Agregar la columna userId con valor por defecto vacío
        // Nota: Los eventos existentes tendrán userId vacío y deberán ser re-asignados o eliminados
        await db.execute('ALTER TABLE events ADD COLUMN userId TEXT NOT NULL DEFAULT ""');
        
        // Crear índice para userId
        await db.execute('CREATE INDEX idx_events_userId ON events(userId)');
        
        print('⚠️  ADVERTENCIA: Eventos existentes sin userId asignado. Considera eliminarlos o asignarles un usuario.');
      }
    }
    
    // Migración de versión 8 a 9: Agregar campo userId a categories
    if (oldVersion < 9) {
      // Verificar si la columna userId ya existe en categories
      var columns = await db.rawQuery('PRAGMA table_info(categories)');
      var columnNames = columns.map((col) => col['name'] as String).toSet();
      
      if (!columnNames.contains('userId')) {
        // Agregar la columna userId (nullable para categorías del sistema)
        await db.execute('ALTER TABLE categories ADD COLUMN userId TEXT');
        
        // Crear índice para userId
        await db.execute('CREATE INDEX idx_categories_userId ON categories(userId)');
        
        print('⚠️  ADVERTENCIA: Categorías existentes sin userId asignado (categorías del sistema).');
      }
    }
  }

  // ==================== OPERACIONES DE USUARIOS ====================

  /// Insertar un nuevo usuario
  Future<int> insertUser(UserProfile user) async {
    try {
      final db = await database;
      return await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Error al insertar usuario: $e');
    }
  }

  /// Actualizar o insertar usuario (upsert)
  Future<int> upsertUser(UserProfile user) async {
    try {
      final db = await database;
      return await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Error al actualizar usuario: $e');
    }
  }

  /// Obtener usuario por ID
  Future<UserProfile?> getUserById(String userId) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return UserProfile.fromMap(result.first);
    } catch (e) {
      throw DatabaseException('Error al obtener usuario: $e');
    }
  }

  /// Actualizar último login del usuario
  Future<int> updateUserLastLogin(String userId) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      return await db.update(
        'users',
        {
          'last_login_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw DatabaseException('Error al actualizar last login: $e');
    }
  }

  /// Eliminar usuario
  Future<int> deleteUser(String userId) async {
    try {
      final db = await database;
      return await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw DatabaseException('Error al eliminar usuario: $e');
    }
  }

  // ==================== OPERACIONES DE CATEGORÍAS ====================

  /// Insertar una nueva categoría
  @override
  Future<int> insertCategory(model.Category category) async {
    try {
      final db = await database;
      return await db.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Error al insertar categoría: $e');
    }
  }

  /// Actualizar una categoría existente
  @override
  Future<int> updateCategory(model.Category category) async {
    try {
      final db = await database;
      return await db.update(
        'categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
    } catch (e) {
      throw DatabaseException('Error al actualizar categoría: $e');
    }
  }

  /// Obtener todas las categorías
  @override
  Future<List<model.Category>> getAllCategories() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'categories',
        orderBy: 'name ASC',
      );

      return maps.map((map) => model.Category.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener categorías: $e');
    }
  }

  /// Obtener categoría por ID
  @override
  Future<model.Category?> getCategoryById(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return model.Category.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Error al obtener categoría: $e');
    }
  }

  /// Eliminar una categoría
  @override
  Future<int> deleteCategory(String id) async {
    try {
      final db = await database;
      
      // Verificar si hay eventos asociados
      final eventsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM events WHERE category = ?', [id])
      ) ?? 0;
      
      if (eventsCount > 0) {
        throw DatabaseException('No se puede eliminar la categoría: tiene eventos asociados');
      }
      
      return await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Error al eliminar categoría: $e');
    }
  }

  // ==================== OPERACIONES DE EVENTOS ====================

  /// Insertar un nuevo evento
  @override
  Future<int> insertEvent(Event event) async {
    try {
      final db = await database;
      
      // Verificar que la categoría existe
      final category = await getCategoryById(event.category);
      if (category == null) {
        throw DatabaseException('La categoría especificada no existe');
      }
      
      return await db.insert(
        'events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DatabaseException('Error al insertar evento: $e');
    }
  }

  /// Obtener todos los eventos
  @override
  Future<List<Event>> getAllEvents() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        orderBy: 'startTime ASC',
      );

      return maps.map((map) => Event.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener eventos: $e');
    }
  }

  /// Obtener eventos por fecha
  @override
  Future<List<Event>> getEventsByDate(DateTime date) async {
    try {
      final db = await database;
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        where: 'startTime >= ? AND startTime < ?',
        whereArgs: [
          startOfDay.millisecondsSinceEpoch,
          endOfDay.millisecondsSinceEpoch,
        ],
        orderBy: 'startTime ASC',
      );

      return maps.map((map) => Event.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener eventos por fecha: $e');
    }
  }

  /// Obtener eventos por rango de fechas
  @override
  Future<List<Event>> getEventsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        where: 'startTime >= ? AND startTime <= ?',
        whereArgs: [
          startDate.millisecondsSinceEpoch,
          endDate.millisecondsSinceEpoch,
        ],
        orderBy: 'startTime ASC',
      );

      return maps.map((map) => Event.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener eventos por rango: $e');
    }
  }

  /// Obtener evento por ID
  @override
  Future<Event?> getEventById(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return Event.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Error al obtener evento: $e');
    }
  }

  /// Actualizar un evento
  @override
  Future<int> updateEvent(Event event) async {
    try {
      final db = await database;
      
      // Verificar que el evento existe
      final existingEvent = await getEventById(event.id);
      if (existingEvent == null) {
        throw DatabaseException('El evento no existe');
      }
      
      return await db.update(
        'events',
        event.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
    } catch (e) {
      throw DatabaseException('Error al actualizar evento: $e');
    }
  }

  /// Eliminar un evento
  @override
  Future<int> deleteEvent(String id) async {
    try {
      final db = await database;
      return await db.delete(
        'events',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Error al eliminar evento: $e');
    }
  }

  /// Buscar eventos por texto
  @override
  Future<List<Event>> searchEvents(String query) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        where: 'title LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'startTime ASC',
      );

      return maps.map((map) => Event.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al buscar eventos: $e');
    }
  }

  // ==================== OPERACIONES DE MANTENIMIENTO ====================

  /// Limpiar eventos antiguos (más de 1 año)
  @override
  Future<int> cleanupOldEvents() async {
    try {
      final db = await database;
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      
      return await db.delete(
        'events',
        where: 'endTime < ?',
        whereArgs: [oneYearAgo.millisecondsSinceEpoch],
      );
    } catch (e) {
      throw DatabaseException('Error al limpiar eventos antiguos: $e');
    }
  }

  /// Obtener estadísticas de la base de datos
  @override
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final db = await database;
      
      final eventsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM events')
      ) ?? 0;
      
      final categoriesCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM categories')
      ) ?? 0;
      
      final completedEventsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM events WHERE isCompleted = 1')
      ) ?? 0;
      
      return {
        'totalEvents': eventsCount,
        'totalCategories': categoriesCount,
        'completedEvents': completedEventsCount,
        'pendingEvents': eventsCount - completedEventsCount,
      };
    } catch (e) {
      throw DatabaseException('Error al obtener estadísticas: $e');
    }
  }

  // ==================== OPERACIONES DE TAREAS ====================

  /// Insertar una nueva tarea
  @override
  Future<int> insertTask(Task task) async {
    try {
      final db = await database;
      await db.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return 1;
    } catch (e) {
      throw DatabaseException('Error al insertar tarea: $e');
    }
  }

  /// Actualizar una tarea existente
  @override
  Future<int> updateTask(Task task) async {
    try {
      final db = await database;
      return await db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } catch (e) {
      throw DatabaseException('Error al actualizar tarea: $e');
    }
  }

  /// Eliminar una tarea por ID
  @override
  Future<int> deleteTask(String id) async {
    try {
      final db = await database;
      return await db.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Error al eliminar tarea: $e');
    }
  }

  /// Obtener todas las tareas
  @override
  Future<List<Task>> getAllTasks() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        orderBy: 'createdAt DESC',
      );
      return maps.map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener tareas: $e');
    }
  }

  /// Obtener tarea por ID
  @override
  Future<Task?> getTaskById(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return Task.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Error al obtener tarea: $e');
    }
  }

  /// Obtener tareas por estado
  @override
  Future<List<Task>> getTasksByStatus(TaskStatus status) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'status = ?',
        whereArgs: [status.name],
        orderBy: 'dueDate ASC NULLS LAST, priority DESC, createdAt DESC',
      );
      return maps.map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener tareas por estado: $e');
    }
  }

  /// Obtener tareas por prioridad
  @override
  Future<List<Task>> getTasksByPriority(TaskPriority priority) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'priority = ?',
        whereArgs: [priority.name],
        orderBy: 'dueDate ASC NULLS LAST, createdAt DESC',
      );
      return maps.map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener tareas por prioridad: $e');
    }
  }

  /// Obtener tareas por categoría
  @override
  Future<List<Task>> getTasksByCategory(String category) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'dueDate ASC NULLS LAST, priority DESC, createdAt DESC',
      );
      return maps.map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener tareas por categoría: $e');
    }
  }

  /// Obtener tareas vencidas
  @override
  Future<List<Task>> getOverdueTasks() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'dueDate < ? AND status != ?',
        whereArgs: [now, TaskStatus.completed.name],
        orderBy: 'dueDate ASC, priority DESC',
      );
      return maps.map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener tareas vencidas: $e');
    }
  }

  /// Obtener tareas de hoy
  @override
  Future<List<Task>> getTodayTasks() async {
    try {
      final db = await database;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'dueDate >= ? AND dueDate < ?',
        whereArgs: [
          startOfDay.millisecondsSinceEpoch,
          endOfDay.millisecondsSinceEpoch,
        ],
        orderBy: 'priority DESC, dueDate ASC',
      );
      return maps.map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener tareas de hoy: $e');
    }
  }

  /// Buscar tareas por texto
  @override
  Future<List<Task>> searchTasks(String query) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'title LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'priority DESC, createdAt DESC',
      );
      return maps.map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al buscar tareas: $e');
    }
  }

  /// Marcar tarea como completada
  Future<int> completeTask(String id) async {
    try {
      final db = await database;
      return await db.update(
        'tasks',
        {
          'status': TaskStatus.completed.name,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Error al completar tarea: $e');
    }
  }

  /// Archivar tarea
  Future<int> archiveTask(String id) async {
    try {
      final db = await database;
      return await db.update(
        'tasks',
        {
          'status': TaskStatus.completed.name,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Error al archivar tarea: $e');
    }
  }

  /// Cerrar la base de datos
  @override
  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Resetear la base de datos (CUIDADO: Borra todos los datos)
  Future<void> resetDatabase() async {
    try {
      // Cerrar conexión actual
      await closeDatabase();
      
      // Obtener ruta de la base de datos
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'mi_agenda.db');
      
      // Eliminar archivo de base de datos
      await deleteDatabase(path);
      
      // Reinicializar
      _database = await _initDatabase();
      
      print('✅ Base de datos reseteada correctamente');
    } catch (e) {
      print('❌ Error al resetear base de datos: $e');
      throw DatabaseException('Error al resetear base de datos: $e');
    }
  }

  /// Verificar integridad de la base de datos
  Future<bool> checkDatabaseIntegrity() async {
    try {
      final db = await database;
      
      // Verificar integridad de SQLite
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.isEmpty || result.first.values.first != 'ok') {
        print('❌ Base de datos corrupta');
        return false;
      }
      
      // Verificar existencia de tablas principales
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      final tableNames = tables.map((t) => t['name']).toSet();
      
      if (!tableNames.contains('events') || 
          !tableNames.contains('categories') || 
          !tableNames.contains('tasks')) {
        print('❌ Faltan tablas principales');
        return false;
      }
      
      print('✅ Base de datos íntegra');
      return true;
    } catch (e) {
      print('❌ Error al verificar integridad: $e');
      return false;
    }
  }
  
  // ==================== OPERACIONES DE POMODORO ====================
  
  /// Insertar una nueva sesión Pomodoro
  @override
  Future<int> insertPomodoroSession(PomodoroSession session) async {
    try {
      final db = await database;
      return await db.insert('pomodoro_sessions', session.toMap());
    } catch (e) {
      throw DatabaseException('Error al insertar sesión Pomodoro: $e');
    }
  }
  
  /// Actualizar una sesión Pomodoro existente
  @override
  Future<int> updatePomodoroSession(PomodoroSession session) async {
    try {
      final db = await database;
      return await db.update(
        'pomodoro_sessions',
        session.toMap(),
        where: 'id = ?',
        whereArgs: [session.id],
      );
    } catch (e) {
      throw DatabaseException('Error al actualizar sesión Pomodoro: $e');
    }
  }
  
  /// Eliminar una sesión Pomodoro
  @override
  Future<int> deletePomodoroSession(String id) async {
    try {
      final db = await database;
      return await db.delete(
        'pomodoro_sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Error al eliminar sesión Pomodoro: $e');
    }
  }
  
  /// Obtener todas las sesiones Pomodoro
  @override
  Future<List<PomodoroSession>> getAllPomodoroSessions() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'pomodoro_sessions',
        orderBy: 'startTime DESC',
      );
      return maps.map((map) => PomodoroSession.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener sesiones Pomodoro: $e');
    }
  }
  
  /// Obtener sesión Pomodoro por ID
  @override
  Future<PomodoroSession?> getPomodoroSessionById(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'pomodoro_sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isEmpty) return null;
      return PomodoroSession.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Error al obtener sesión Pomodoro por ID: $e');
    }
  }
  
  /// Obtener sesiones Pomodoro por rango de fechas
  @override
  Future<List<PomodoroSession>> getPomodoroSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await database;
      final startMillis = startDate.millisecondsSinceEpoch;
      final endMillis = endDate.millisecondsSinceEpoch;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'pomodoro_sessions',
        where: 'startTime >= ? AND startTime <= ?',
        whereArgs: [startMillis, endMillis],
        orderBy: 'startTime DESC',
      );
      
      return maps.map((map) => PomodoroSession.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener sesiones Pomodoro por rango: $e');
    }
  }
  
  /// Obtener sesiones Pomodoro de hoy
  @override
  Future<List<PomodoroSession>> getTodayPomodoroSessions() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return await getPomodoroSessionsByDateRange(startOfDay, endOfDay);
  }
  
  /// Obtener sesiones Pomodoro por tarea
  @override
  Future<List<PomodoroSession>> getPomodoroSessionsByTask(String taskId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'pomodoro_sessions',
        where: 'taskId = ?',
        whereArgs: [taskId],
        orderBy: 'startTime DESC',
      );
      
      return maps.map((map) => PomodoroSession.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener sesiones Pomodoro por tarea: $e');
    }
  }
  
  /// Obtener estadísticas de Pomodoro
  @override
  Future<Map<String, dynamic>> getPomodoroStats() async {
    try {
      final db = await database;
      
      // Total de sesiones
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pomodoro_sessions WHERE endTime IS NOT NULL'
      );
      final totalSessions = Sqflite.firstIntValue(totalResult) ?? 0;
      
      // Sesiones de trabajo completadas
      final workResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM pomodoro_sessions WHERE sessionType = ? AND endTime IS NOT NULL",
        [SessionType.work.toString()],
      );
      final workSessions = Sqflite.firstIntValue(workResult) ?? 0;
      
      // Tiempo total en minutos
      final timeResult = await db.rawQuery(
        'SELECT SUM(duration) as total FROM pomodoro_sessions WHERE endTime IS NOT NULL'
      );
      final totalSeconds = Sqflite.firstIntValue(timeResult) ?? 0;
      final totalMinutes = totalSeconds ~/ 60;
      
      // Sesiones de hoy
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pomodoro_sessions WHERE startTime >= ? AND endTime IS NOT NULL',
        [startOfDay],
      );
      final todaySessions = Sqflite.firstIntValue(todayResult) ?? 0;
      
      return {
        'totalSessions': totalSessions,
        'workSessions': workSessions,
        'totalMinutes': totalMinutes,
        'todaySessions': todaySessions,
      };
    } catch (e) {
      throw DatabaseException('Error al obtener estadísticas Pomodoro: $e');
    }
  }
  
  // ==================== OPERACIONES DE TASK TEMPLATES ====================
  
  /// Insertar un nuevo template
  @override
  Future<int> insertTaskTemplate(TaskTemplate template) async {
    try {
      final db = await database;
      return await db.insert('task_templates', template.toMap());
    } catch (e) {
      throw DatabaseException('Error al insertar template: $e');
    }
  }
  
  /// Actualizar un template existente
  @override
  Future<int> updateTaskTemplate(TaskTemplate template) async {
    try {
      final db = await database;
      return await db.update(
        'task_templates',
        template.toMap(),
        where: 'id = ?',
        whereArgs: [template.id],
      );
    } catch (e) {
      throw DatabaseException('Error al actualizar template: $e');
    }
  }
  
  /// Eliminar un template
  @override
  Future<int> deleteTaskTemplate(String templateId) async {
    try {
      final db = await database;
      return await db.delete(
        'task_templates',
        where: 'id = ?',
        whereArgs: [templateId],
      );
    } catch (e) {
      throw DatabaseException('Error al eliminar template: $e');
    }
  }
  
  /// Obtener todos los templates
  @override
  Future<List<TaskTemplate>> getAllTaskTemplates() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'task_templates',
        orderBy: 'created_at DESC',
      );
      return maps.map((map) => TaskTemplate.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Error al obtener templates: $e');
    }
  }
  
  /// Obtener template por ID
  @override
  Future<TaskTemplate?> getTaskTemplateById(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'task_templates',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isEmpty) return null;
      return TaskTemplate.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Error al obtener template: $e');
    }
  }
}

/// Excepción personalizada para errores de base de datos
class DatabaseException implements Exception {
  final String message;
  
  DatabaseException(this.message);
  
  @override
  String toString() => 'DatabaseException: $message';
}
