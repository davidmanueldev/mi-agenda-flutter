import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/task_controller.dart';
import '../models/task.dart';
import '../utils/security_utils.dart';

/// Pantalla para agregar o editar tarea
class AddEditTaskScreen extends StatefulWidget {
  final String? taskId;

  const AddEditTaskScreen({super.key, this.taskId});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subTaskController = TextEditingController();

  Task? _existingTask;
  DateTime? _selectedDueDate;
  TaskPriority _selectedPriority = TaskPriority.medium;
  String? _selectedCategory; // Cambiado a nullable para inicializar correctamente
  List<TaskStep> _steps = [];
  int _estimatedPomodoros = 1; // Estimación de pomodoros
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    if (widget.taskId != null) {
      // Editar tarea existente
      final controller = context.read<TaskController>();
      final task = controller.getTaskById(widget.taskId!);

      if (task != null) {
        setState(() {
          _existingTask = task;
          _titleController.text = task.title;
          _descriptionController.text = task.description;
          _selectedDueDate = task.dueDate;
          _selectedPriority = task.priority;
          _selectedCategory = task.category;
          _steps = List.from(task.steps);
          _estimatedPomodoros = task.estimatedPomodoros;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      // Nueva tarea: inicializar con primera categoría disponible
      final categories = context.read<TaskController>().categories;
      setState(() {
        if (categories.isNotEmpty) {
          _selectedCategory = categories.first.id;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subTaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null ? 'Nueva Tarea' : 'Editar Tarea'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTask,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ej: Revisar correos',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      maxLength: 200,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El título es requerido';
                        }
                        if (value.length > 200) {
                          return 'El título es muy largo';
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
                        hintText: 'Detalles de la tarea...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 4,
                      maxLength: 1000,
                      validator: (value) {
                        if (value != null && value.length > 1000) {
                          return 'La descripción es muy larga';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fecha de vencimiento
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Fecha de vencimiento'),
                        subtitle: Text(
                          _selectedDueDate != null
                              ? _formatDate(_selectedDueDate!)
                              : 'Sin fecha límite',
                        ),
                        trailing: _selectedDueDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() => _selectedDueDate = null);
                                },
                              )
                            : null,
                        onTap: _selectDueDate,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Prioridad
                    Text(
                      'Prioridad',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: TaskPriority.values.map((priority) {
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag,
                                size: 16,
                                color: _getPriorityColor(priority),
                              ),
                              const SizedBox(width: 4),
                              Text(priority.displayName),
                            ],
                          ),
                          selected: _selectedPriority == priority,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedPriority = priority);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Categoría
                    Consumer<TaskController>(
                      builder: (context, controller, child) {
                        final categories = controller.categories;

                        if (categories.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.folder),
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
                            if (value != null) {
                              setState(() => _selectedCategory = value);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Estimación de Pomodoros
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  'Estimación de Pomodoros',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: _estimatedPomodoros > 1
                                              ? () {
                                                  setState(() {
                                                    _estimatedPomodoros--;
                                                  });
                                                }
                                              : null,
                                          color: Colors.red,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$_estimatedPomodoros 🍅',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: _estimatedPomodoros < 20
                                              ? () {
                                                  setState(() {
                                                    _estimatedPomodoros++;
                                                  });
                                                }
                                              : null,
                                          color: Colors.red,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '≈ ${_estimatedPomodoros * 25} minutos',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sub-tareas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sub-tareas (${_steps.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          onPressed: _addTaskStep,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Lista de sub-tareas
                    if (_steps.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No hay sub-tareas',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_steps.length, (index) {
                        final subTask = _steps[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Checkbox(
                              value: subTask.isCompleted,
                              onChanged: (value) {
                                setState(() {
                                  _steps[index] = subTask.copyWith(
                                    isCompleted: value ?? false,
                                  );
                                });
                              },
                            ),
                            title: Text(
                              subTask.title,
                              style: TextStyle(
                                decoration: subTask.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() => _steps.removeAt(index));
                              },
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.blue;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.deepOrange;
      case TaskPriority.urgent:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _selectedDueDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _addTaskStep() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Sub-tarea'),
        content: TextField(
          controller: _subTaskController,
          decoration: const InputDecoration(
            hintText: 'Título de la sub-tarea',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 200,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (_subTaskController.text.trim().isNotEmpty) {
                Navigator.pop(context, _subTaskController.text.trim());
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _steps.add(TaskStep(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: result,
        ));
      });
      _subTaskController.clear();
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar que se haya seleccionado una categoría
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una categoría'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final controller = context.read<TaskController>();
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}'; // Temporal

    final task = Task(
      id: _existingTask?.id ?? SecurityUtils.generateSecureId(),
      userId: _existingTask?.userId ?? userId,
      title: SecurityUtils.sanitizeInput(_titleController.text),
      description: SecurityUtils.sanitizeInput(_descriptionController.text),
      dueDate: _selectedDueDate,
      category: _selectedCategory!, // Ahora es seguro usar !
      priority: _selectedPriority,
      status: _existingTask?.status ?? TaskStatus.pending,
      steps: _steps,
      createdAt: _existingTask?.createdAt ?? DateTime.now(),
      estimatedPomodoros: _estimatedPomodoros,
      completedPomodoros: _existingTask?.completedPomodoros ?? 0,
    );

    if (!task.isValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor verifica los datos ingresados'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool success;
    if (_existingTask != null) {
      success = await controller.updateTask(task);
    } else {
      success = await controller.createTask(task);
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _existingTask != null
                ? 'Tarea actualizada correctamente'
                : 'Tarea creada correctamente',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Error al guardar la tarea'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
