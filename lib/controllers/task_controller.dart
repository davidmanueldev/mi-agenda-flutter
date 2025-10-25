import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart' as model;
import '../services/database_interface.dart';
import '../services/database_service_hybrid_v2.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';

/// Controlador para gestión de tareas
/// Implementa patrón Provider para gestión de estado
class TaskController with ChangeNotifier {
  final DatabaseInterface _database;
  final NotificationService _notificationService;
  final ConnectivityService _connectivityService = ConnectivityService();
  
  List<Task> _tasks = [];
  List<model.Category> _categories = [];
  bool _isLoading = false;
  bool _isOnline = false;
  String? _errorMessage;
  
  // Filtros
  TaskStatus? _statusFilter;
  TaskPriority? _priorityFilter;
  String? _categoryFilter;
  String _searchQuery = '';
  
  // Getters
  List<Task> get tasks => _getFilteredTasks();
  List<model.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String? get errorMessage => _errorMessage;
  TaskStatus? get statusFilter => _statusFilter;
  TaskPriority? get priorityFilter => _priorityFilter;
  String? get categoryFilter => _categoryFilter;
  String get searchQuery => _searchQuery;
  
  /// Constructor con inyección de dependencias
  TaskController({
    required DatabaseInterface databaseService,
    required NotificationService notificationService,
  }) : _database = databaseService,
       _notificationService = notificationService {
    _initialize();
  }
  
  /// Inicializar controller
  Future<void> _initialize() async {
    _setLoading(true);
    
    try {
      // Configurar callback para cambios de datos (solo si es DatabaseServiceHybridV2)
      if (_database is DatabaseServiceHybridV2) {
        (_database as DatabaseServiceHybridV2).onDataChanged = () {
          _loadTasks();
        };
      }
      
      // Cargar datos iniciales
      await Future.wait([
        _loadTasks(),
        _loadCategories(),
      ]);
      
      // Escuchar cambios de conectividad
      _connectivityService.connectionStream.listen((isOnline) {
        _isOnline = isOnline;
        notifyListeners();
      });
      
      // Verificar conectividad inicial
      _isOnline = await _connectivityService.checkConnectivity();
      
    } catch (e) {
      _setError('Error al inicializar: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Cargar todas las tareas
  Future<void> _loadTasks() async {
    try {
      _tasks = await _database.getAllTasks();
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar tareas: $e');
    }
  }
  
  /// Cargar categorías
  Future<void> _loadCategories() async {
    try {
      _categories = await _database.getAllCategories();
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar categorías: $e');
    }
  }
  
  /// Obtener tareas filtradas
  List<Task> _getFilteredTasks() {
    var filtered = List<Task>.from(_tasks);
    
    // Filtrar por estado
    if (_statusFilter != null) {
      filtered = filtered.where((task) => task.status == _statusFilter).toList();
    }
    
    // Filtrar por prioridad
    if (_priorityFilter != null) {
      filtered = filtered.where((task) => task.priority == _priorityFilter).toList();
    }
    
    // Filtrar por categoría
    if (_categoryFilter != null) {
      filtered = filtered.where((task) => task.category == _categoryFilter).toList();
    }
    
    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(query) ||
               task.description.toLowerCase().contains(query);
      }).toList();
    }
    
    // Ordenar: vencidas primero, luego por prioridad y fecha
    filtered.sort((a, b) {
      // Tareas vencidas primero
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      
      // Luego por prioridad (urgente primero)
      final priorityCompare = b.priority.value.compareTo(a.priority.value);
      if (priorityCompare != 0) return priorityCompare;
      
      // Luego por fecha de vencimiento
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      
      // Por último por fecha de creación (más recientes primero)
      return b.createdAt.compareTo(a.createdAt);
    });
    
    return filtered;
  }
  
  /// Crear nueva tarea
  Future<bool> createTask(Task task) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _database.insertTask(task);
      
      // Programar notificación si tiene fecha de vencimiento o recordatorio
      if (task.dueDate != null || task.reminderDateTime != null) {
        await _notificationService.scheduleTaskNotification(task);
      }
      
