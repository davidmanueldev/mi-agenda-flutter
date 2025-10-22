import 'dart:convert';
import 'dart:math';

/// Utilidades de seguridad para la aplicación
/// Implementa mejores prácticas de seguridad y validación
class SecurityUtils {
  
  /// Generar ID único y seguro para eventos
  static String generateSecureId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List.generate(8, (index) => random.nextInt(256));
    
    final combined = '$timestamp${randomBytes.join()}';
    final encoded = base64.encode(utf8.encode(combined));
    
    // Limpiar caracteres especiales para usar como ID
    return encoded
        .replaceAll('+', 'A')
        .replaceAll('/', 'B')
        .replaceAll('=', 'C')
        .substring(0, 16);
  }

  /// Sanitizar entrada de texto para prevenir injection
  static String sanitizeInput(String input) {
    // Remover caracteres potencialmente peligrosos
    final cleaned = input
        .replaceAll(RegExp(r'[<>"\%;()&+]'), '')
        .trim();
    
    // Limitar longitud máxima
    return cleaned.length > 1000 
        ? cleaned.substring(0, 1000)
        : cleaned;
  }

  /// Validar formato de email (si se implementa autenticación)
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );
    return emailRegex.hasMatch(email);
  }

  /// Validar fortaleza de contraseña (si se implementa autenticación)
  static bool isStrongPassword(String password) {
    // Al menos 8 caracteres, una mayúscula, una minúscula, un número
    final passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$'
    );
    return passwordRegex.hasMatch(password);
  }

  /// Validar fecha para prevenir valores inválidos
  static bool isValidDate(DateTime? date) {
    if (date == null) return false;
    
    final minDate = DateTime(1900);
    final maxDate = DateTime(2100);
    
    return date.isAfter(minDate) && date.isBefore(maxDate);
  }

  /// Validar duración del evento
  static bool isValidEventDuration(DateTime startTime, DateTime endTime) {
    if (!isValidDate(startTime) || !isValidDate(endTime)) {
      return false;
    }
    
    final duration = endTime.difference(startTime);
    
    // Duración mínima de 1 minuto y máxima de 7 días
    return duration.inMinutes >= 1 && duration.inDays <= 7;
  }

  /// Limpiar logs sensibles para debugging
  static String sanitizeForLogging(String message) {
    // Remover posibles datos sensibles de logs
    return message
        .replaceAll(RegExp(r'\b\d{4}-\d{2}-\d{2}\b'), '[DATE]')
        .replaceAll(RegExp(r'\b\d{2}:\d{2}:\d{2}\b'), '[TIME]')
        .replaceAll(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), '[EMAIL]');
  }

  /// Rate limiting básico para prevenir spam
  static final Map<String, List<DateTime>> _requestHistory = {};
  
  static bool checkRateLimit(String identifier, {int maxRequests = 10, Duration window = const Duration(minutes: 1)}) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    
    // Limpiar historial antiguo
    _requestHistory[identifier]?.removeWhere((time) => time.isBefore(cutoff));
    
    final requests = _requestHistory[identifier] ?? [];
    
    if (requests.length >= maxRequests) {
      return false; // Rate limit exceeded
    }
    
    // Registrar nueva solicitud
    requests.add(now);
    _requestHistory[identifier] = requests;
    
    return true;
  }
}

/// Validador de entrada personalizado
class InputValidator {
  
  /// Validar título del evento
  static String? validateEventTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El título es requerido';
    }
    
    final sanitized = SecurityUtils.sanitizeInput(value);
    if (sanitized != value) {
      return 'El título contiene caracteres no válidos';
    }
    
    if (sanitized.length < 3) {
      return 'El título debe tener al menos 3 caracteres';
    }
    
    if (sanitized.length > 100) {
      return 'El título no puede exceder 100 caracteres';
    }
    
    return null;
  }

  /// Validar descripción del evento
  static String? validateEventDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Descripción es opcional
    }
    
    final sanitized = SecurityUtils.sanitizeInput(value);
    if (sanitized != value) {
      return 'La descripción contiene caracteres no válidos';
    }
    
    if (sanitized.length > 500) {
      return 'La descripción no puede exceder 500 caracteres';
    }
    
    return null;
  }

  /// Validar fechas del evento
  static String? validateEventDates(DateTime? startTime, DateTime? endTime) {
    if (startTime == null || endTime == null) {
      return 'Las fechas son requeridas';
    }
    
    if (!SecurityUtils.isValidDate(startTime) || !SecurityUtils.isValidDate(endTime)) {
      return 'Las fechas no son válidas';
    }
    
    if (!SecurityUtils.isValidEventDuration(startTime, endTime)) {
      return 'La duración del evento no es válida';
    }
    
    return null;
  }
}
