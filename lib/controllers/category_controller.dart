import 'package:flutter/material.dart';
import '../models/category.dart' as model;
import '../services/database_interface.dart';
import '../services/database_service_hybrid_v2.dart';

/// Controlador para gestión de categorías
/// Implementa patrón Provider para gestión de estado
class CategoryController with ChangeNotifier {
  final DatabaseInterface _database;
  
  List<model.Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<model.Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  /// Constructor con inyección de dependencias
  CategoryController({
    required DatabaseInterface databaseService,
  }) : _database = databaseService {
    _initialize();
  }
  
  /// Inicializar controlador
  Future<void> _initialize() async {
    // Configurar listener para cambios de Firebase (solo si es DatabaseServiceHybridV2)
    if (_database is DatabaseServiceHybridV2) {
      (_database as DatabaseServiceHybridV2).onDataChanged = () {
        // Recargar categorías cuando hay cambios en Firebase
        _loadCategories();
      };
    }
    
    await _loadCategories();
  }
  
  /// Cargar todas las categorías
  Future<void> _loadCategories() async {
    try {
      _categories = await _database.getAllCategories();
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar categorías: $e');
    }
  }
  
  /// Crear nueva categoría
  Future<bool> createCategory(model.Category category) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _database.insertCategory(category);
      await _loadCategories();
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
      await _database.updateCategory(category);
      await _loadCategories();
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
      await _database.deleteCategory(categoryId);
      await _loadCategories();
      return true;
    } catch (e) {
      _setError('Error al eliminar categoría: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Obtener categoría por ID
  Future<model.Category?> getCategoryById(String id) async {
    try {
      return await _database.getCategoryById(id);
    } catch (e) {
      _setError('Error al obtener categoría: $e');
      return null;
    }
  }
  
  /// Recargar categorías manualmente
  Future<void> refresh() async {
    await _loadCategories();
  }
  
  // ==================== MÉTODOS AUXILIARES ====================
  
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
  
  @override
  void dispose() {
    super.dispose();
  }
}