      await _loadTasks();
      return true;
    } catch (e) {
      _setError('Error al crear tarea: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Actualizar tarea existente
  Future<bool> updateTask(Task task) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _database.updateTask(task);
      
      // Actualizar notificación
      await _notificationService.updateTaskNotification(task);
      
      await _loadTasks();
      return true;
    } catch (e) {
      _setError('Error al actualizar tarea: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Eliminar tarea
  Future<bool> deleteTask(String taskId) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Cancelar notificaciones antes de eliminar
      await _notificationService.cancelTaskNotification(taskId);
      
      await _database.deleteTask(taskId);
      await _loadTasks();
      return true;
    } catch (e) {
      _setError('Error al eliminar tarea: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Obtener tarea por ID
  Task? getTaskById(String taskId) {
    try {
      return _tasks.firstWhere((task) => task.id == taskId);
    } catch (e) {
      return null;
    }
  }
  
  /// Obtener tareas pendientes que vencen hoy
  /// Útil para sugerencias en PomodoroScreen
  List<Task> getTodaysTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    return _tasks.where((task) {
      // Solo tareas pendientes
      if (task.status != TaskStatus.pending) return false;
      
      // Filtrar por fecha de vencimiento == HOY
      if (task.dueDate == null) return false;
      
      final dueDate = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      
      return dueDate.isAtSameMomentAs(today) || 
             (dueDate.isBefore(tomorrow) && dueDate.isAfter(today.subtract(const Duration(days: 1))));
    }).toList()
      ..sort((a, b) {
        // Ordenar por prioridad (urgente primero)
        final priorityCompare = b.priority.value.compareTo(a.priority.value);
        if (priorityCompare != 0) return priorityCompare;
        
        // Luego por pomodoros estimados (menos pomodoros primero = quick wins)
        return a.estimatedPomodoros.compareTo(b.estimatedPomodoros);
      });
  }
  
  /// Marcar tarea como completada
  Future<bool> completeTask(String taskId) async {
    _clearError();
    
    try {
      final task = await _database.getTaskById(taskId);
      if (task == null) {
        _setError('Tarea no encontrada');
        return false;
      }
      
      final updatedTask = task.copyWith(
        status: TaskStatus.completed,
        updatedAt: DateTime.now(),
      );
      
      // Cancelar notificaciones al completar
      await _notificationService.cancelTaskNotification(taskId);
      
      await _database.updateTask(updatedTask);
      await _loadTasks();
      return true;
    } catch (e) {
      _setError('Error al completar tarea: $e');
      return false;
    }
  }
  
  /// Archivar tarea (marcar como completada)
  Future<bool> archiveTask(String taskId) async {
    _clearError();
    
    try {
      final task = await _database.getTaskById(taskId);
      if (task == null) {
        _setError('Tarea no encontrada');
        return false;
      }
      
      final updatedTask = task.copyWith(
        status: TaskStatus.completed,
        updatedAt: DateTime.now(),
      );
      
      await _database.updateTask(updatedTask);
      await _loadTasks();
      return true;
    } catch (e) {
      _setError('Error al archivar tarea: $e');
      return false;
    }
  }
  
  /// Toggle estado de sub-tarea
  Future<bool> toggleTaskStep(Task task, int subTaskIndex) async {
    try {
      final steps = List<TaskStep>.from(task.steps);
      steps[subTaskIndex] = steps[subTaskIndex].copyWith(
        isCompleted: !steps[subTaskIndex].isCompleted,
      );
      
      final updatedTask = task.copyWith(steps: steps);
      return await updateTask(updatedTask);
    } catch (e) {
      _setError('Error al actualizar sub-tarea: $e');
      return false;
    }
  }
  
  /// Agregar sub-tarea
  Future<bool> addTaskStep(Task task, String title) async {
    try {
      final steps = List<TaskStep>.from(task.steps);
      steps.add(TaskStep(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
      ));
      
      final updatedTask = task.copyWith(steps: steps);
      return await updateTask(updatedTask);
    } catch (e) {
      _setError('Error al agregar sub-tarea: $e');
      return false;
    }
  }
  
  /// Eliminar sub-tarea
  Future<bool> removeTaskStep(Task task, int subTaskIndex) async {
    try {
      final steps = List<TaskStep>.from(task.steps);
      steps.removeAt(subTaskIndex);
      
      final updatedTask = task.copyWith(steps: steps);
      return await updateTask(updatedTask);
    } catch (e) {
      _setError('Error al eliminar sub-tarea: $e');
      return false;
    }
  }
  
  // ==================== FILTROS ====================
  
  /// Establecer filtro por estado
  void setStatusFilter(TaskStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }
  
  /// Establecer filtro por prioridad
  void setPriorityFilter(TaskPriority? priority) {
    _priorityFilter = priority;
    notifyListeners();
  }
  
  /// Establecer filtro por categoría
  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }
  
  /// Establecer búsqueda
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  
  /// Limpiar todos los filtros
  void clearFilters() {
    _statusFilter = null;
    _priorityFilter = null;
    _categoryFilter = null;
    _searchQuery = '';
    notifyListeners();
  }
  
  // ==================== CONSULTAS ESPECIALES ====================
  
  /// Obtener tareas vencidas
  List<Task> get overdueTasks {
    return tasks.where((task) => task.isOverdue).toList();
  }
  
  /// Obtener tareas de hoy
  Future<List<Task>> getTodayTasks() async {
    try {
      return await _database.getTodayTasks();
    } catch (e) {
      _setError('Error al obtener tareas de hoy: $e');
      return [];
    }
  }
  
  /// Obtener tareas pendientes
  List<Task> get pendingTasks {
    return tasks.where((task) => task.status == TaskStatus.pending).toList();
  }
  
  /// Obtener tareas completadas
  List<Task> get completedTasks {
    return tasks.where((task) => task.status == TaskStatus.completed).toList();
  }
  
  /// Obtener tareas archivadas
  List<Task> get archivedTasks {
    return tasks.where((task) => task.status == TaskStatus.completed).toList();
  }
  
  /// Obtener tareas por prioridad urgente
  List<Task> get urgentTasks {
    return tasks.where((task) => 
      task.priority == TaskPriority.urgent && 
      task.status == TaskStatus.pending
    ).toList();
  }
  
  // ==================== ESTADÍSTICAS ====================
  
  /// Total de tareas
  int get totalTasks => _tasks.length;
  
  /// Total de tareas pendientes
  int get totalPendingTasks => pendingTasks.length;
  
  /// Total de tareas completadas
  int get totalCompletedTasks => completedTasks.length;
  
  /// Total de tareas vencidas
  int get totalOverdueTasks => overdueTasks.length;
  
  /// Porcentaje de completadas
  double get completionRate {
    if (_tasks.isEmpty) return 0.0;
    return (totalCompletedTasks / totalTasks) * 100;
  }
  
  /// Obtener tareas por categoría
  Map<String, int> get tasksByCategory {
    final map = <String, int>{};
    for (final task in _tasks) {
      map[task.category] = (map[task.category] ?? 0) + 1;
    }
    return map;
  }
  
  /// Obtener tareas por prioridad
  Map<TaskPriority, int> get tasksByPriority {
    final map = <TaskPriority, int>{};
    for (final task in _tasks) {
      map[task.priority] = (map[task.priority] ?? 0) + 1;
    }
    return map;
  }
  
  // ==================== UTILIDADES ====================
  
  /// Recargar todas las tareas
  Future<void> refresh() async {
    _setLoading(true);
    await _loadTasks();
    _setLoading(false);
  }
  
  /// Establecer estado de carga
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Establecer mensaje de error
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
    print('❌ TaskController Error: $message');
  }
  
  /// Limpiar error
  void _clearError() {
    _errorMessage = null;
  }
  
  @override
  void dispose() {
    _database.closeDatabase();
    super.dispose();
  }
}
