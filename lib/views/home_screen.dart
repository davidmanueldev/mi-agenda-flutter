import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../controllers/event_controller.dart';
import '../models/event.dart';
import '../services/connectivity_service.dart';
import 'add_edit_event_screen.dart';
import 'event_detail_screen.dart';
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Mi Agenda'),
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
        onPressed: () => _navigateToAddEvent(),
        tooltip: 'Agregar evento',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Construir el widget del calendario
  Widget _buildCalendar(EventController controller) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: TableCalendar<Event>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) {
          return isSameDay(controller.selectedDate, day);
        },
        calendarFormat: _calendarFormat,
        eventLoader: (day) {
          // Retornar eventos para el día especificado
          return controller.events.where((event) {
            return isSameDay(event.startTime, day);
          }).toList();
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
  }

  /// Construir la lista de eventos del día seleccionado
  Widget _buildEventsList(EventController controller) {
    final eventsForDay = controller.eventsForSelectedDate;

    if (eventsForDay.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: eventsForDay.length,
      itemBuilder: (context, index) {
        final event = eventsForDay[index];
        return EventCard(
          event: event,
          onTap: () => _navigateToEventDetail(event),
          onToggleComplete: () => controller.toggleEventCompletion(event.id),
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
}
