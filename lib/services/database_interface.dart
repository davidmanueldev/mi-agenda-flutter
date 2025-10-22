import '../models/event.dart';
import '../models/category.dart' as model;

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
  
  /// Obtener todas las categorías
  Future<List<model.Category>> getAllCategories();
  
  /// Obtener categoría por ID
  Future<model.Category?> getCategoryById(String id);
  
  /// Eliminar una categoría
  Future<int> deleteCategory(String id);
  
  // ==================== OPERACIONES DE MANTENIMIENTO ====================
  
  /// Obtener estadísticas de la base de datos
  Future<Map<String, int>> getDatabaseStats();
  
  /// Limpiar eventos antiguos
  Future<int> cleanupOldEvents();
  
  /// Cerrar la base de datos
  Future<void> closeDatabase();
}
