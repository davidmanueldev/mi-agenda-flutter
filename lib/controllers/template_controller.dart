import 'package:flutter/material.dart';
import '../models/task_template.dart';
import '../services/database_interface.dart';
import '../services/database_service_hybrid_v2.dart';

/// Controlador para gestión de plantillas de tareas
/// Implementa patrón Provider para gestión de estado
class TemplateController with ChangeNotifier {
  final DatabaseInterface _database;
  
  List<TaskTemplate> _templates = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<TaskTemplate> get templates => List.unmodifiable(_templates);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  /// Constructor con inyección de dependencias
  TemplateController({
    required DatabaseInterface databaseService,
  }) : _database = databaseService {
    _initialize();
  }
  
  /// Inicializar controlador
  Future<void> _initialize() async {
    // Registrar callback para cambios de datos si es híbrido
    if (_database case DatabaseServiceHybridV2 hybridDb) {
      hybridDb.onDataChanged = () {
        debugPrint('🔄 Templates: Datos cambiados desde Firebase, recargando...');
        _loadTemplates();
      };
    }
    
    await _loadTemplates();
  }
  
  /// Cargar todas las plantillas
  Future<void> _loadTemplates() async {
    try {
      _templates = await _database.getAllTaskTemplates();
      _templates.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Más recientes primero
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error al cargar templates: $e');
      _setError('Error al cargar plantillas: $e');
    }
  }
  
  /// Crear nueva plantilla
  Future<bool> createTemplate(TaskTemplate template) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _database.insertTaskTemplate(template);
      await _loadTemplates();
      debugPrint('✅ Template creado: ${template.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error al crear template: $e');
      _setError('Error al crear plantilla: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Actualizar una plantilla existente
  Future<bool> updateTemplate(TaskTemplate template) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _database.updateTaskTemplate(template);
      await _loadTemplates();
      debugPrint('✅ Template actualizado: ${template.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error al actualizar template: $e');
      _setError('Error al actualizar plantilla: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Eliminar una plantilla
  Future<bool> deleteTemplate(String templateId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _database.deleteTaskTemplate(templateId);
      await _loadTemplates();
      debugPrint('✅ Template eliminado: $templateId');
      return true;
    } catch (e) {
      debugPrint('❌ Error al eliminar template: $e');
      _setError('Error al eliminar plantilla: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Obtener plantilla por ID
  Future<TaskTemplate?> getTemplateById(String id) async {
    try {
      return await _database.getTaskTemplateById(id);
    } catch (e) {
      debugPrint('❌ Error al obtener template: $e');
      return null;
    }
  }
  
  /// Recargar plantillas manualmente
  Future<void> refresh() async {
    await _loadTemplates();
  }
  
  // ==================== MÉTODOS AUXILIARES ====================
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
