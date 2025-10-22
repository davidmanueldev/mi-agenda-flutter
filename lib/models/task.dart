import 'dart:convert';

/// Tipo de recurrencia para tareas
enum TaskRecurrence {
  none('Sin repetir'),
  daily('Diariamente'),
  weekdays('Días laborables'),
  weekly('Semanalmente'),
  monthly('Mensualmente'),
  yearly('Anualmente'),
  custom('Personalizado');

  final String displayName;
  const TaskRecurrence(this.displayName);
}

/// Estado de la tarea
enum TaskStatus {
  pending('Pendiente'),
  completed('Completada');

  final String displayName;
  const TaskStatus(this.displayName);
}

/// Prioridad de la tarea
enum TaskPriority {
  low('Baja', 1),
  medium('Media', 2),
  high('Alta', 3),
  urgent('Urgente', 4);

  final String displayName;
  final int value;
  const TaskPriority(this.displayName, this.value);
}

/// Modelo de Paso (antes sub-tarea)
class TaskStep {
  final String id;
  final String title;
  final bool isCompleted;

  TaskStep({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  /// Copiar con modificaciones
  TaskStep copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return TaskStep(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
  };

  /// Crear desde JSON
  factory TaskStep.fromJson(Map<String, dynamic> json) {
    return TaskStep(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  /// Convertir a String para SQLite
  @override
  String toString() => '$id:::$title:::${isCompleted ? '1' : '0'}';

  /// Crear desde String (para SQLite)
  factory TaskStep.fromString(String str) {
    final parts = str.split(':::');
    return TaskStep(
      id: parts[0],
      title: parts[1],
      isCompleted: parts.length > 2 && parts[2] == '1',
    );
  }
}

/// Modelo de datos para Tareas mejorado
/// Implementa validación y serialización para persistencia
class Task {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime? dueDate; // Fecha de vencimiento
  final String category;
  final TaskPriority priority;
  final TaskStatus status;
  final List<TaskStep> steps; // Antes "subTasks", ahora "steps"
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // NUEVOS CAMPOS
  final bool isMyDay; // "Agregar a Mi Día"
  final DateTime? reminderDateTime; // "Recordarme"
  final TaskRecurrence recurrence; // Recurrencia
  final Map<String, dynamic>? customRecurrence; // Para recurrencia personalizada

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.dueDate,
    required this.category,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    List<TaskStep>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isMyDay = false,
    this.reminderDateTime,
    this.recurrence = TaskRecurrence.none,
    this.customRecurrence,
  })  : steps = steps ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Validar si la tarea es válida
  bool isValid() {
    if (title.trim().isEmpty) return false;
    if (title.length > 200) return false;
    if (description.length > 1000) return false;
    if (dueDate != null && dueDate!.year < 1900) return false;
    if (reminderDateTime != null && dueDate != null) {
      if (reminderDateTime!.isAfter(dueDate!)) return false;
    }
    return true;
  }

  /// Verificar si está vencida
  bool get isOverdue {
    if (status == TaskStatus.completed) return false;
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Calcular progreso de pasos
  double get progress {
    if (steps.isEmpty) return 0.0;
    final completed = steps.where((step) => step.isCompleted).length;
    return completed / steps.length;
  }

  /// Copiar con modificaciones
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
    List<TaskStep>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isMyDay,
    DateTime? reminderDateTime,
    bool clearReminder = false,
    TaskRecurrence? recurrence,
    Map<String, dynamic>? customRecurrence,
    bool clearCustomRecurrence = false,
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
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isMyDay: isMyDay ?? this.isMyDay,
      reminderDateTime: clearReminder ? null : (reminderDateTime ?? this.reminderDateTime),
      recurrence: recurrence ?? this.recurrence,
      customRecurrence: clearCustomRecurrence ? null : (customRecurrence ?? this.customRecurrence),
    );
  }

  /// Convertir a Map para SQLite
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
      'steps': steps.map((s) => s.toString()).join('|||'),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isMyDay': isMyDay ? 1 : 0,
      'reminderDateTime': reminderDateTime?.millisecondsSinceEpoch,
      'recurrence': recurrence.name,
      'customRecurrence': customRecurrence != null ? jsonEncode(customRecurrence) : null,
    };
  }

  /// Crear desde Map (SQLite)
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
      steps: map['steps'] != null
          ? (map['steps'] as String)
              .split('|||')
              .where((s) => s.isNotEmpty)
              .map((s) => TaskStep.fromString(s))
              .toList()
          : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      isMyDay: (map['isMyDay'] as int?) == 1,
      reminderDateTime: map['reminderDateTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['reminderDateTime'] as int)
          : null,
      recurrence: TaskRecurrence.values.firstWhere(
        (e) => e.name == map['recurrence'],
        orElse: () => TaskRecurrence.none,
      ),
      customRecurrence: map['customRecurrence'] != null
          ? jsonDecode(map['customRecurrence'] as String) as Map<String, dynamic>
          : null,
    );
  }

  /// Convertir a JSON para Firebase
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
      'steps': steps.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isMyDay': isMyDay,
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'recurrence': recurrence.name,
      'customRecurrence': customRecurrence,
    };
  }

  /// Crear desde JSON (Firebase)
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
      steps: json['steps'] != null
          ? (json['steps'] as List)
              .map((s) => TaskStep.fromJson(s as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isMyDay: json['isMyDay'] as bool? ?? false,
      reminderDateTime: json['reminderDateTime'] != null
          ? DateTime.parse(json['reminderDateTime'] as String)
          : null,
      recurrence: TaskRecurrence.values.firstWhere(
        (e) => e.name == json['recurrence'],
        orElse: () => TaskRecurrence.none,
      ),
      customRecurrence: json['customRecurrence'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, status: $status, isMyDay: $isMyDay, recurrence: $recurrence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
