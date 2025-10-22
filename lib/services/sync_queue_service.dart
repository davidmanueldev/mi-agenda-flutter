import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipo de operación pendiente
enum SyncOperation {
  createEvent,
  updateEvent,
  deleteEvent,
  createCategory,
  deleteCategory,
  createTask,
  updateTask,
  deleteTask,
}

/// Item en cola de sincronización
class SyncQueueItem {
  final String id;
  final SyncOperation operation;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  
  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.data,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation.toString(),
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };
  
  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'],
      operation: SyncOperation.values.firstWhere(
        (e) => e.toString() == json['operation']
      ),
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Servicio para manejar cola de sincronización offline
class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  static const String _queueKey = 'sync_queue';
  
  List<SyncQueueItem> _queue = [];
  
  factory SyncQueueService() {
    return _instance;
  }
  
  SyncQueueService._internal();
  
  /// Cargar cola desde almacenamiento
  Future<void> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue = decoded.map((item) => SyncQueueItem.fromJson(item)).toList();
        print('Cola de sincronización cargada: ${_queue.length} items');
      }
    } catch (e) {
      print('Error al cargar cola: $e');
    }
  }
  
  /// Guardar cola en almacenamiento
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((item) => item.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      print('Error al guardar cola: $e');
    }
  }
  
  /// Agregar operación a la cola
  Future<void> addToQueue(SyncOperation operation, Map<String, dynamic> data) async {
    final item = SyncQueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operation: operation,
      data: data,
      timestamp: DateTime.now(),
    );
    
    _queue.add(item);
    await _saveQueue();
    print('Agregado a cola: ${operation.toString()}');
  }
  
  /// Obtener todos los items de la cola
  List<SyncQueueItem> getQueue() {
    return List.unmodifiable(_queue);
  }
  
  /// Remover item de la cola
  Future<void> removeFromQueue(String itemId) async {
    _queue.removeWhere((item) => item.id == itemId);
    await _saveQueue();
  }
  
  /// Limpiar toda la cola
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
  }
  
  /// Verificar si hay items pendientes
  bool hasPendingItems() {
    return _queue.isNotEmpty;
  }
  
  /// Obtener número de items pendientes
  int get pendingCount => _queue.length;
}
