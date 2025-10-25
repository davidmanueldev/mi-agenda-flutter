import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pomodoro_controller.dart';
import '../models/pomodoro_session.dart';
import '../widgets/app_drawer.dart';

/// Pantalla de historial de sesiones Pomodoro
class PomodoroHistoryScreen extends StatefulWidget {
  const PomodoroHistoryScreen({super.key});

  @override
  State<PomodoroHistoryScreen> createState() => _PomodoroHistoryScreenState();
}

class _PomodoroHistoryScreenState extends State<PomodoroHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Por defecto, mostrar últimos 7 días
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 6));
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final controller = context.read<PomodoroController>();
    if (_startDate != null && _endDate != null) {
      await controller.getSessionsByDateRange(_startDate!, _endDate!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Pomodoro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
            tooltip: 'Filtrar por fechas',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'pomodoro_history'),
      body: Consumer<PomodoroController>(
        builder: (context, controller, _) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = controller.sessions;

          if (sessions.isEmpty) {
            return _buildEmptyState();
          }

          // Agrupar sesiones por fecha
          final sessionsByDate = _groupSessionsByDate(sessions);

          return Column(
            children: [
              _buildStatsCard(controller),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessionsByDate.length,
                  itemBuilder: (context, index) {
                    final date = sessionsByDate.keys.elementAt(index);
                    final dateSessions = sessionsByDate[date]!;
                    return _buildDateSection(date, dateSessions);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Card con estadísticas generales
  Widget _buildStatsCard(PomodoroController controller) {
    final stats = controller.stats;
    final totalSessions = stats['totalSessions'] ?? 0;
    final workSessions = stats['workSessions'] ?? 0;
    final totalMinutes = stats['totalMinutes'] ?? 0;
    final todaySessions = stats['todaySessions'] ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.check_circle,
                  label: 'Total',
                  value: totalSessions.toString(),
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.work,
                  label: 'Trabajo',
                  value: workSessions.toString(),
                  color: Colors.red,
                ),
                _buildStatItem(
                  icon: Icons.access_time,
                  label: 'Minutos',
                  value: totalMinutes.toString(),
                  color: Colors.green,
                ),
                _buildStatItem(
                  icon: Icons.today,
                  label: 'Hoy',
                  value: todaySessions.toString(),
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  /// Agrupar sesiones por fecha
  Map<String, List<PomodoroSession>> _groupSessionsByDate(
      List<PomodoroSession> sessions) {
    final Map<String, List<PomodoroSession>> grouped = {};

    for (final session in sessions) {
      final date = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      final dateKey = _formatDate(date);

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(session);
    }

    return grouped;
  }

  /// Sección de fecha con sesiones
  Widget _buildDateSection(String date, List<PomodoroSession> sessions) {
    final workSessions = sessions.where((s) => s.sessionType == SessionType.work).length;
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + (s.actualDuration ?? s.duration) ~/ 60,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$workSessions sesiones • $totalMinutes min',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        ...sessions.map((session) => _buildSessionCard(session)),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Card de sesión individual
  Widget _buildSessionCard(PomodoroSession session) {
    final color = _getColorForSessionType(session.sessionType);
    final icon = _getIconForSessionType(session.sessionType);
    final duration = (session.actualDuration ?? session.duration) ~/ 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(session.sessionType.displayName),
        subtitle: Text(
          '${_formatTime(session.startTime)} - ${session.endTime != null ? _formatTime(session.endTime!) : "En progreso"}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$duration min',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (session.isCompleted)
              const Icon(Icons.check_circle, color: Colors.green, size: 16)
            else
              const Icon(Icons.pending, color: Colors.orange, size: 16),
          ],
        ),
      ),
    );
  }

  /// Estado vacío
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay sesiones en este período',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completa sesiones Pomodoro para ver tu historial',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Mostrar selector de rango de fechas
  Future<void> _showDateRangePicker() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate!,
        end: _endDate!,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      await _loadSessions();
    }
  }

  /// Formatear fecha
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hoy';
    } else if (dateOnly == yesterday) {
      return 'Ayer';
    } else {
      final months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  /// Formatear hora
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Obtener color por tipo de sesión
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

  /// Obtener ícono por tipo de sesión
  IconData _getIconForSessionType(SessionType type) {
    switch (type) {
      case SessionType.work:
        return Icons.work;
      case SessionType.shortBreak:
        return Icons.coffee;
      case SessionType.longBreak:
        return Icons.beach_access;
    }
  }
}
