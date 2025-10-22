import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/event_controller.dart';
import '../models/event.dart';
import '../widgets/custom_app_bar.dart';
import 'add_edit_event_screen.dart';

/// Pantalla de detalle de evento con opciones de edición y eliminación
class EventDetailScreen extends StatelessWidget {
  final Event event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Detalle del Evento',
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editEvent(context),
            tooltip: 'Editar evento',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título del evento
            _buildEventTitle(context),
            
            const SizedBox(height: 24),
            
            // Información del tiempo
            _buildTimeInfo(context),
            
            const SizedBox(height: 24),
            
            // Descripción del evento
            if (event.description.isNotEmpty) ...[
              _buildDescription(context),
              const SizedBox(height: 24),
            ],
            
            // Estado del evento
            _buildEventStatus(context),
          ],
        ),
      ),
    );
  }

  /// Construir título del evento
  Widget _buildEventTitle(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              event.isCompleted ? Icons.check_circle : Icons.event,
              size: 32,
              color: event.isCompleted
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  decoration: event.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir información de tiempo
  Widget _buildTimeInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horario',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildTimeInfoRow(
              context,
              Icons.schedule,
              'Inicio',
              _formatDateTime(event.startTime),
            ),
            const SizedBox(height: 8),
            _buildTimeInfoRow(
              context,
              Icons.schedule,
              'Fin',
              _formatDateTime(event.endTime),
            ),
            const SizedBox(height: 8),
            _buildTimeInfoRow(
              context,
              Icons.timer,
              'Duración',
              _formatDuration(event.durationInMinutes),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir fila de información de tiempo
  Widget _buildTimeInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// Construir descripción del evento
  Widget _buildDescription(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Descripción',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              event.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Construir estado del evento
  Widget _buildEventStatus(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Consumer<EventController>(
              builder: (context, controller, child) {
                return SwitchListTile(
                  value: event.isCompleted,
                  onChanged: (value) {
                    controller.toggleEventCompletion(event.id);
                    Navigator.of(context).pop();
                  },
                  title: Text(
                    event.isCompleted ? 'Completado' : 'Pendiente',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    event.isCompleted
                        ? 'Este evento ha sido marcado como completado'
                        : 'Este evento está pendiente',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  secondary: Icon(
                    event.isCompleted ? Icons.check_circle : Icons.pending,
                    color: event.isCompleted
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Navegar a editar evento
  void _editEvent(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(event: event),
      ),
    );
  }

  /// Formatear fecha y hora
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Formatear duración
  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes minutos';
    }
    
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    
    if (remainingMinutes == 0) {
      return '$hours hora${hours != 1 ? 's' : ''}';
    }
    
    return '$hours hora${hours != 1 ? 's' : ''} y $remainingMinutes minuto${remainingMinutes != 1 ? 's' : ''}';
  }
}
