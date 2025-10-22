import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio para detectar y monitorear la conectividad a internet
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();
  
  StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  
  factory ConnectivityService() {
    return _instance;
  }
  
  ConnectivityService._internal() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  /// Stream para escuchar cambios de conectividad
  Stream<bool> get connectionStream => _connectionStatusController.stream;
  
  /// Estado actual de conectividad
  bool get isOnline => _isOnline;
  
  /// Inicializar y verificar conectividad actual
  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print('Error al verificar conectividad: $e');
      _isOnline = false;
    }
  }
  
  /// Actualizar estado de conectividad
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    
    // Considerar online si hay cualquier tipo de conexión
    _isOnline = results.any((result) => 
      result != ConnectivityResult.none
    );
    
    // Notificar solo si cambió el estado
    if (wasOnline != _isOnline) {
      print('Estado de conectividad cambió: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      _connectionStatusController.add(_isOnline);
    }
  }
  
  /// Verificar manualmente la conectividad
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
      return _isOnline;
    } catch (e) {
      print('Error al verificar conectividad: $e');
      return false;
    }
  }
  
  /// Cerrar streams
  void dispose() {
    _connectionStatusController.close();
  }
}
