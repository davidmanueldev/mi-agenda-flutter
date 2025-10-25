import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de sesión Pomodoro
enum SessionType {
  work,       // Sesión de trabajo (25 min)
  shortBreak, // Descanso corto (5 min)
  longBreak,  // Descanso largo (15 min)
}

/// Modelo de sesión Pomodoro
/// Registra cada sesión de trabajo o descanso completada
class PomodoroSession {
  final String id;
  final String userId;
  final SessionType sessionType;
  final int duration; // Duración en segundos
  final DateTime startTime;
  final DateTime? endTime;
  final String? taskId; // Opcional: asociar con una tarea específica
  final DateTime createdAt;
  final DateTime updatedAt;

  PomodoroSession({
    required this.id,
    required this.userId,
    required this.sessionType,
    required this.duration,
    required this.startTime,
    this.endTime,
    this.taskId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Verificar si la sesión está completa
  bool get isCompleted => endTime != null;

  /// Obtener duración real (si está completada)
  int? get actualDuration {
    if (endTime == null) return null;
    return endTime!.difference(startTime).inSeconds;
  }

  /// Obtener duración en minutos
  int get durationInMinutes => duration ~/ 60;

  // ==================== SERIALIZACIÓN PARA SQLITE ====================

  /// Convertir a Map para SQLite (fechas como millisecondsSinceEpoch)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'sessionType': sessionType.toString(),
      'duration': duration,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'taskId': taskId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Crear desde Map de SQLite
  factory PomodoroSession.fromMap(Map<String, dynamic> map) {
    return PomodoroSession(
      id: map['id'] as String,
      userId: map['userId'] as String,
      sessionType: SessionType.values.firstWhere(
        (e) => e.toString() == map['sessionType'],
        orElse: () => SessionType.work,
      ),
      duration: map['duration'] as int,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int)
          : null,
      taskId: map['taskId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  // ==================== SERIALIZACIÓN PARA FIREBASE ====================

  /// Convertir a JSON para Firebase (fechas como Timestamp)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'sessionType': sessionType.toString(),
      'duration': duration,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'taskId': taskId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Crear desde JSON de Firebase
  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    return PomodoroSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      sessionType: SessionType.values.firstWhere(
        (e) => e.toString() == json['sessionType'],
        orElse: () => SessionType.work,
      ),
      duration: json['duration'] as int,
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: json['endTime'] != null
          ? (json['endTime'] as Timestamp).toDate()
          : null,
      taskId: json['taskId'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  // ==================== MÉTODOS DE UTILIDAD ====================

  /// Copiar con modificaciones
  PomodoroSession copyWith({
    String? id,
    String? userId,
    SessionType? sessionType,
    int? duration,
    DateTime? startTime,
    DateTime? endTime,
    String? taskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionType: sessionType ?? this.sessionType,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      taskId: taskId ?? this.taskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PomodoroSession(id: $id, type: $sessionType, duration: ${durationInMinutes}min, completed: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PomodoroSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Extensión para obtener valores por defecto de duración
extension SessionTypeDuration on SessionType {
  /// Duración por defecto en segundos
  int get defaultDuration {
    switch (this) {
      case SessionType.work:
        return 25 * 60; // 25 minutos
      case SessionType.shortBreak:
        return 5 * 60; // 5 minutos
      case SessionType.longBreak:
        return 15 * 60; // 15 minutos
    }
  }

  /// Nombre legible
  String get displayName {
    switch (this) {
      case SessionType.work:
        return 'Trabajo';
      case SessionType.shortBreak:
        return 'Descanso Corto';
      case SessionType.longBreak:
        return 'Descanso Largo';
    }
  }
}
