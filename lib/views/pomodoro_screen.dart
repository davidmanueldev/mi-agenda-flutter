import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pomodoro_controller.dart';
import '../models/pomodoro_session.dart';

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
              // TODO: Navegar a historial de sesiones
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
                  onPressed: () {
                    pomodoroController.resetCompletedSessions();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contador de sesiones reseteado'),
                        duration: Duration(seconds: 2),
                      ),
                    );
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
