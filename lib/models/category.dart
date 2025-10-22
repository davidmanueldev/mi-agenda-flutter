import 'package:flutter/material.dart';

/// Modelo para representar una categoría de eventos
/// Incluye validaciones y propiedades para UI
class Category {
  final String id;
  final String name;
  final String description;
  final Color color;
  final IconData icon;
  final DateTime createdAt;

  /// Constructor principal con validaciones
  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.createdAt,
  }) : assert(name.isNotEmpty, 'El nombre de la categoría no puede estar vacío');

  /// Constructor para crear nueva categoría
  Category.create({
    required String name,
    required String description,
    required Color color,
    required IconData icon,
  }) : this(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          description: description,
          color: color,
          icon: icon,
          createdAt: DateTime.now(),
        );

  /// Conversión a Map para almacenamiento
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color.value,
      'icon': icon.codePoint,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Factory constructor desde Map
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      color: Color(map['color'] ?? Colors.blue.value),
      icon: IconData(map['icon'] ?? Icons.event.codePoint, fontFamily: 'MaterialIcons'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
  
  /// Alias para serialización JSON
  Map<String, dynamic> toJson() => toMap();
  
  /// Alias para deserialización JSON
  factory Category.fromJson(Map<String, dynamic> json) => Category.fromMap(json);

  /// Categorías predeterminadas del sistema
  static List<Category> get defaultCategories {
    return [
      Category.create(
        name: 'Trabajo',
        description: 'Eventos relacionados con el trabajo',
        color: Colors.blue,
        icon: Icons.work,
      ),
      Category.create(
        name: 'Personal',
        description: 'Eventos personales',
        color: Colors.green,
        icon: Icons.person,
      ),
      Category.create(
        name: 'Salud',
        description: 'Citas médicas y actividades de salud',
        color: Colors.red,
        icon: Icons.health_and_safety,
      ),
      Category.create(
        name: 'Estudio',
        description: 'Actividades académicas y estudio',
        color: Colors.purple,
        icon: Icons.school,
      ),
      Category.create(
        name: 'Social',
        description: 'Eventos sociales y reuniones',
        color: Colors.orange,
        icon: Icons.groups,
      ),
    ];
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}
