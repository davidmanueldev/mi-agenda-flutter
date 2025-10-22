/// Modelo de datos para Tareas
/// Implementa validación y serialización para persistencia
class Task {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime? dueDate; // Fecha de vencimiento (opcional)
  final String category;
  final TaskPriority priority;
  final TaskStatus status;
  final List<SubTask> subTasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.dueDate,
    required this.category,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    List<SubTask>? subTasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : subTasks = subTasks ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Crear tarea desde Map (para SQLite)
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
          : null,
      category: map['category'] as String,
      priority: TaskPriority.values
          .firstWhere((e) => e.name == map['priority'], orElse: () => TaskPriority.medium),
      status: TaskStatus.values
          .firstWhere((e) => e.name == map['status'], orElse: () => TaskStatus.pending),
      subTasks: map['subTasks'] != null
          ? (map['subTasks'] as String)
              .split('|||')
              .where((s) => s.isNotEmpty)
              .map((s) => SubTask.fromString(s))
              .toList()
          : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  /// Convertir tarea a Map (para SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'category': category,
      'priority': priority.name,
      'status': status.name,
      'subTasks': subTasks.map((s) => s.toString()).join('|||'),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Crear tarea desde JSON (para Firebase)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      category: json['category'] as String,
      priority: TaskPriority.values
          .firstWhere((e) => e.name == json['priority'], orElse: () => TaskPriority.medium),
      status: TaskStatus.values
          .firstWhere((e) => e.name == json['status'], orElse: () => TaskStatus.pending),
      subTasks: json['subTasks'] != null
          ? (json['subTasks'] as List)
              .map((s) => SubTask.fromJson(s as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convertir tarea a JSON (para Firebase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'category': category,
      'priority': priority.name,
      'status': status.name,
      'subTasks': subTasks.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Validar tarea
  bool isValid() {
    if (title.trim().isEmpty) return false;
    if (title.length > 200) return false;
    if (description.length > 1000) return false;
    return true;
  }

  /// Crear copia con modificaciones
  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? category,
    TaskPriority? priority,
    TaskStatus? status,
    List<SubTask>? subTasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      subTasks: subTasks ?? this.subTasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Verificar si la tarea está vencida
  bool get isOverdue {
    if (dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now()) && status != TaskStatus.completed;
  }

  /// Obtener progreso de sub-tareas (0.0 a 1.0)
  double get progress {
    if (subTasks.isEmpty) return status == TaskStatus.completed ? 1.0 : 0.0;
    final completed = subTasks.where((s) => s.isCompleted).length;
    return completed / subTasks.length;
  }

  @override
  String toString() {
    return 'Task{id: $id, title: $title, status: $status, priority: $priority}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Prioridades de tareas
enum TaskPriority {
  low,      // Baja
  medium,   // Media
  high,     // Alta
  urgent,   // Urgente
}

/// Estados de tareas
enum TaskStatus {
  pending,    // Pendiente
  completed,  // Completada
  archived,   // Archivada
}

/// Modelo de Sub-tarea (checklist item)
class SubTask {
  final String id;
  final String title;
  final bool isCompleted;

  SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  /// Crear desde string serializado
  factory SubTask.fromString(String str) {
    final parts = str.split('::');
    return SubTask(
      id: parts[0],
      title: parts[1],
      isCompleted: parts[2] == '1',
    );
  }

  /// Convertir a string para SQLite
  @override
  String toString() {
    return '$id::$title::${isCompleted ? '1' : '0'}';
  }

  /// Crear desde JSON
  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  /// Crear copia con modificaciones
  SubTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Extensiones para enums
extension TaskPriorityExtension on TaskPriority {
  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Baja';
      case TaskPriority.medium:
        return 'Media';
      case TaskPriority.high:
        return 'Alta';
      case TaskPriority.urgent:
        return 'Urgente';
    }
  }

  int get value {
    switch (this) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
      case TaskPriority.urgent:
        return 4;
    }
  }
}

extension TaskStatusExtension on TaskStatus {
  String get displayName {
    switch (this) {
      case TaskStatus.pending:
        return 'Pendiente';
      case TaskStatus.completed:
        return 'Completada';
      case TaskStatus.archived:
        return 'Archivada';
    }
  }
}
