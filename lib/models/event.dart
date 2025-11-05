/// Modelo de datos para representar un evento en la agenda
/// Implementa las mejores prácticas con validación y serialización
class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String category;
  final bool isCompleted;
  final String userId; // ID del usuario propietario del evento
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Constructor principal con validaciones básicas
  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.category,
    this.isCompleted = false,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(title.isNotEmpty, 'El título no puede estar vacío'),
       assert(userId.isNotEmpty, 'El userId no puede estar vacío'),
       assert(startTime.isBefore(endTime), 'La fecha de inicio debe ser anterior a la de fin');

  /// Constructor para crear un nuevo evento con timestamps automáticos
  Event.create({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String category,
    required String userId,
  }) : this(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          description: description,
          startTime: startTime,
          endTime: endTime,
          category: category,
          userId: userId,
          isCompleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

  /// Método para convertir el evento a Map para almacenamiento
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'category': category,
      'isCompleted': isCompleted ? 1 : 0,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Factory constructor para crear un evento desde Map
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] ?? 0),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] ?? 0),
      category: map['category'] ?? '',
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      userId: map['userId'] ?? map['user_id'] ?? '', // Soporta ambos nombres
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }
  
  /// Alias para serialización JSON
  Map<String, dynamic> toJson() => toMap();
  
  /// Alias para deserialización JSON
  factory Event.fromJson(Map<String, dynamic> json) => Event.fromMap(json);

  /// Método para crear una copia del evento con campos actualizados
  Event copyWith({
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? category,
    bool? isCompleted,
    String? userId,
  }) {
    return Event(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
      createdAt: createdAt,
      updatedAt: DateTime.now(), // Actualiza automáticamente el timestamp
    );
  }

  /// Validación de integridad del evento
  bool get isValid {
    return title.isNotEmpty && 
           startTime.isBefore(endTime) &&
           category.isNotEmpty;
  }

  /// Duración del evento en minutos
  int get durationInMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  @override
  String toString() {
    return 'Event{id: $id, title: $title, startTime: $startTime, endTime: $endTime}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}
