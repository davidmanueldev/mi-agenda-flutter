import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:form_field_validator/form_field_validator.dart';
import '../controllers/event_controller.dart';
import '../models/event.dart';
import '../models/category.dart';
import '../widgets/custom_app_bar.dart';

/// Pantalla para agregar o editar eventos
/// Implementa validación de formularios y UX intuitiva
class AddEditEventScreen extends StatefulWidget {
  final Event? event;
  final DateTime? selectedDate;

  const AddEditEventScreen({
    super.key,
    this.event,
    this.selectedDate,
  });

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String? _selectedCategoryId;
  bool _isLoading = false;

  /// Validadores de formulario
  final _titleValidator = MultiValidator([
    RequiredValidator(errorText: 'El título es requerido'),
    MinLengthValidator(3, errorText: 'El título debe tener al menos 3 caracteres'),
    MaxLengthValidator(100, errorText: 'El título no puede exceder 100 caracteres'),
  ]);

  final _descriptionValidator = MaxLengthValidator(
    500, 
    errorText: 'La descripción no puede exceder 500 caracteres'
  );

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Inicializar formulario con datos existentes o valores por defecto
  void _initializeForm() {
    if (widget.event != null) {
      // Modo edición: cargar datos del evento
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description;
      _startDateTime = widget.event!.startTime;
      _endDateTime = widget.event!.endTime;
      _selectedCategoryId = widget.event!.category;
    } else {
      // Modo creación: valores por defecto
      final now = DateTime.now();
      final baseDate = widget.selectedDate ?? now;
      
      _startDateTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        now.hour + 1,
        0,
      );
      
      _endDateTime = _startDateTime!.add(const Duration(hours: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: isEditing ? 'Editar Evento' : 'Nuevo Evento',
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
              tooltip: 'Eliminar evento',
            ),
        ],
      ),
      body: Consumer<EventController>(
        builder: (context, controller, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Campo título
                _buildTitleField(),
                
                const SizedBox(height: 16),
                
                // Campo descripción
                _buildDescriptionField(),
                
                const SizedBox(height: 16),
                
                // Selección de categoría
                _buildCategorySelector(controller),
                
                const SizedBox(height: 24),
                
                // Selección de fecha y hora de inicio
                _buildDateTimeSelector(
                  title: 'Fecha y hora de inicio',
                  dateTime: _startDateTime,
                  onChanged: _onStartDateTimeChanged,
                ),
                
                const SizedBox(height: 16),
                
                // Selección de fecha y hora de fin
                _buildDateTimeSelector(
                  title: 'Fecha y hora de fin',
                  dateTime: _endDateTime,
                  onChanged: _onEndDateTimeChanged,
                ),
                
                const SizedBox(height: 32),
                
                // Mostrar mensaje de error si existe
                if (controller.errorMessage != null)
                  _buildErrorMessage(controller.errorMessage!),
                
                const SizedBox(height: 16),
                
                // Botones de acción
                _buildActionButtons(controller, isEditing),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Campo de título
  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Título del evento',
        hintText: 'Ingresa el título del evento',
        prefixIcon: Icon(Icons.title),
        border: OutlineInputBorder(),
      ),
      validator: _titleValidator.call,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 100,
    );
  }

  /// Campo de descripción
  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Descripción (opcional)',
        hintText: 'Describe los detalles del evento',
        prefixIcon: Icon(Icons.description),
        border: OutlineInputBorder(),
      ),
      validator: _descriptionValidator.call,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      maxLength: 500,
    );
  }

  /// Selector de categoría
  Widget _buildCategorySelector(EventController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categoría',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: () => _showCreateCategoryDialog(controller),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: controller.categories.isEmpty
              ? const Center(
                  child: Text('Cargando categorías...'),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.categories.map((category) {
                    final isSelected = _selectedCategoryId == category.id;
                    return FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.icon,
                            size: 16,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : category.color,
                          ),
                          const SizedBox(width: 4),
                          Text(category.name),
                        ],
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryId = selected ? category.id : null;
                        });
                      },
                      backgroundColor: category.color.withOpacity(0.1),
                      selectedColor: category.color,
                    );
                  }).toList(),
                ),
        ),
        if (_selectedCategoryId == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Selecciona una categoría',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  /// Selector de fecha y hora
  Widget _buildDateTimeSelector({
    required String title,
    required DateTime? dateTime,
    required ValueChanged<DateTime> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Selector de fecha
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectDate(dateTime, onChanged),
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  dateTime != null
                      ? _formatDate(dateTime)
                      : 'Seleccionar fecha',
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Selector de hora
            Expanded(
              child: OutlinedButton.icon(
                onPressed: dateTime != null
                    ? () => _selectTime(dateTime, onChanged)
                    : null,
                icon: const Icon(Icons.access_time),
                label: Text(
                  dateTime != null
                      ? _formatTime(dateTime)
                      : 'Seleccionar hora',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Mensaje de error
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botones de acción
  Widget _buildActionButtons(EventController controller, bool isEditing) {
    return Row(
      children: [
        // Botón cancelar
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 16),
        // Botón guardar
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _saveEvent(controller),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? 'Actualizar' : 'Guardar'),
          ),
        ),
      ],
    );
  }

  /// Seleccionar fecha
  Future<void> _selectDate(DateTime? currentDate, ValueChanged<DateTime> onChanged) async {
    final initialDate = currentDate ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      final newDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        currentDate?.hour ?? 9,
        currentDate?.minute ?? 0,
      );
      onChanged(newDateTime);
    }
  }

  /// Seleccionar hora
  Future<void> _selectTime(DateTime currentDate, ValueChanged<DateTime> onChanged) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDate),
    );

    if (pickedTime != null) {
      final newDateTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      onChanged(newDateTime);
    }
  }

  /// Manejar cambio en fecha/hora de inicio
  void _onStartDateTimeChanged(DateTime newDateTime) {
    setState(() {
      _startDateTime = newDateTime;
      
      // Ajustar automáticamente la hora de fin si es necesaria
      if (_endDateTime == null || _endDateTime!.isBefore(newDateTime)) {
        _endDateTime = newDateTime.add(const Duration(hours: 1));
      }
    });
  }

  /// Manejar cambio en fecha/hora de fin
  void _onEndDateTimeChanged(DateTime newDateTime) {
    setState(() {
      _endDateTime = newDateTime;
    });
  }

  /// Guardar evento
  Future<void> _saveEvent(EventController controller) async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool success;
      
      if (widget.event != null) {
        // Actualizar evento existente
        success = await controller.updateEvent(
          widget.event!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startTime: _startDateTime!,
          endTime: _endDateTime!,
          categoryId: _selectedCategoryId!,
        );
      } else {
        // Crear nuevo evento
        success = await controller.createEvent(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startTime: _startDateTime!,
          endTime: _endDateTime!,
          categoryId: _selectedCategoryId!,
        );
      }

      if (success && mounted) {
        Navigator.of(context).pop();
        _showSuccessMessage();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Validar formulario
  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedCategoryId == null) {
      _showErrorSnackBar('Por favor selecciona una categoría');
      return false;
    }

    if (_startDateTime == null || _endDateTime == null) {
      _showErrorSnackBar('Por favor selecciona las fechas del evento');
      return false;
    }

    if (_endDateTime!.isBefore(_startDateTime!)) {
      _showErrorSnackBar('La fecha de fin debe ser posterior a la de inicio');
      return false;
    }

    return true;
  }

  /// Mostrar confirmación de eliminación
  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text('¿Estás seguro de que quieres eliminar este evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteEvent();
    }
  }

  /// Eliminar evento
  Future<void> _deleteEvent() async {
    final controller = context.read<EventController>();
    final success = await controller.deleteEvent(widget.event!.id);
    
    if (success && mounted) {
      Navigator.of(context).pop();
      _showSuccessMessage('Evento eliminado correctamente');
    }
  }

  /// Mostrar mensaje de éxito
  void _showSuccessMessage([String? message]) {
    final defaultMessage = widget.event != null
        ? 'Evento actualizado correctamente'
        : 'Evento creado correctamente';
        
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? defaultMessage),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// Mostrar mensaje de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// Mostrar diálogo para crear nueva categoría
  Future<void> _showCreateCategoryDialog(EventController controller) async {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;
    IconData selectedIcon = Icons.category;
    
    // Colores predefinidos
    final colors = [
      Colors.blue, Colors.green, Colors.red, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.amber,
      Colors.indigo, Colors.cyan,
    ];
    
    // Iconos predefinidos
    final icons = [
      Icons.work, Icons.personal_injury, Icons.school, Icons.fitness_center,
      Icons.shopping_cart, Icons.restaurant, Icons.flight, Icons.local_hospital,
      Icons.celebration, Icons.sports_soccer, Icons.music_note, Icons.book,
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva Categoría'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo de nombre
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Reuniones',
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                
                // Selector de color
                Text('Color', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((color) {
                    final isSelected = color == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected 
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                
                // Selector de icono
                Text('Icono', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((icon) {
                    final isSelected = icon == selectedIcon;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? selectedColor.withOpacity(0.2) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? selectedColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(icon, color: isSelected ? selectedColor : Colors.grey),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                
                // Crear nueva categoría
                final newCategory = Category.create(
                  name: name,
                  description: 'Categoría personalizada',
                  color: selectedColor,
                  icon: selectedIcon,
                );
                
                Navigator.of(context).pop();
                
                // Guardar categoría
                final success = await controller.createCategory(newCategory);
                
                if (success && mounted) {
                  // Auto-seleccionar la nueva categoría
                  setState(() {
                    _selectedCategoryId = newCategory.id;
                  });
                  
                  _showSuccessMessage('Categoría creada correctamente');
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  /// Formatear fecha
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Formatear hora
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
