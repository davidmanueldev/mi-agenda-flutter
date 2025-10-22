import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/category.dart' as model;

/// Widget personalizado para mostrar un evento en formato de tarjeta
/// Implementa Material Design y accesibilidad
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;
  final model.Category? category;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onToggleComplete,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: category?.color ?? colorScheme.primary,
                width: 4.0,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono de estado del evento
                _buildStatusIcon(colorScheme),
                
                const SizedBox(width: 12),
                
                // Contenido principal del evento
                Expanded(
                  child: _buildEventContent(theme),
                ),
                
                // Botón de acciones
                _buildActionButton(colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construir icono de estado del evento
  Widget _buildStatusIcon(ColorScheme colorScheme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: event.isCompleted
            ? colorScheme.primary
            : colorScheme.outline.withOpacity(0.3),
      ),
      child: Icon(
        event.isCompleted ? Icons.check : category?.icon ?? Icons.event,
        size: 16,
        color: event.isCompleted
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
      ),
    );
  }

  /// Construir contenido principal del evento
  Widget _buildEventContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título del evento
        Text(
          event.title,
          style: theme.textTheme.titleMedium?.copyWith(
            decoration: event.isCompleted 
                ? TextDecoration.lineThrough 
                : null,
            color: event.isCompleted
                ? theme.colorScheme.outline
                : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // Horario del evento
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 4),
            Text(
              _formatTimeRange(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        
        // Descripción del evento (si existe)
        if (event.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            event.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        
        // Duración del evento
        const SizedBox(height: 4),
        _buildDurationChip(theme),
      ],
    );
  }

  /// Construir botón de acciones
  Widget _buildActionButton(ColorScheme colorScheme) {
    return IconButton(
      onPressed: onToggleComplete,
      icon: Icon(
        event.isCompleted ? Icons.undo : Icons.check_circle_outline,
        color: event.isCompleted
            ? colorScheme.outline
            : colorScheme.primary,
      ),
      tooltip: event.isCompleted 
          ? 'Marcar como pendiente' 
          : 'Marcar como completado',
    );
  }

  /// Construir chip de duración
  Widget _buildDurationChip(ThemeData theme) {
    final duration = event.durationInMinutes;
    final durationText = duration < 60
        ? '${duration}m'
        : '${(duration / 60).floor()}h ${duration % 60}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        durationText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  /// Formatear rango de tiempo del evento
  String _formatTimeRange() {
    final startTime = _formatTime(event.startTime);
    final endTime = _formatTime(event.endTime);
    
    // Si el evento es en el mismo día, mostrar solo las horas
    if (_isSameDay(event.startTime, event.endTime)) {
      return '$startTime - $endTime';
    }
    
    // Si abarca múltiples días, mostrar fechas completas
    return '${_formatDate(event.startTime)} $startTime - ${_formatDate(event.endTime)} $endTime';
  }

  /// Formatear hora en formato 24h
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Formatear fecha
  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}';
  }

  /// Verificar si dos fechas son del mismo día
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}
