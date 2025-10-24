import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../models/category.dart' as model;
import '../services/database_interface.dart';
import '../services/database_service_hybrid_v2.dart';
import '../services/notification_service.dart';

/// Controlador principal para la gestión de eventos
/// Implementa el patrón MVC y manejo de estado con ChangeNotifier
class EventController extends ChangeNotifier {
  final DatabaseInterface _databaseService;
  final NotificationService _notificationService;

  // Estado interno del controlador
  List<Event> _events = [];
  List<model.Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  /// Constructor que inyecta las dependencias
  EventController({
    required DatabaseInterface databaseService,
    required NotificationService notificationService,
  }) : _databaseService = databaseService,
       _notificationService = notificationService {
    _initializeController();
    _setupDatabaseListener();
  }
  
  /// Configurar listener para cambios de Firebase
  void _setupDatabaseListener() {
    if (_databaseService is DatabaseServiceHybridV2) {
      final hybridService = _databaseService;
      hybridService.onDataChanged = () {
        // Recargar eventos cuando Firebase notifica cambios
        print('🔄 Datos cambiados desde Firebase, recargando...');
        loadEvents();
      };
    }
  }

  // Getters para acceso controlado al estado
  List<Event> get events => List.unmodifiable(_events);
  List<model.Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;

  /// Eventos filtrados por la fecha seleccionada
  List<Event> get eventsForSelectedDate {
    return _events.where((event) {
      return event.startTime.year == _selectedDate.year &&
             event.startTime.month == _selectedDate.month &&
             event.startTime.day == _selectedDate.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Eventos próximos (siguientes 7 días)
  List<Event> get upcomingEvents {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    
    return _events.where((event) {
      return event.startTime.isAfter(now) && 
             event.startTime.isBefore(nextWeek);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Inicialización del controlador
  Future<void> _initializeController() async {
    await loadCategories();
    await loadEvents();
  }

  /// Cambiar la fecha seleccionada
  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Cargar todos los eventos desde la base de datos
  Future<void> loadEvents() async {
    _setLoading(true);
    _clearError();
    
    try {
      _events = await _databaseService.getAllEvents();
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar eventos: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Cargar todas las categorías
  Future<void> loadCategories() async {
    try {
      _categories = await _databaseService.getAllCategories();
    } catch (e) {
      _setError('Error al cargar categorías: $e');
    }
  }

  /// Crear un nuevo evento
  Future<bool> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String categoryId,
  }) async {
    _clearError();
    
    try {
      // Validaciones
      if (title.isEmpty) {
        _setError('El título es requerido');
        return false;
      }

      if (startTime.isAfter(endTime)) {
        _setError('La fecha de inicio debe ser anterior a la de fin');
        return false;
      }

      // Verificar conflictos de horario
      if (_hasScheduleConflict(startTime, endTime)) {
        _setError('Existe un conflicto de horario con otro evento');
        return false;
      }

      final event = Event.create(
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        category: categoryId,
      );

      await _databaseService.insertEvent(event);
      await _notificationService.scheduleEventNotification(event);
      
      _events.add(event);
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('Error al crear evento: $e');
      return false;
    }
  }

  /// Actualizar un evento existente
  Future<bool> updateEvent(String eventId, {
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? categoryId,
    bool? isCompleted,
  }) async {
    _clearError();
    
    try {
      final eventIndex = _events.indexWhere((e) => e.id == eventId);
      if (eventIndex == -1) {
        _setError('Evento no encontrado');
        return false;
      }

      final currentEvent = _events[eventIndex];
      final updatedEvent = currentEvent.copyWith(
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        category: categoryId,
        isCompleted: isCompleted,
      );

      // Validar el evento actualizado
      if (!updatedEvent.isValid) {
        _setError('Datos del evento inválidos');
        return false;
      }

      // Verificar conflictos solo si cambió la hora
      if ((startTime != null || endTime != null) && 
          _hasScheduleConflict(updatedEvent.startTime, updatedEvent.endTime, excludeEventId: eventId)) {
        _setError('Existe un conflicto de horario con otro evento');
        return false;
      }

      await _databaseService.updateEvent(updatedEvent);
      await _notificationService.updateEventNotification(updatedEvent);
      
      _events[eventIndex] = updatedEvent;
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('Error al actualizar evento: $e');
      return false;
    }
  }

  /// Eliminar un evento
  Future<bool> deleteEvent(String eventId) async {
    _clearError();
    
    try {
      await _databaseService.deleteEvent(eventId);
      await _notificationService.cancelEventNotification(eventId);
      
      _events.removeWhere((event) => event.id == eventId);
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('Error al eliminar evento: $e');
      return false;
    }
  }

  /// Marcar evento como completado
  Future<void> toggleEventCompletion(String eventId) async {
    final event = _events.firstWhere((e) => e.id == eventId);
    await updateEvent(eventId, isCompleted: !event.isCompleted);
  }

  /// Buscar eventos por título o descripción
  List<Event> searchEvents(String query) {
    if (query.isEmpty) return events;
    
    final lowerQuery = query.toLowerCase();
    return _events.where((event) {
      return event.title.toLowerCase().contains(lowerQuery) ||
             event.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Obtener eventos por categoría
  List<Event> getEventsByCategory(String categoryId) {
    return _events.where((event) => event.category == categoryId).toList();
  }

  /// Verificar conflictos de horario
  bool _hasScheduleConflict(DateTime startTime, DateTime endTime, {String? excludeEventId}) {
    return _events.any((event) {
      if (excludeEventId != null && event.id == excludeEventId) {
        return false;
      }
      
      // Verificar solapamiento de horarios
      return (startTime.isBefore(event.endTime) && endTime.isAfter(event.startTime));
    });
  }

  /// Crear nueva categoría
  Future<bool> createCategory(model.Category category) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _databaseService.insertCategory(category);
      
      // Actualizar lista local
      _categories = [..._categories, category];
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('Error al crear categoría: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualizar una categoría existente
  Future<bool> updateCategory(model.Category category) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _databaseService.updateCategory(category);
      
      // Actualizar lista local
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories = [
          ..._categories.sublist(0, index),
          category,
          ..._categories.sublist(index + 1),
        ];
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _setError('Error al actualizar categoría: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Eliminar una categoría
  Future<bool> deleteCategory(String categoryId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _databaseService.deleteCategory(categoryId);
      
      // Actualizar lista local
      _categories = _categories.where((c) => c.id != categoryId).toList();
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('Error al eliminar categoría: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Métodos auxiliares para manejo de estado
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Limpiar recursos al destruir el controlador
  @override
  void dispose() {
    super.dispose();
  }
}
