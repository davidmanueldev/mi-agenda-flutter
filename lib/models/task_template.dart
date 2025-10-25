import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'task.dart';

/// Modelo de plantilla de tarea
/// Permite guardar configuraciones de tareas para reutilización rápida
class TaskTemplate {
  final String id;
  final String userId;
  final String name; // Nombre de la plantilla
  final String title; // Título de la tarea que se creará
  final String description;
  final String category;
  final TaskPriority priority;
  final int estimatedPomodoros;
  final List<String> steps; // Lista de títulos de pasos (sin ID ni estado)
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskTemplate({
    required this.id,
    required this.userId,
    required this.name,
    required this.title,
    this.description = '',
    this.category = 'Personal',
    this.priority = TaskPriority.medium,
    this.estimatedPomodoros = 1,
    this.steps = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crear una copia con modificaciones
  TaskTemplate copyWith({
    String? id,
    String? userId,
    String? name,
    String? title,
    String? description,
    String? category,
    TaskPriority? priority,
    int? estimatedPomodoros,
    List<String>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ==================== SERIALIZACIÓN PARA SQLITE ====================

  /// Convertir a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority.name,
      'estimated_pomodoros': estimatedPomodoros,
      'steps': jsonEncode(steps), // Guardar como JSON string
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Crear desde Map de SQLite
  factory TaskTemplate.fromMap(Map<String, dynamic> map) {
    return TaskTemplate(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Personal',
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      estimatedPomodoros: map['estimated_pomodoros'] as int? ?? 1,
      steps: map['steps'] != null 
          ? List<String>.from(jsonDecode(map['steps'] as String))
          : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  // ==================== SERIALIZACIÓN PARA FIREBASE ====================

  /// Convertir a JSON para Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority.name,
      'estimatedPomodoros': estimatedPomodoros,
      'steps': steps,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Crear desde JSON de Firebase
  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Personal',
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      estimatedPomodoros: json['estimatedPomodoros'] as int? ?? 1,
      steps: json['steps'] != null 
          ? List<String>.from(json['steps'] as List)
          : [],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  @override
  String toString() {
    return 'TaskTemplate(id: $id, name: $name, title: $title, priority: ${priority.displayName}, pomodoros: $estimatedPomodoros)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is TaskTemplate &&
      other.id == id &&
      other.userId == userId &&
      other.name == name &&
      other.title == title &&
      other.description == description &&
      other.category == category &&
      other.priority == priority &&
      other.estimatedPomodoros == estimatedPomodoros;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      title.hashCode ^
      description.hashCode ^
      category.hashCode ^
      priority.hashCode ^
      estimatedPomodoros.hashCode;
  }
}
