import '../models/event.dart';
import '../models/category.dart' as model;
import '../models/task.dart';

/// Interfaz común para servicios de base de datos
/// Permite intercambiar entre SQLite, Firebase, o implementaciones híbridas
abstract class DatabaseInterface {
  
  // ==================== OPERACIONES DE EVENTOS ====================
  
  /// Insertar un nuevo evento
  Future<int> insertEvent(Event event);
  
  /// Obtener todos los eventos
  Future<List<Event>> getAllEvents();
  
  /// Actualizar un evento existente
  Future<int> updateEvent(Event event);
  
  /// Eliminar un evento
  Future<int> deleteEvent(String eventId);
  
  /// Obtener eventos por fecha específica
  Future<List<Event>> getEventsByDate(DateTime date);
  
  /// Obtener eventos por rango de fechas
  Future<List<Event>> getEventsByDateRange(DateTime startDate, DateTime endDate);
  
  /// Obtener evento por ID
  Future<Event?> getEventById(String id);
  
  /// Buscar eventos por texto
  Future<List<Event>> searchEvents(String query);
  
  // ==================== OPERACIONES DE CATEGORÍAS ====================
  
  /// Insertar una nueva categoría
  Future<int> insertCategory(model.Category category);
  
  /// Actualizar una categoría existente
  Future<int> updateCategory(model.Category category);
  
  /// Obtener todas las categorías
  Future<List<model.Category>> getAllCategories();
  
  /// Obtener categoría por ID
  Future<model.Category?> getCategoryById(String id);
  
  /// Eliminar una categoría
  Future<int> deleteCategory(String id);
  
  // ==================== OPERACIONES DE TAREAS ====================
  
  /// Insertar una nueva tarea
  Future<int> insertTask(Task task);
  
  /// Actualizar una tarea existente
  Future<int> updateTask(Task task);
  
  /// Eliminar una tarea
  Future<int> deleteTask(String id);
  
  /// Obtener todas las tareas
  Future<List<Task>> getAllTasks();
  
  /// Obtener tarea por ID
  Future<Task?> getTaskById(String id);
  
  /// Obtener tareas por estado
  Future<List<Task>> getTasksByStatus(TaskStatus status);
  
  /// Obtener tareas por prioridad
  Future<List<Task>> getTasksByPriority(TaskPriority priority);
  
  /// Obtener tareas por categoría
  Future<List<Task>> getTasksByCategory(String category);
  
  /// Obtener tareas vencidas
  Future<List<Task>> getOverdueTasks();
  
  /// Obtener tareas de hoy
  Future<List<Task>> getTodayTasks();
  
  /// Buscar tareas por texto
  Future<List<Task>> searchTasks(String query);
  
  // ==================== OPERACIONES DE MANTENIMIENTO ====================
  
  /// Obtener estadísticas de la base de datos
  Future<Map<String, int>> getDatabaseStats();
  
  /// Limpiar eventos antiguos
  Future<int> cleanupOldEvents();
  
  /// Cerrar la base de datos
  Future<void> closeDatabase();
}
