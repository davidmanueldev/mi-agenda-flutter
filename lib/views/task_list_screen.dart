import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/task_controller.dart';
import '../models/task.dart';
import '../models/category.dart' as model;
import 'add_edit_task_screen.dart';
import 'task_detail_screen.dart';
import 'templates_screen.dart';

/// Pantalla de lista de tareas
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          // Botón de plantillas
          IconButton(
            icon: const Icon(Icons.insert_drive_file_outlined),
            tooltip: 'Plantillas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TemplatesScreen(),
                ),
              );
            },
          ),
          // Botón de filtros
          Consumer<TaskController>(
            builder: (context, controller, child) {
              final hasFilters = controller.statusFilter != null ||
                  controller.priorityFilter != null ||
                  controller.categoryFilter != null;

              return IconButton(
                icon: Badge(
                  isLabelVisible: hasFilters,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => _showFilters(context),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          _buildSearchBar(),
          
          // Estadísticas rápidas
          _buildQuickStats(),
          
          // Lista de tareas
          Expanded(
            child: Consumer<TaskController>(
              builder: (context, controller, child) {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = controller.tasks;

                if (tasks.isEmpty) {
                  return _buildEmptyState(controller);
                }

                return RefreshIndicator(
                  onRefresh: () => controller.refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _TaskCard(task: tasks[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddTask(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Tarea'),
      ),
    );
  }

  /// Barra de búsqueda
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar tareas...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<TaskController>().setSearchQuery('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          context.read<TaskController>().setSearchQuery(value);
        },
      ),
    );
  }

  /// Estadísticas rápidas
  Widget _buildQuickStats() {
    return Consumer<TaskController>(
      builder: (context, controller, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                icon: Icons.pending_actions,
                label: 'Pendientes',
                count: controller.totalPendingTasks,
                color: Colors.orange,
              ),
              _StatChip(
                icon: Icons.check_circle,
                label: 'Completadas',
                count: controller.totalCompletedTasks,
                color: Colors.green,
              ),
              _StatChip(
                icon: Icons.warning,
                label: 'Vencidas',
                count: controller.totalOverdueTasks,
                color: Colors.red,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Estado vacío
  Widget _buildEmptyState(TaskController controller) {
    final hasFilters = controller.statusFilter != null ||
        controller.priorityFilter != null ||
        controller.categoryFilter != null ||
        controller.searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.task_alt,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No se encontraron tareas'
                : '¡Sin tareas pendientes!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Intenta con otros filtros'
                : 'Agrega tu primera tarea',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => controller.clearFilters(),
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpiar Filtros'),
            ),
          ],
        ],
      ),
    );
  }

  /// Mostrar diálogo de filtros
  void _showFilters(BuildContext context) {
    final controller = context.read<TaskController>();

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtros',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () {
                      controller.clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Filtro por estado
              Text('Estado', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Pendiente'),
                    selected: controller.statusFilter == TaskStatus.pending,
                    onSelected: (selected) {
                      setState(() {
                        controller.setStatusFilter(
                          selected ? TaskStatus.pending : null,
                        );
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Completada'),
                    selected: controller.statusFilter == TaskStatus.completed,
                    onSelected: (selected) {
                      setState(() {
                        controller.setStatusFilter(
                          selected ? TaskStatus.completed : null,
                        );
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Archivada'),
                    selected: controller.statusFilter == TaskStatus.completed,
                    onSelected: (selected) {
                      setState(() {
                        controller.setStatusFilter(
                          selected ? TaskStatus.completed : null,
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Filtro por prioridad
              Text('Prioridad', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: TaskPriority.values.map((priority) {
                  return FilterChip(
                    label: Text(priority.displayName),
                    selected: controller.priorityFilter == priority,
                    onSelected: (selected) {
                      setState(() {
                        controller.setPriorityFilter(
                          selected ? priority : null,
                        );
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navegar a agregar tarea
  void _navigateToAddTask(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditTaskScreen(),
      ),
    );
  }
}

/// Widget de estadística
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Tarjeta de tarea
class _TaskCard extends StatelessWidget {
  final Task task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TaskController>();
    
    // Buscar el nombre de la categoría
    String categoryName = task.category;
    final categories = controller.categories;
    if (categories.isNotEmpty) {
      final category = categories.firstWhere(
        (cat) => cat.id == task.category,
        orElse: () => model.Category(
          id: task.category,
          name: task.category,
          description: '',
          color: const Color(0xFF2196F3),
          icon: const IconData(0xe1cb, fontFamily: 'MaterialIcons'),
          createdAt: DateTime.now(),
        ),
      );
      categoryName = category.name;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: título y prioridad
              Row(
                children: [
                  // Indicador de prioridad
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Título
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: task.status == TaskStatus.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                  ),
                  
                  // Menú de acciones
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      if (task.status == TaskStatus.pending)
                        const PopupMenuItem(
                          value: 'complete',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle),
                              SizedBox(width: 8),
                              Text('Completar'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      if (task.status != TaskStatus.completed)
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive),
                              SizedBox(width: 8),
                              Text('Archivar'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) => _handleAction(context, value, controller),
                  ),
                ],
              ),
              
              // Descripción
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Información adicional
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Fecha de vencimiento
                  if (task.dueDate != null)
                    Chip(
                      avatar: Icon(
                        task.isOverdue ? Icons.warning : Icons.calendar_today,
                        size: 16,
                        color: task.isOverdue ? Colors.red : null,
                      ),
                      label: Text(
                        _formatDate(task.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: task.isOverdue ? Colors.red : null,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  
                  // Categoría
                  Chip(
                    avatar: const Icon(Icons.folder, size: 16),
                    label: Text(
                      categoryName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  
                  // Progreso de sub-tareas
                  if (task.steps.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.checklist, size: 16),
                      label: Text(
                        '${task.steps.where((s) => s.isCompleted).length}/${task.steps.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  
                  // Pomodoros completados/estimados
                  Chip(
                    avatar: const Icon(Icons.timer, size: 16, color: Colors.red),
                    label: Text(
                      '${task.completedPomodoros}/${task.estimatedPomodoros} 🍅',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              
              // Barra de progreso de sub-tareas
              if (task.steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: Colors.grey[200],
                ),
              ],
              
              // Barra de progreso de Pomodoros
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pomodoros: ${task.completedPomodoros}/${task.estimatedPomodoros}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${task.remainingPomodoros} restantes (${task.remainingMinutes} min)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: task.pomodoroProgress,
                    backgroundColor: Colors.red[50],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                  
                  // Tiempo estimado de finalización
                  if (task.estimatedFinishTime != null && task.status == TaskStatus.pending) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Finish by: ${_formatFinishTime(task.estimatedFinishTime!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor() {
    switch (task.priority) {
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
    final now = DateTime.now();
    final diff = date.difference(now).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    if (diff < 0) return 'Vencida ${-diff}d';
    if (diff <= 7) return 'En ${diff}d';

    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFinishTime(DateTime finishTime) {
    final now = DateTime.now();
    
    // Si es hoy
    if (finishTime.day == now.day && 
        finishTime.month == now.month && 
        finishTime.year == now.year) {
      final hour = finishTime.hour.toString().padLeft(2, '0');
      final minute = finishTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    
    // Si es mañana
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (finishTime.day == tomorrow.day && 
        finishTime.month == tomorrow.month && 
        finishTime.year == tomorrow.year) {
      final hour = finishTime.hour.toString().padLeft(2, '0');
      final minute = finishTime.minute.toString().padLeft(2, '0');
      return 'Mañana $hour:$minute';
    }
    
    // Cualquier otra fecha
    final hour = finishTime.hour.toString().padLeft(2, '0');
    final minute = finishTime.minute.toString().padLeft(2, '0');
    return '${finishTime.day}/${finishTime.month} $hour:$minute';
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(taskId: task.id),
      ),
    );
  }

  void _handleAction(BuildContext context, String action, TaskController controller) {
    switch (action) {
      case 'complete':
        controller.completeTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea completada')),
        );
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddEditTaskScreen(taskId: task.id),
          ),
        );
        break;
      case 'archive':
        controller.archiveTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea archivada')),
        );
        break;
      case 'delete':
        _confirmDelete(context, controller);
        break;
    }
  }

  void _confirmDelete(BuildContext context, TaskController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tarea'),
        content: const Text('¿Estás seguro de que deseas eliminar esta tarea?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              controller.deleteTask(task.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tarea eliminada')),
              );
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
