import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../controllers/event_controller.dart';
import '../controllers/pomodoro_controller.dart';
import '../models/event.dart';
import '../models/pomodoro_session.dart';
import '../services/connectivity_service.dart';
import 'add_edit_event_screen.dart';
import 'event_detail_screen.dart';
import 'list_categories_screen.dart';
import 'task_list_screen.dart';
import 'pomodoro_screen.dart';
import 'pomodoro_history_screen.dart';
import '../widgets/event_card.dart';
import '../widgets/custom_app_bar.dart';

/// Pantalla principal de la aplicación - Vista del calendario y eventos
/// Implementa Material Design y mejores prácticas de UX
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Cargar datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventController>().loadEvents();
      context.read<PomodoroController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Mi Agenda'),
      drawer: _buildDrawer(context),
      body: Consumer<EventController>(
        builder: (context, controller, child) {
          // Mostrar indicador de carga
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Mostrar mensaje de error si existe
          if (controller.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar eventos',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.loadEvents(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Banner de estado de conectividad
              _buildConnectivityBanner(),
              
              // Calendario widget
              _buildCalendar(controller),
              
              // Lista de eventos del día seleccionado
              Expanded(
                child: _buildEventsList(controller),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab', // Tag único para evitar conflictos de Hero
        onPressed: () => _navigateToAddEvent(),
        tooltip: 'Agregar evento',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Construir el widget del calendario
  Widget _buildCalendar(EventController controller) {
    return Consumer<PomodoroController>(
      builder: (context, pomodoroController, child) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          elevation: 4,
          child: TableCalendar<dynamic>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(controller.selectedDate, day);
            },
            calendarFormat: _calendarFormat,
            eventLoader: (day) {
              // Combinar eventos y sesiones Pomodoro
              final events = controller.events.where((event) {
                return isSameDay(event.startTime, day);
              }).toList();
              
              final pomodoroSessions = pomodoroController.sessions.where((session) {
                return isSameDay(session.startTime, day) && session.isCompleted;
              }).toList();
              
              // Retornar lista combinada para mostrar marcadores
              return [...events, ...pomodoroSessions];
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
              holidayTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                
                // Separar eventos de sesiones Pomodoro
                final eventCount = events.where((e) => e is Event).length;
                final pomodoroCount = events.where((e) => e is PomodoroSession).length;
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Marcador de eventos
                    if (eventCount > 0)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    // Marcador de Pomodoro
                    if (pomodoroCount > 0)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                );
              },
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16.0),
              ),
              formatButtonTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              controller.selectDate(selectedDay);
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          ),
        );
      },
    );
  }

  /// Construir la lista de eventos del día seleccionado
  Widget _buildEventsList(EventController controller) {
    return Consumer<PomodoroController>(
      builder: (context, pomodoroController, child) {
        final eventsForDay = controller.eventsForSelectedDate;
        final pomodoroSessionsForDay = pomodoroController.sessions.where((session) {
          return isSameDay(session.startTime, controller.selectedDate) && session.isCompleted;
        }).toList();

        if (eventsForDay.isEmpty && pomodoroSessionsForDay.isEmpty) {
          return _buildEmptyState();
        }

        return ListView(
          padding: const EdgeInsets.all(8.0),
          children: [
            // Sección de Eventos
            if (eventsForDay.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Eventos (${eventsForDay.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ...eventsForDay.map((event) {
                return EventCard(
                  event: event,
                  onTap: () => _navigateToEventDetail(event),
                  onToggleComplete: () => controller.toggleEventCompletion(event.id),
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
            
            // Sección de Sesiones Pomodoro
            if (pomodoroSessionsForDay.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer,
                      size: 20,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sesiones Pomodoro (${pomodoroSessionsForDay.length}) 🍅',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ...pomodoroSessionsForDay.map((session) {
                return _buildPomodoroSessionCard(context, session);
              }).toList(),
            ],
          ],
        );
      },
    );
  }

  /// Estado vacío cuando no hay eventos
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay eventos para este día',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para agregar un nuevo evento',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// Card de sesión Pomodoro
  Widget _buildPomodoroSessionCard(BuildContext context, PomodoroSession session) {
    final sessionColor = _getSessionColor(session.sessionType);
    final sessionLabel = _getSessionLabel(session.sessionType);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: sessionColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.timer,
            color: sessionColor,
            size: 24,
          ),
        ),
        title: Text(
          sessionLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_formatTime(session.startTime)}${session.endTime != null ? ' - ${_formatTime(session.endTime!)}' : ''} • ${session.durationInMinutes} min',
        ),
        trailing: session.taskId != null
            ? const Icon(Icons.task_alt, color: Colors.blue, size: 20)
            : null,
        onTap: () {
          // Navegar a historial de Pomodoro
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PomodoroHistoryScreen(),
            ),
          );
        },
      ),
    );
  }

  /// Obtener color por tipo de sesión
  Color _getSessionColor(SessionType type) {
    switch (type) {
      case SessionType.work:
        return Colors.red;
      case SessionType.shortBreak:
        return Colors.green;
      case SessionType.longBreak:
        return Colors.blue;
    }
  }

  /// Obtener etiqueta por tipo de sesión
  String _getSessionLabel(SessionType type) {
    switch (type) {
      case SessionType.work:
        return 'Trabajo 🍅';
      case SessionType.shortBreak:
        return 'Descanso Corto ☕';
      case SessionType.longBreak:
        return 'Descanso Largo 🌟';
    }
  }

  /// Formatear hora
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Banner de estado de conectividad y sincronización
  Widget _buildConnectivityBanner() {
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectionStream,
      initialData: ConnectivityService().isOnline,
      builder: (context, connectivitySnapshot) {
        final isOnline = connectivitySnapshot.data ?? false;
        
        // Si está offline, mostrar banner naranja
        if (!isOnline) {
          return _buildBanner(
            color: Colors.orange.shade600,
            icon: Icons.cloud_off,
            text: 'Modo Offline',
          );
        }
        
        // Si está online, mostrar estado basado en sincronización
        // Por ahora, mostrar "Sincronizado" por defecto cuando está online
        return _buildBanner(
          color: Colors.green.shade600,
          icon: Icons.cloud_done,
          text: 'Conectado - Sincronizado',
        );
      },
    );
  }
  
  /// Construir banner con estilos consistentes
  Widget _buildBanner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Navegar a la pantalla de agregar evento
  void _navigateToAddEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(
          selectedDate: context.read<EventController>().selectedDate,
        ),
      ),
    );
  }

  /// Navegar a la pantalla de detalle del evento
  void _navigateToEventDetail(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(event: event),
      ),
    );
  }

  /// Construir el drawer de navegación
  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 48,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Mi Agenda',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Organiza tu vida',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categorías'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListCategoriesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('Tareas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TaskListScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Pomodoro'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PomodoroScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial Pomodoro'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PomodoroHistoryScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navegar a configuración
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configuración - Próximamente'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  /// Mostrar diálogo "Acerca de"
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Mi Agenda',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.calendar_today,
        size: 48,
      ),
      children: [
        const Text(
          'Una aplicación de gestión de eventos y tareas con sincronización en la nube.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Desarrollado con Flutter y Firebase.',
        ),
      ],
    );
  }
}
