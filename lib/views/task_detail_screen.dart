import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/task_controller.dart';
import '../models/task.dart';
import 'add_edit_task_screen.dart';

/// Pantalla de detalle de tarea
class TaskDetailScreen extends StatelessWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Tarea'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: FutureBuilder<Task?>(
        future: context.read<TaskController>().getTaskById(taskId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final task = snapshot.data;

          if (task == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Tarea no encontrada',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con estado
                _buildHeader(context, task),

                const Divider(),

                // Información principal
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: task.status == TaskStatus.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Descripción
                      if (task.description.isNotEmpty) ...[
                        Text(
                          'Descripción',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Detalles
                      _buildDetailCard(context, task),
                      const SizedBox(height: 24),

                      // Sub-tareas
                      if (task.steps.isNotEmpty) ...[
                        _buildTaskStepsSection(context, task),
                        const SizedBox(height: 24),
                      ],

                      // Acciones rápidas
                      _buildActions(context, task),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Task task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor(task.status).withOpacity(0.1),
        border: Border(
          left: BorderSide(
            color: _getPriorityColor(task.priority),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(task.status),
            color: _getStatusColor(task.status),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.status.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _getStatusColor(task.status),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Prioridad: ${task.priority.displayName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _getPriorityColor(task.priority),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, Task task) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Categoría
            _buildDetailRow(
              context,
              icon: Icons.folder,
              label: 'Categoría',
              value: task.category,
            ),
            const Divider(),

            // Fecha de vencimiento
            _buildDetailRow(
              context,
              icon: Icons.calendar_today,
              label: 'Fecha de vencimiento',
              value: task.dueDate != null
                  ? _formatDateTime(task.dueDate!)
                  : 'Sin fecha límite',
              isOverdue: task.isOverdue,
            ),
            const Divider(),

            // Progreso
            if (task.steps.isNotEmpty) ...[
              _buildDetailRow(
                context,
                icon: Icons.trending_up,
                label: 'Progreso',
                value: '${(task.progress * 100).toInt()}%',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progress,
                backgroundColor: Colors.grey[200],
                minHeight: 8,
              ),
              const Divider(),
            ],

            // Creación
            _buildDetailRow(
              context,
              icon: Icons.access_time,
              label: 'Creada',
              value: _formatDateTime(task.createdAt),
            ),
            const Divider(),

            // Última actualización
            _buildDetailRow(
              context,
              icon: Icons.update,
              label: 'Actualizada',
              value: _formatDateTime(task.updatedAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isOverdue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isOverdue ? Colors.red : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isOverdue ? Colors.red : null,
                        fontWeight: isOverdue ? FontWeight.bold : null,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStepsSection(BuildContext context, Task task) {
    final controller = context.read<TaskController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sub-tareas (${task.steps.where((s) => s.isCompleted).length}/${task.steps.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${(task.progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(task.steps.length, (index) {
          final subTask = task.steps[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              value: subTask.isCompleted,
              onChanged: task.status == TaskStatus.completed
                  ? null
                  : (value) async {
                      await controller.toggleTaskStep(task, index);
                      // Forzar rebuild
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskDetailScreen(taskId: taskId),
                          ),
                        );
                      }
                    },
              title: Text(
                subTask.title,
                style: TextStyle(
                  decoration: subTask.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              secondary: Icon(
                subTask.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: subTask.isCompleted ? Colors.green : null,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActions(BuildContext context, Task task) {
    final controller = context.read<TaskController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (task.status == TaskStatus.pending) ...[
          FilledButton.icon(
            onPressed: () async {
              await controller.completeTask(task.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tarea completada')),
                );
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Marcar como Completada'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (task.status != TaskStatus.archived)
          OutlinedButton.icon(
            onPressed: () async {
              await controller.archiveTask(task.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tarea archivada')),
                );
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.archive),
            label: const Text('Archivar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.archived:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.pending_actions;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.archived:
        return Icons.archive;
    }
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

  String _formatDateTime(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.day} ${months[date.month - 1]} ${date.year} - $hour:$minute';
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTaskScreen(taskId: taskId),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tarea'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta tarea? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final controller = context.read<TaskController>();
              await controller.deleteTask(taskId);

              if (context.mounted) {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context); // Volver a lista
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tarea eliminada')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
