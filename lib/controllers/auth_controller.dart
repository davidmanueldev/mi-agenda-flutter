import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/firebase_service.dart';
import '../services/database_service.dart';

/// Controlador de autenticación
/// Gestiona el estado de autenticación del usuario
class AuthController with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseService _localService = DatabaseService();

  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Verificar estado de autenticación al iniciar
  Future<void> checkAuthStatus() async {
    _setLoading(true);
    _clearError();

    try {
      print('🔐 Verificando estado de autenticación...');
      final user = await _firebaseService.getCurrentUser();
      
      if (user != null) {
        print('✅ Usuario encontrado: ${user.email} (${user.id})');
        _currentUser = user;
        // Actualizar last login
        await _updateLastLogin(user.id);
      } else {
        print('⚠️  No hay usuario autenticado');
        _currentUser = null;
      }
      notifyListeners();
    } catch (e) {
      print('❌ Error al verificar sesión: $e');
      _setError('Error al verificar sesión: $e');
      _currentUser = null;
    } finally {
      _setLoading(false);
    }
  }

  /// Registrar nuevo usuario
  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _firebaseService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (user != null) {
        _currentUser = user;
        // Guardar en SQLite
        await _localService.insertUser(user);
        notifyListeners();
        return true;
      } else {
        _setError('Error al crear usuario');
        return false;
      }
    } catch (e) {
      _setError('Error al registrar: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Iniciar sesión
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _firebaseService.signIn(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        // Actualizar en SQLite
        await _localService.upsertUser(user);
        notifyListeners();
        return true;
      } else {
        _setError('Credenciales inválidas');
        return false;
      }
    } catch (e) {
      _setError('Error al iniciar sesión: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cerrar sesión
  Future<void> logout() async {
    _setLoading(true);
    _clearError();

    try {
      await _firebaseService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _setError('Error al cerrar sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Enviar email de recuperación de contraseña
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _firebaseService.resetPassword(email);
      return true;
    } catch (e) {
      _setError('Error al enviar email: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualizar perfil de usuario (alias para mantener compatibilidad)
  Future<bool> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    return updateUserProfile(displayName: displayName, photoURL: photoURL);
  }

  /// Actualizar perfil de usuario
  Future<bool> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final updatedUser = await _firebaseService.updateUserProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      if (updatedUser != null) {
        _currentUser = updatedUser;
        await _localService.upsertUser(updatedUser);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Error al actualizar perfil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cambiar contraseña
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      await _firebaseService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _setError('Error al cambiar contraseña: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Eliminar cuenta de usuario
  Future<bool> deleteAccount() async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      // Eliminar de Firebase
      await _firebaseService.deleteUserAccount();
      
      // Eliminar de SQLite
      await _localService.deleteUser(_currentUser!.id);
      
      _currentUser = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error al eliminar cuenta: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualizar último login
  Future<void> _updateLastLogin(String userId) async {
    try {
      await _localService.updateUserLastLogin(userId);
    } catch (e) {
      debugPrint('Error al actualizar last login: $e');
    }
  }

  /// Setters privados
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
  }
}
