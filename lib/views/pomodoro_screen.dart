import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pomodoro_controller.dart';
import '../controllers/task_controller.dart';
import '../models/pomodoro_session.dart';
import '../models/task.dart';
import 'pomodoro_history_screen.dart';

/// Pantalla del temporizador Pomodoro
/// Interfaz visual con circular timer y controles
class PomodoroScreen extends StatelessWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temporizador Pomodoro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
            tooltip: 'Configuración',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PomodoroHistoryScreen(),
                ),
              );
            },
            tooltip: 'Historial',
          ),
        ],
      ),
      body: Consumer<PomodoroController>(
        builder: (context, controller, child) {
          return Column(
            children: [
              // Indicador de tipo de sesión
              _buildSessionTypeIndicator(context, controller),
              
              // Tareas de hoy (sugerencias)
              _buildTodayTasksSuggestion(context, controller),
              
              // Selector de tarea vinculada
              _buildTaskSelector(context, controller),
              
              // Timer circular
              Expanded(
                child: Center(
                  child: _buildCircularTimer(context, controller),
                ),
              ),
              
              // Contador de sesiones completadas
              _buildSessionCounter(context, controller),
              
              // Controles
              _buildControls(context, controller),
              
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  /// Indicador de tipo de sesión
  Widget _buildSessionTypeIndicator(BuildContext context, PomodoroController controller) {
    final theme = Theme.of(context);
    final sessionType = controller.currentSessionType;
    
    Color backgroundColor;
    IconData icon;
    String title;
    
    switch (sessionType) {
      case SessionType.work:
        backgroundColor = Colors.red.shade50;
        icon = Icons.work;
        title = 'Sesión de Trabajo';
        break;
      case SessionType.shortBreak:
        backgroundColor = Colors.green.shade50;
        icon = Icons.coffee;
        title = 'Descanso Corto';
        break;
      case SessionType.longBreak:
        backgroundColor = Colors.blue.shade50;
        icon = Icons.spa;
        title = 'Descanso Largo';
        break;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Sugerencias de tareas que vencen hoy
  Widget _buildTodayTasksSuggestion(BuildContext context, PomodoroController pomodoroController) {
    return Consumer<TaskController>(
      builder: (context, taskController, child) {
        final todayTasks = taskController.getTodaysTasks();
        
        // No mostrar nada si no hay tareas de hoy
        if (todayTasks.isEmpty) return const SizedBox.shrink();
        
        // No mostrar si ya hay una tarea vinculada de hoy
        if (pomodoroController.linkedTaskId != null) {
          final linkedTask = taskController.getTaskById(pomodoroController.linkedTaskId!);
          if (linkedTask != null && todayTasks.any((t) => t.id == linkedTask.id)) {
            return const SizedBox.shrink();
          }
        }
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade50,
                Colors.amber.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tareas de Hoy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${todayTasks.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: todayTasks.length,
                  itemBuilder: (context, index) {
                    final task = todayTasks[index];
                    return _buildTodayTaskCard(context, task, pomodoroController);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Card individual de tarea de hoy
  Widget _buildTodayTaskCard(BuildContext context, Task task, PomodoroController pomodoroController) {
    // Color según prioridad
    Color priorityColor;
    switch (task.priority) {
      case TaskPriority.urgent:
        priorityColor = Colors.red;
        break;
      case TaskPriority.high:
        priorityColor = Colors.orange;
        break;
      case TaskPriority.medium:
        priorityColor = Colors.blue;
        break;
      case TaskPriority.low:
        priorityColor = Colors.grey;
        break;
    }
    
    return GestureDetector(
      onTap: () {
        // Vincular tarea y mostrar confirmación
        pomodoroController.linkTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Vinculada: ${task.title}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: priorityColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: priorityColor.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Título
            Text(
              task.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Información
            Row(
              children: [
                // Prioridad
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.priority.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
                const Spacer(),
                // Pomodoros
                Icon(Icons.timer, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 2),
                Text(
                  '${task.remainingPomodoros}🍅',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de tarea vinculada
  Widget _buildTaskSelector(BuildContext context, PomodoroController pomodoroController) {
    return Consumer<TaskController>(
      builder: (context, taskController, child) {
        final linkedTaskId = pomodoroController.linkedTaskId;
        final tasks = taskController.tasks.where((t) => t.status == TaskStatus.pending).toList();
        
        Task? linkedTask;
        if (linkedTaskId != null) {
          try {
            linkedTask = tasks.firstWhere((t) => t.id == linkedTaskId);
          } catch (e) {
            // Tarea no encontrada
          }
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.task_alt, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: linkedTask != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            linkedTask.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${linkedTask.completedPomodoros}/${linkedTask.estimatedPomodoros} 🍅 completados',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Sin tarea vinculada',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
              ),
              IconButton(
                icon: Icon(
                  linkedTask != null ? Icons.change_circle : Icons.add_circle,
                  color: Colors.blue,
                ),
                onPressed: () => _showTaskSelectorDialog(context, pomodoroController, tasks),
                tooltip: linkedTask != null ? 'Cambiar tarea' : 'Seleccionar tarea',
              ),
            ],
          ),
        );
      },
    );
  }

  /// Timer circular
  Widget _buildCircularTimer(BuildContext context, PomodoroController controller) {
    final theme = Theme.of(context);
    final progress = controller.progress;
    final formattedTime = controller.formattedTime;
    
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo de fondo
          CustomPaint(
            size: const Size(280, 280),
            painter: _CircularTimerPainter(
              progress: progress,
              backgroundColor: theme.colorScheme.surfaceVariant,
              progressColor: _getColorForSessionType(controller.currentSessionType),
            ),
          ),
          
          // Tiempo restante
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedTime,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 64,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.isRunning
                    ? (controller.isPaused ? 'Pausado' : 'En progreso')
                    : 'Listo para comenzar',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Contador de sesiones
  Widget _buildSessionCounter(BuildContext context, PomodoroController controller) {
    final theme = Theme.of(context);
    final completedSessions = controller.completedWorkSessions;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 24),
          const SizedBox(width: 8),
          Text(
            'Sesiones completadas hoy: $completedSessions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Controles del timer
  Widget _buildControls(BuildContext context, PomodoroController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!controller.isRunning || controller.isPaused)
            // Botón Start/Resume
            _buildControlButton(
              context: context,
              icon: controller.isPaused ? Icons.play_arrow : Icons.play_circle_fill,
              label: controller.isPaused ? 'Reanudar' : 'Iniciar',
              color: Colors.green,
              onPressed: () => controller.start(),
            ),
          
          if (controller.isRunning && !controller.isPaused)
            // Botón Pause
            _buildControlButton(
              context: context,
              icon: Icons.pause_circle_filled,
              label: 'Pausar',
              color: Colors.orange,
              onPressed: () => controller.pause(),
            ),
          
          if (controller.isRunning || controller.isPaused) ...[
            const SizedBox(width: 16),
            // Botón Stop
            _buildControlButton(
              context: context,
              icon: Icons.stop_circle,
              label: 'Detener',
              color: Colors.red,
              onPressed: () => controller.stop(),
            ),
          ],
          
          const SizedBox(width: 16),
          // Botón Skip
          _buildControlButton(
            context: context,
            icon: Icons.skip_next,
            label: 'Saltar',
            color: Colors.blue,
            onPressed: () => controller.skipToNext(),
          ),
        ],
      ),
    );
  }

  /// Botón de control
  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(20),
            shape: const CircleBorder(),
            elevation: 4,
          ),
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }

  /// Diálogo de configuración
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer<PomodoroController>(
        builder: (context, pomodoroController, _) => AlertDialog(
          title: const Text('Configuración'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duración de sesiones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Duración de trabajo
                _buildDurationSetting(
                  context: context,
                  label: 'Trabajo',
                  value: pomodoroController.workDuration ~/ 60,
                  onChanged: (value) => pomodoroController.setWorkDuration(value),
                ),
                
                const SizedBox(height: 12),
                
                // Duración de descanso corto
                _buildDurationSetting(
                  context: context,
                  label: 'Descanso corto',
                  value: pomodoroController.shortBreakDuration ~/ 60,
                  onChanged: (value) => pomodoroController.setShortBreakDuration(value),
                ),
                
                const SizedBox(height: 12),
                
                // Duración de descanso largo
                _buildDurationSetting(
                  context: context,
                  label: 'Descanso largo',
                  value: pomodoroController.longBreakDuration ~/ 60,
                  onChanged: (value) => pomodoroController.setLongBreakDuration(value),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Resetear contador
                TextButton.icon(
                  onPressed: () async {
                    await pomodoroController.resetCompletedSessions();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contador de sesiones reseteado'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Resetear contador de sesiones'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget de configuración de duración
  Widget _buildDurationSetting({
    required BuildContext context,
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text('$label: $value min'),
        ),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < 60 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  /// Obtener color según tipo de sesión
  Color _getColorForSessionType(SessionType type) {
    switch (type) {
      case SessionType.work:
        return Colors.red;
      case SessionType.shortBreak:
        return Colors.green;
      case SessionType.longBreak:
        return Colors.blue;
    }
  }
}

/// Painter para el timer circular
class _CircularTimerPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _CircularTimerPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Dibujar círculo de fondo
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 10, backgroundPaint);

    // Dibujar progreso
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}

/// Diálogo para seleccionar tarea a vincular con Pomodoro
void _showTaskSelectorDialog(
  BuildContext context,
  PomodoroController pomodoroController,
  List<Task> tasks,
) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.task_alt, color: Colors.blue),
            SizedBox(width: 8),
            Text('Seleccionar Tarea'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: tasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No hay tareas pendientes',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: tasks.length + 1, // +1 para opción "Sin vincular"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Opción para desvincular
                      return ListTile(
                        leading: const Icon(Icons.cancel, color: Colors.grey),
                        title: const Text('Sin vincular'),
                        subtitle: const Text('Pomodoro sin tarea específica'),
                        onTap: () {
                          pomodoroController.unlinkTask();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tarea desvinculada'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    }
                    
                    final task = tasks[index - 1];
                    final isLinked = pomodoroController.linkedTaskId == task.id;
                    
                    return ListTile(
                      leading: Icon(
                        Icons.task,
                        color: isLinked ? Colors.blue : Colors.grey,
                      ),
                      title: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${task.completedPomodoros}/${task.estimatedPomodoros} 🍅 • ${task.remainingPomodoros} restantes',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isLinked
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      selected: isLinked,
                      onTap: () {
                        pomodoroController.linkTask(task.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Vinculado a: ${task.title}'),
                            backgroundColor: Colors.blue,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      );
    },
  );
}
