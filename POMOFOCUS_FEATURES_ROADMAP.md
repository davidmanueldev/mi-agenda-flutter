# 🍅 Roadmap de Funcionalidades Inspiradas en Pomofocus

**Fecha:** 24 de Octubre, 2025  
**Versión:** 1.0  
**Referencia:** [Pomofocus.io](https://pomofocus.io)

---

## 📊 Análisis Comparativo

### ✅ Funcionalidades YA IMPLEMENTADAS

| Funcionalidad | Estado | Archivo | Notas |
|---------------|--------|---------|-------|
| **Pomodoro Timer** | ✅ COMPLETO | `pomodoro_controller.dart` | 25/5/15 min, auto-switch |
| **Configuración Personalizada** | ✅ COMPLETO | `pomodoro_screen.dart` | Duraciones ajustables |
| **Historial de Sesiones** | ✅ COMPLETO | `pomodoro_history_screen.dart` | Con filtro de fechas |
| **Estadísticas Básicas** | ✅ COMPLETO | `pomodoro_history_screen.dart` | Total, trabajo, minutos, hoy |
| **Sincronización Bidireccional** | ✅ COMPLETO | `database_service_hybrid_v2.dart` | Firebase + SQLite |
| **Sistema de Tareas** | ✅ COMPLETO | `task_controller.dart` | CRUD completo |
| **Notificaciones** | ✅ COMPLETO | `notification_service.dart` | Al finalizar sesión |

---

## 🆕 Funcionalidades NUEVAS de Pomofocus

### 1️⃣ Estimación de Pomodoros por Tarea 🎯

**Descripción**: Cada tarea puede tener un número estimado de pomodoros para completarla.

#### Cambios Necesarios:

**A. Modelo Task**
```dart
// lib/models/task.dart

class Task {
  // ... campos existentes ...
  
  // NUEVOS CAMPOS
  final int estimatedPomodoros;  // Pomodoros estimados (default: 1)
  final int completedPomodoros;  // Pomodoros ya completados (default: 0)
  
  Task({
    // ... parámetros existentes ...
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
  });
  
  // Getter útil
  int get remainingPomodoros => 
    (estimatedPomodoros - completedPomodoros).clamp(0, estimatedPomodoros);
  
  double get pomodoroProgress => 
    estimatedPomodoros > 0 ? completedPomodoros / estimatedPomodoros : 0.0;
}
```

**B. Database Schema (SQLite v5)**
```sql
-- Agregar columnas a tabla tasks
ALTER TABLE tasks ADD COLUMN estimated_pomodoros INTEGER DEFAULT 1;
ALTER TABLE tasks ADD COLUMN completed_pomodoros INTEGER DEFAULT 0;
```

**C. UI en AddEditTaskScreen**
```dart
// Agregar selector de estimación
Widget _buildPomodoroEstimation() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Estimated Pomodoros', style: theme.textTheme.titleSmall),
      Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove_circle_outline),
            onPressed: () => setState(() {
              if (_estimatedPomodoros > 1) _estimatedPomodoros--;
            }),
          ),
          Text('$_estimatedPomodoros 🍅', style: theme.textTheme.titleLarge),
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () => setState(() {
              _estimatedPomodoros++;
            }),
          ),
        ],
      ),
      Text(
        '≈ ${_estimatedPomodoros * 25} minutes',
        style: theme.textTheme.bodySmall,
      ),
    ],
  );
}
```

**D. Mostrar Progreso en TaskCard**
```dart
// En _TaskCard widget
Widget _buildPomodoroProgress() {
  return Row(
    children: [
      Text('${task.completedPomodoros}/${task.estimatedPomodoros} 🍅'),
      SizedBox(width: 8),
      Expanded(
        child: LinearProgressIndicator(
          value: task.pomodoroProgress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
        ),
      ),
    ],
  );
}
```

**Prioridad**: ⭐⭐⭐⭐⭐ ALTA  
**Esfuerzo**: 2-3 horas  
**Impacto**: Mejora significativa en productividad

---

### 2️⃣ Selector de Tarea en Pomodoro Timer 🔗

**Descripción**: Antes de iniciar una sesión Pomodoro, seleccionar qué tarea se va a trabajar.

#### Implementación:

**A. Modificar PomodoroScreen**
```dart
// En PomodoroScreen, método start modificado:
Future<void> _startWithTaskSelection(BuildContext context) async {
  final controller = context.read<PomodoroController>();
  final taskController = context.read<TaskController>();
  
  // Mostrar diálogo de selección
  final selectedTask = await showDialog<Task>(
    context: context,
    builder: (context) => _TaskSelectionDialog(
      tasks: taskController.tasks.where((t) => !t.isCompleted).toList(),
    ),
  );
  
  // Iniciar con o sin tarea vinculada
  await controller.start(taskId: selectedTask?.id);
}
```

**B. Diálogo de Selección**
```dart
class _TaskSelectionDialog extends StatelessWidget {
  final List<Task> tasks;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Task'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: tasks.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // Opción: "No task (free focus)"
              return ListTile(
                leading: Icon(Icons.hourglass_empty),
                title: Text('No task (free focus)'),
                onTap: () => Navigator.pop(context, null),
              );
            }
            
            final task = tasks[index - 1];
            return ListTile(
              leading: CircleAvatar(
                child: Text('${task.completedPomodoros}/${task.estimatedPomodoros}'),
              ),
              title: Text(task.title),
              subtitle: Text('${task.remainingPomodoros} 🍅 remaining'),
              onTap: () => Navigator.pop(context, task),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
```

**C. Mostrar Tarea Activa durante Sesión**
```dart
// En _buildSessionTypeIndicator
if (controller.linkedTaskId != null) {
  return Consumer<TaskController>(
    builder: (context, taskController, _) {
      final task = taskController.tasks.firstWhere(
        (t) => t.id == controller.linkedTaskId,
        orElse: () => null,
      );
      
      if (task != null) {
        return Card(
          child: ListTile(
            leading: Icon(Icons.task_alt),
            title: Text(task.title),
            subtitle: Text('${task.remainingPomodoros} 🍅 remaining'),
          ),
        );
      }
    },
  );
}
```

**D. Auto-incrementar Pomodoros Completados**
```dart
// En PomodoroController._completeSession()
if (_linkedTaskId != null && _currentSessionType == SessionType.work) {
  // Incrementar contador de pomodoros de la tarea
  final task = await _database.getTaskById(_linkedTaskId!);
  if (task != null) {
    final updatedTask = task.copyWith(
      completedPomodoros: task.completedPomodoros + 1,
    );
    await _database.updateTask(updatedTask);
  }
}
```

**Prioridad**: ⭐⭐⭐⭐⭐ ALTA  
**Esfuerzo**: 3-4 horas  
**Impacto**: Conexión directa entre Pomodoro y Tareas

---

### 3️⃣ Tiempo Estimado de Finalización ⏱️

**Descripción**: Mostrar a qué hora se completarán todas las tareas del día.

#### Implementación:

**A. En TaskController**
```dart
// lib/controllers/task_controller.dart

DateTime? get estimatedFinishTime {
  // Filtrar tareas no completadas
  final pendingTasks = _tasks.where((t) => !t.isCompleted).toList();
  
  if (pendingTasks.isEmpty) return null;
  
  // Calcular pomodoros restantes
  int totalPomodorosRemaining = pendingTasks.fold(
    0,
    (sum, task) => sum + task.remainingPomodoros,
  );
  
  // Calcular tiempo total (pomodoros + descansos)
  // Fórmula: cada 4 pomodoros = 1 descanso largo (15min)
  //          resto = descansos cortos (5min)
  int longBreaks = totalPomodorosRemaining ~/ 4;
  int shortBreaks = (totalPomodorosRemaining % 4) - 1;
  if (shortBreaks < 0) shortBreaks = 0;
  
  int totalMinutes = (totalPomodorosRemaining * 25) +
                     (longBreaks * 15) +
                     (shortBreaks * 5);
  
  return DateTime.now().add(Duration(minutes: totalMinutes));
}

String get estimatedFinishTimeFormatted {
  final time = estimatedFinishTime;
  if (time == null) return 'All done! 🎉';
  
  final hour = time.hour;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  
  return 'Finish by $hour12:$minute $period';
}
```

**B. UI en TaskListScreen**
```dart
// Agregar banner en la parte superior
Widget _buildEstimatedFinishBanner() {
  return Consumer<TaskController>(
    builder: (context, controller, _) {
      final finishTime = controller.estimatedFinishTime;
      
      if (finishTime == null) {
        return SizedBox.shrink();
      }
      
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.purple],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.white),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.estimatedFinishTimeFormatted,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Based on ${controller.tasks.where((t) => !t.isCompleted).length} pending tasks',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
```

**Prioridad**: ⭐⭐⭐⭐ MEDIA-ALTA  
**Esfuerzo**: 1-2 horas  
**Impacto**: Motivación y planificación del día

---

### 4️⃣ Templates de Tareas 📝

**Descripción**: Guardar tareas repetitivas como templates para agregarlas rápidamente.

#### Implementación:

**A. Modelo TaskTemplate**
```dart
// lib/models/task_template.dart

class TaskTemplate {
  final String id;
  final String title;
  final String? description;
  final int estimatedPomodoros;
  final List<String> steps;
  final TaskPriority priority;
  final String category;
  final DateTime createdAt;

  TaskTemplate({
    required this.id,
    required this.title,
    this.description,
    required this.estimatedPomodoros,
    required this.steps,
    required this.priority,
    required this.category,
    required this.createdAt,
  });

  // Crear Task desde template
  Task toTask() {
    return Task(
      id: SecurityUtils.generateSecureId(),
      userId: 'current_user', // Reemplazar con userId real
      title: title,
      description: description,
      dueDate: null,
      priority: priority,
      status: TaskStatus.pending,
      category: category,
      estimatedPomodoros: estimatedPomodoros,
      completedPomodoros: 0,
      steps: steps.map((step) => TaskStep(
        id: SecurityUtils.generateSecureId(),
        title: step,
        isCompleted: false,
      )).toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() { /* ... */ }
  factory TaskTemplate.fromMap(Map<String, dynamic> map) { /* ... */ }
}
```

**B. Database Schema (SQLite v5)**
```sql
CREATE TABLE task_templates (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  estimated_pomodoros INTEGER DEFAULT 1,
  steps TEXT, -- JSON array
  priority TEXT NOT NULL,
  category TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
```

**C. UI - Guardar como Template**
```dart
// En TaskDetailScreen, agregar botón
actions: [
  IconButton(
    icon: Icon(Icons.bookmark_add),
    tooltip: 'Save as Template',
    onPressed: () => _saveAsTemplate(context),
  ),
]

Future<void> _saveAsTemplate(BuildContext context) async {
  final template = TaskTemplate(
    id: SecurityUtils.generateSecureId(),
    title: task.title,
    description: task.description,
    estimatedPomodoros: task.estimatedPomodoros,
    steps: task.steps.map((s) => s.title).toList(),
    priority: task.priority,
    category: task.category,
    createdAt: DateTime.now(),
  );
  
  await _database.insertTaskTemplate(template);
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Template saved! 📋')),
  );
}
```

**D. UI - Lista de Templates**
```dart
// En TaskListScreen, agregar botón flotante secundario
FloatingActionButton(
  heroTag: 'templates',
  mini: true,
  child: Icon(Icons.bookmark),
  onPressed: () => _showTemplatesSheet(context),
)

void _showTemplatesSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) => TaskTemplatesSheet(),
  );
}

class TaskTemplatesSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskTemplate>>(
      future: _database.getAllTaskTemplates(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final templates = snapshot.data!;
        
        return ListView.builder(
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text('${template.estimatedPomodoros}🍅'),
              ),
              title: Text(template.title),
              subtitle: Text('${template.steps.length} steps'),
              trailing: IconButton(
                icon: Icon(Icons.add_circle),
                onPressed: () async {
                  final task = template.toTask();
                  await controller.createTask(task);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Task added from template! ✅')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
```

**Prioridad**: ⭐⭐⭐ MEDIA  
**Esfuerzo**: 4-5 horas  
**Impacto**: Gran mejora para usuarios con tareas recurrentes

---

### 5️⃣ Reportes Visuales con Gráficas 📈

**Descripción**: Mostrar estadísticas visuales con gráficas de productividad.

#### Dependencia Necesaria:
```yaml
# pubspec.yaml
dependencies:
  fl_chart: ^0.68.0
```

#### Implementación:

**A. Pantalla de Reportes**
```dart
// lib/views/reports_screen.dart

class ReportsScreen extends StatefulWidget {
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'week'; // week, month, year
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Focus Reports'),
        actions: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
              ButtonSegment(value: 'year', label: Text('Year')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (Set<String> selected) {
              setState(() => _selectedPeriod = selected.first);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSummaryCards(),
            _buildPomodorosPerDayChart(),
            _buildCategoryDistributionChart(),
            _buildProductiveHoursChart(),
            _buildStreakCard(),
          ],
        ),
      ),
    );
  }
  
  // 1. Tarjetas de resumen
  Widget _buildSummaryCards() {
    return Consumer<PomodoroController>(
      builder: (context, controller, _) {
        final stats = controller.stats;
        return Row(
          children: [
            _SummaryCard(
              title: 'Total Focus',
              value: '${stats['totalMinutes'] ?? 0}',
              unit: 'min',
              icon: Icons.timer,
              color: Colors.red,
            ),
            _SummaryCard(
              title: 'Sessions',
              value: '${stats['totalSessions'] ?? 0}',
              unit: '🍅',
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            _SummaryCard(
              title: 'Streak',
              value: '${_calculateStreak()}',
              unit: 'days',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
          ],
        );
      },
    );
  }
  
  // 2. Gráfica de barras: Pomodoros por día
  Widget _buildPomodorosPerDayChart() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pomodoros per Day', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: _getPomodorosPerDayData(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          return Text(days[value.toInt() % 7]);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 3. Gráfica de pastel: Distribución por categoría
  Widget _buildCategoryDistributionChart() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Focus by Category', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _getCategoryDistributionData(),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 4. Gráfica de línea: Horas productivas del día
  Widget _buildProductiveHoursChart() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Most Productive Hours', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getProductiveHoursData(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}h');
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 5. Tarjeta de racha
  Widget _buildStreakCard() {
    final streak = _calculateStreak();
    return Card(
      color: Colors.orange[50],
      child: ListTile(
        leading: Icon(Icons.local_fire_department, color: Colors.orange, size: 40),
        title: Text('$streak Day Streak! 🔥'),
        subtitle: Text('Keep it up!'),
      ),
    );
  }
  
  // Métodos helper para obtener datos
  List<BarChartGroupData> _getPomodorosPerDayData() {
    // Consultar sesiones de los últimos 7 días
    // Agrupar por día y contar
    // Retornar BarChartGroupData
  }
  
  List<PieChartSectionData> _getCategoryDistributionData() {
    // Consultar sesiones por categoría de tarea vinculada
    // Retornar PieChartSectionData
  }
  
  List<FlSpot> _getProductiveHoursData() {
    // Consultar sesiones agrupadas por hora del día
    // Retornar FlSpot(hora, cantidad)
  }
  
  int _calculateStreak() {
    // Consultar días consecutivos con al menos 1 sesión
  }
}
```

**Prioridad**: ⭐⭐⭐ MEDIA  
**Esfuerzo**: 6-8 horas  
**Impacto**: Alta motivación y gamificación

---

### 6️⃣ Sonidos de Ambiente y Personalizados 🔊

**Descripción**: Reproducir sonidos de ambiente durante sesiones y notificaciones personalizadas.

#### Dependencias:
```yaml
dependencies:
  audioplayers: ^5.2.0
```

#### Implementación:

**A. Servicio de Audio**
```dart
// lib/services/audio_service.dart

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  
  factory AudioService() => _instance;
  AudioService._internal();
  
  // Sonidos de ambiente
  final Map<String, String> ambientSounds = {
    'rain': 'assets/sounds/rain.mp3',
    'cafe': 'assets/sounds/cafe.mp3',
    'library': 'assets/sounds/library.mp3',
    'nature': 'assets/sounds/nature.mp3',
    'none': '',
  };
  
  // Sonidos de notificación
  final Map<String, String> notificationSounds = {
    'bell': 'assets/sounds/bell.mp3',
    'chime': 'assets/sounds/chime.mp3',
    'ding': 'assets/sounds/ding.mp3',
  };
  
  Future<void> playAmbientSound(String soundKey) async {
    final path = ambientSounds[soundKey];
    if (path == null || path.isEmpty) {
      await stopAmbientSound();
      return;
    }
    
    await _ambientPlayer.play(AssetSource(path));
    await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
  }
  
  Future<void> stopAmbientSound() async {
    await _ambientPlayer.stop();
  }
  
  Future<void> playNotificationSound(String soundKey) async {
    final path = notificationSounds[soundKey] ?? notificationSounds['bell']!;
    await _player.play(AssetSource(path));
  }
  
  Future<void> setVolume(double volume) async {
    await _ambientPlayer.setVolume(volume);
  }
}
```

**B. Configuración en PomodoroScreen**
```dart
// Agregar al diálogo de settings
Widget _buildSoundSettings() {
  return Column(
    children: [
      Text('Ambient Sound'),
      DropdownButton<String>(
        value: _selectedAmbientSound,
        items: [
          DropdownMenuItem(value: 'none', child: Text('None')),
          DropdownMenuItem(value: 'rain', child: Text('🌧️ Rain')),
          DropdownMenuItem(value: 'cafe', child: Text('☕ Cafe')),
          DropdownMenuItem(value: 'library', child: Text('📚 Library')),
          DropdownMenuItem(value: 'nature', child: Text('🌳 Nature')),
        ],
        onChanged: (value) {
          setState(() => _selectedAmbientSound = value!);
          _audioService.playAmbientSound(value!);
        },
      ),
      SizedBox(height: 16),
      Text('Volume'),
      Slider(
        value: _ambientVolume,
        min: 0,
        max: 1,
        onChanged: (value) {
          setState(() => _ambientVolume = value);
          _audioService.setVolume(value);
        },
      ),
    ],
  );
}
```

**C. Reproducir durante sesión activa**
```dart
// En PomodoroController.start()
if (_selectedAmbientSound != 'none') {
  await _audioService.playAmbientSound(_selectedAmbientSound);
}

// En PomodoroController.stop()
await _audioService.stopAmbientSound();
```

**Prioridad**: ⭐⭐ BAJA  
**Esfuerzo**: 3-4 horas  
**Impacto**: Mejora experiencia de usuario

---

### 7️⃣ Clear Completed Tasks 🗑️

**Descripción**: Botón para archivar/eliminar todas las tareas completadas del día.

#### Implementación:

**A. En TaskController**
```dart
Future<void> clearCompletedTasks() async {
  _setLoading(true);
  
  try {
    final completedTasks = _tasks.where((t) => t.isCompleted).toList();
    
    for (final task in completedTasks) {
      await _database.deleteTask(task.id);
    }
    
    await _loadTasks();
    
    // Notificar éxito
    print('✅ Cleared ${completedTasks.length} completed tasks');
  } catch (e) {
    _setError('Error clearing tasks: $e');
  } finally {
    _setLoading(false);
  }
}
```

**B. UI en TaskListScreen**
```dart
// En AppBar actions
if (controller.tasks.any((t) => t.isCompleted))
  IconButton(
    icon: Icon(Icons.delete_sweep),
    tooltip: 'Clear Completed',
    onPressed: () => _confirmClearCompleted(context),
  ),

Future<void> _confirmClearCompleted(BuildContext context) async {
  final controller = context.read<TaskController>();
  final completedCount = controller.tasks.where((t) => t.isCompleted).length;
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Clear Completed Tasks?'),
      content: Text('This will permanently delete $completedCount completed tasks.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Clear All'),
        ),
      ],
    ),
  );
  
  if (confirmed == true) {
    await controller.clearCompletedTasks();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Cleared $completedCount tasks')),
    );
  }
}
```

**Prioridad**: ⭐⭐ BAJA  
**Esfuerzo**: 30 minutos  
**Impacto**: Limpieza de interfaz

---

## 🎯 Plan de Implementación Recomendado

### Fase 1: Funcionalidades Core (1-2 semanas)
1. ✅ **Probar sincronización bidireccional** (Pendiente)
2. ⭐ **Estimación de Pomodoros por Tarea** (2-3 horas)
3. ⭐ **Selector de Tarea en Pomodoro** (3-4 horas)
4. ⭐ **Tiempo Estimado de Finalización** (1-2 horas)

### Fase 2: Mejoras de Productividad (2-3 semanas)
5. **Templates de Tareas** (4-5 horas)
6. **Clear Completed Tasks** (30 min)

### Fase 3: Visualización y Gamificación (2-3 semanas)
7. **Reportes Visuales con Gráficas** (6-8 horas)

### Fase 4: Experiencia de Usuario (1 semana)
8. **Sonidos de Ambiente** (3-4 horas)

---

## 📊 Comparativa Final

| Funcionalidad Pomofocus | Estado en Mi Agenda | Prioridad | Esfuerzo |
|--------------------------|---------------------|-----------|----------|
| Timer básico | ✅ Completo | - | - |
| Estimación de pomodoros | 🔨 Por implementar | ⭐⭐⭐⭐⭐ | 2-3h |
| Vincular tarea a sesión | 🔨 Por implementar | ⭐⭐⭐⭐⭐ | 3-4h |
| Tiempo estimado fin | 🔨 Por implementar | ⭐⭐⭐⭐ | 1-2h |
| Templates de tareas | 🔨 Por implementar | ⭐⭐⭐ | 4-5h |
| Reportes visuales | 🔨 Por implementar | ⭐⭐⭐ | 6-8h |
| Sonidos ambiente | 🔨 Por implementar | ⭐⭐ | 3-4h |
| Clear completed | 🔨 Por implementar | ⭐⭐ | 30min |

---

## 🔗 Referencias

- **Pomofocus**: https://pomofocus.io
- **Pomodoro Technique**: https://francescocirillo.com/pages/pomodoro-technique
- **fl_chart Docs**: https://pub.dev/packages/fl_chart
- **audioplayers Docs**: https://pub.dev/packages/audioplayers

---

**Última actualización:** 24 de Octubre, 2025  
**Versión del documento:** 1.0  
**Estado del proyecto:** En desarrollo activo 🚀
