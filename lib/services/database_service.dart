import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/event.dart';
import '../models/category.dart' as model;
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
      version: 1,
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

    // Índices para optimizar consultas
    await db.execute('CREATE INDEX idx_events_startTime ON events(startTime)');
    await db.execute('CREATE INDEX idx_events_category ON events(category)');
    await db.execute('CREATE INDEX idx_events_date ON events(startTime, endTime)');
  }

  /// Manejo de actualizaciones de esquema de base de datos
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Implementar migraciones futuras aquí
    if (oldVersion < newVersion) {
      // Ejemplo de migración para versión futura
      // if (oldVersion < 2) {
      //   await db.execute('ALTER TABLE events ADD COLUMN reminder INTEGER');
      // }
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

  /// Cerrar la base de datos
  @override
  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
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
