import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/template_controller.dart';
import '../controllers/task_controller.dart';
import '../models/task_template.dart';
import '../models/task.dart';
import '../utils/security_utils.dart';

/// Pantalla de gestión de plantillas de tareas
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantillas de Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear Plantilla',
            onPressed: () => _showCreateTemplateDialog(context),
          ),
        ],
      ),
      body: Consumer<TemplateController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage != null) {
            return _buildErrorState(context, controller.errorMessage!);
          }

          if (controller.templates.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: controller.templates.length,
              itemBuilder: (context, index) {
                final template = controller.templates[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TemplateCard(
                    template: template,
                    onTap: () => _createTaskFromTemplate(context, template),
                    onEdit: () => _showEditTemplateDialog(context, template),
                    onDelete: () => _confirmDelete(context, template),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay plantillas',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea plantillas para reutilizar configuraciones de tareas',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateTemplateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Crear Plantilla'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error al cargar plantillas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final controller = Provider.of<TemplateController>(context, listen: false);
              controller.refresh();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _TemplateDialog(),
    );
  }

  void _showEditTemplateDialog(BuildContext context, TaskTemplate template) {
    showDialog(
      context: context,
      builder: (context) => _TemplateDialog(template: template),
    );
  }

  void _createTaskFromTemplate(BuildContext context, TaskTemplate template) async {
    final taskController = Provider.of<TaskController>(context, listen: false);
    
    // Obtener el userId real desde las tareas existentes
    // Si no hay tareas, usar un userId temporal que será reemplazado por Firebase Auth
    String userId = 'user_temp';
    if (taskController.tasks.isNotEmpty) {
      userId = taskController.tasks.first.userId;
    }
    
    // Crear tarea desde template
    final newTask = Task(
      id: SecurityUtils.generateSecureId(),
      userId: userId,
      title: template.title,
      description: template.description,
      category: template.category,
      priority: template.priority,
      estimatedPomodoros: template.estimatedPomodoros,
      completedPomodoros: 0,
      status: TaskStatus.pending,
      steps: template.steps.map((stepTitle) => TaskStep(
        id: SecurityUtils.generateSecureId(),
        title: stepTitle,
        isCompleted: false,
      )).toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await taskController.createTask(newTask);
    
    if (!context.mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tarea creada desde "${template.name}"'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Ver',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pop(context); // Volver a la pantalla anterior
            },
          ),
        ),
      );
      Navigator.pop(context); // Cerrar pantalla de templates
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al crear tarea desde plantilla'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, TaskTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Plantilla'),
        content: Text('¿Estás seguro de eliminar "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final controller = Provider.of<TemplateController>(context, listen: false);
              final success = await controller.deleteTemplate(template.id);
              
              if (!context.mounted) return;
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Plantilla eliminada'
                        : 'Error al eliminar plantilla',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Card de plantilla
class _TemplateCard extends StatelessWidget {
  final TaskTemplate template;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono de plantilla
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getPriorityColor(template.priority).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insert_drive_file,
                  color: _getPriorityColor(template.priority),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Información de la plantilla
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre de plantilla
                    Text(
                      template.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Título de tarea
                    Text(
                      template.title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Footer con categoría, prioridad y pomodoros
                    Row(
                      children: [
                        // Categoría
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              template.category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Prioridad badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(template.priority).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            template.priority.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getPriorityColor(template.priority),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Pomodoros
                        Row(
                          children: [
                            const Icon(Icons.timer, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${template.estimatedPomodoros}🍅',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Menú de acciones
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return Colors.red;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.low:
        return Colors.grey;
    }
  }
}

/// Diálogo para crear/editar plantilla
class _TemplateDialog extends StatefulWidget {
  final TaskTemplate? template;

  const _TemplateDialog({this.template});

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepController = TextEditingController();
  
  String? _selectedCategory; // Ahora nullable para inicializar correctamente
  TaskPriority _selectedPriority = TaskPriority.medium;
  int _estimatedPomodoros = 1;
  List<String> _steps = [];

  @override
  void initState() {
    super.initState();
    
    // Si estamos editando, cargar datos de la plantilla
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _titleController.text = widget.template!.title;
      _descriptionController.text = widget.template!.description;
      _selectedCategory = widget.template!.category;
      _selectedPriority = widget.template!.priority;
      _estimatedPomodoros = widget.template!.estimatedPomodoros;
      _steps = List.from(widget.template!.steps);
    } else {
      // Si es nueva plantilla, inicializar con primera categoría disponible
      final taskController = Provider.of<TaskController>(context, listen: false);
      if (taskController.categories.isNotEmpty) {
        _selectedCategory = taskController.categories.first.id;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.template != null;
    
    return AlertDialog(
      title: Text(isEdit ? 'Editar Plantilla' : 'Nueva Plantilla'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nombre de plantilla
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de Plantilla *',
                  hintText: 'Ej: Reunión Semanal',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Título de tarea
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título de Tarea *',
                  hintText: 'Ej: Reunión de Equipo',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El título es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Descripción
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Opcional',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Categoría - Ahora usa Consumer para obtener categorías reales
              Consumer<TaskController>(
                builder: (context, controller, child) {
                  final categories = controller.categories;
                  
                  if (categories.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay categorías disponibles. Crea una primero.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    );
                  }
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          children: [
                            Icon(
                              category.icon,
                              color: category.color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecciona una categoría';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Prioridad
              DropdownButtonFormField<TaskPriority>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Prioridad',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: TaskPriority.values
                    .map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Pomodoros estimados
              Row(
                children: [
                  const Icon(Icons.timer, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pomodoros: $_estimatedPomodoros',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _estimatedPomodoros > 1
                        ? () => setState(() => _estimatedPomodoros--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _estimatedPomodoros++),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Pasos
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.list, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pasos (${_steps.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Lista de pasos
              if (_steps.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        dense: true,
                        leading: Text('${index + 1}.'),
                        title: Text(_steps[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            setState(() {
                              _steps.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              
              // Agregar paso
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stepController,
                      decoration: const InputDecoration(
                        hintText: 'Agregar paso',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addStep(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addStep,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saveTemplate,
          child: Text(isEdit ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  void _addStep() {
    if (_stepController.text.trim().isNotEmpty) {
      setState(() {
        _steps.add(_stepController.text.trim());
        _stepController.clear();
      });
    }
  }

  void _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar que se haya seleccionado una categoría
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una categoría'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final controller = Provider.of<TemplateController>(context, listen: false);
    final isEdit = widget.template != null;

    final template = TaskTemplate(
      id: isEdit ? widget.template!.id : SecurityUtils.generateSecureId(),
      userId: isEdit ? widget.template!.userId : 'user_temp', // Se actualizará con userId real
      name: SecurityUtils.sanitizeInput(_nameController.text.trim()),
      title: SecurityUtils.sanitizeInput(_titleController.text.trim()),
      description: SecurityUtils.sanitizeInput(_descriptionController.text.trim()),
      category: _selectedCategory!, // Ahora es seguro usar ! después de la validación
      priority: _selectedPriority,
      estimatedPomodoros: _estimatedPomodoros,
      steps: _steps,
      createdAt: isEdit ? widget.template!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = isEdit
        ? await controller.updateTemplate(template)
        : await controller.createTemplate(template);

    if (!mounted) return;
    
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Plantilla actualizada' : 'Plantilla creada'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar plantilla'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
