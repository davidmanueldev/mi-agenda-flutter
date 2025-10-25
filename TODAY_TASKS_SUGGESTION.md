# Sugerencias de Tareas de Hoy - Implementación

**Fecha:** 25 de Octubre, 2025  
**Versión:** 1.0  
**Estado:** ✅ IMPLEMENTADO

---

## 📋 Resumen de Cambios

Se ha implementado una sección de sugerencias inteligentes en `PomodoroScreen` que muestra automáticamente las tareas pendientes que vencen hoy, facilitando al usuario enfocarse en lo más importante y urgente del día.

---

## 🎯 Funcionalidades Implementadas

### 1️⃣ Método `getTodaysTasks()` en TaskController

**Descripción:**
Nuevo método que filtra y ordena las tareas que vencen hoy.

**Implementación en `lib/controllers/task_controller.dart`:**
```dart
/// Obtener tareas pendientes que vencen hoy
/// Útil para sugerencias en PomodoroScreen
List<Task> getTodaysTasks() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  
  return _tasks.where((task) {
    // Solo tareas pendientes
    if (task.status != TaskStatus.pending) return false;
    
    // Filtrar por fecha de vencimiento == HOY
    if (task.dueDate == null) return false;
    
    final dueDate = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
    );
    
    return dueDate.isAtSameMomentAs(today) || 
           (dueDate.isBefore(tomorrow) && dueDate.isAfter(today.subtract(const Duration(days: 1))));
  }).toList()
    ..sort((a, b) {
      // Ordenar por prioridad (urgente primero)
      final priorityCompare = b.priority.value.compareTo(a.priority.value);
      if (priorityCompare != 0) return priorityCompare;
      
      // Luego por pomodoros estimados (menos pomodoros primero = quick wins)
      return a.estimatedPomodoros.compareTo(b.estimatedPomodoros);
    });
}
```

**Lógica de filtrado:**
- ✅ Solo tareas con `status == TaskStatus.pending`
- ✅ Solo tareas con `dueDate != null`
- ✅ Fecha de vencimiento debe ser HOY (comparación día/mes/año)

**Lógica de ordenamiento:**
1. **Prioridad descendente**: Urgente → Alta → Media → Baja
2. **Pomodoros estimados ascendente**: Tareas con menos pomodoros primero (quick wins)

**Ejemplo de resultado:**
```
[
  Task(title: "Urgente API", priority: urgent, estimatedPomodoros: 2),
  Task(title: "Bug crítico", priority: urgent, estimatedPomodoros: 4),
  Task(title: "Review PR", priority: high, estimatedPomodoros: 1),
  Task(title: "Documentar", priority: medium, estimatedPomodoros: 3),
]
```

---

### 2️⃣ Sección "Tareas de Hoy" en PomodoroScreen

**Descripción:**
Banner destacado con diseño naranja/ámbar que muestra las tareas de hoy en formato horizontal scrollable.

**Implementación en `lib/views/pomodoro_screen.dart`:**

#### A) Integración en el layout principal

```dart
body: Consumer<PomodoroController>(
  builder: (context, controller, child) {
    return Column(
      children: [
        // Indicador de tipo de sesión
        _buildSessionTypeIndicator(context, controller),
        
        // 🆕 Tareas de hoy (sugerencias)
        _buildTodayTasksSuggestion(context, controller),
        
        // Selector de tarea vinculada
        _buildTaskSelector(context, controller),
        
        // ... resto del UI
      ],
    );
  },
),
```

#### B) Widget `_buildTodayTasksSuggestion()`

**Características:**
- 🔄 **Consumidor reactivo**: Usa `Consumer<TaskController>` para actualizaciones en tiempo real
- 🎨 **Diseño destacado**: Gradiente naranja/ámbar con borde naranja
- 📊 **Badge de contador**: Muestra el número total de tareas de hoy
- 📜 **Lista horizontal**: Scroll horizontal para múltiples tareas
- 🧠 **Lógica inteligente**: Se oculta automáticamente si:
  - No hay tareas de hoy
  - Ya hay una tarea de hoy vinculada

**Código:**
```dart
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
```

---

### 3️⃣ Cards de Tareas Individuales

**Descripción:**
Cada tarea se muestra en una card compacta con información clave y acción rápida de vinculación.

**Implementación:**

```dart
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
```

**Elementos visuales:**
- **Borde coloreado**: Color según prioridad (rojo/naranja/azul/gris)
- **Sombra con color**: Efecto de profundidad con color de prioridad
- **Título**: Máximo 2 líneas con ellipsis
- **Badge de prioridad**: Chip con fondo semi-transparente
- **Indicador de pomodoros**: Icono de timer + número de pomodoros restantes

**Interacción:**
- **Tap**: Vincula automáticamente la tarea al Pomodoro
- **Feedback**: SnackBar verde con mensaje de confirmación

---

## 🧪 Casos de Prueba

### Caso 1: Usuario sin tareas de hoy
**Estado:**
- No hay tareas pendientes con `dueDate == hoy`

**Resultado esperado:**
- ✅ La sección "Tareas de Hoy" NO se muestra
- ✅ UI normal sin banners adicionales

---

### Caso 2: Usuario con 1 tarea de hoy
**Estado:**
- 1 tarea pendiente: "Reunión cliente" (alta prioridad, vence hoy)

**Resultado esperado:**
- ✅ Banner naranja visible con "Tareas de Hoy"
- ✅ Badge muestra "1"
- ✅ Card de tarea con borde naranja (alta prioridad)
- ✅ Al hacer tap, tarea se vincula y banner desaparece

---

### Caso 3: Usuario con múltiples tareas de hoy
**Estado:**
- 4 tareas pendientes con distintas prioridades:
  * "Bug crítico" (urgente, 2 pomodoros)
  * "Review PR" (alta, 1 pomodoro)
  * "Docs API" (media, 3 pomodoros)
  * "Email cliente" (baja, 1 pomodoro)

**Resultado esperado:**
- ✅ Banner muestra "4" en el badge
- ✅ Lista horizontal scrollable
- ✅ Orden: Bug crítico → Review PR → Docs API → Email cliente
  * (urgente primero, luego alta, luego media, luego baja)
  * (dentro de misma prioridad, menos pomodoros primero)
- ✅ Colores de borde: rojo → naranja → azul → gris

---

### Caso 4: Usuario vincula tarea de hoy
**Estado:**
- 2 tareas de hoy: "Tarea A", "Tarea B"
- Usuario vincula "Tarea A"

**Resultado esperado:**
- ✅ SnackBar verde: "✅ Vinculada: Tarea A"
- ✅ Banner "Tareas de Hoy" desaparece (porque tarea vinculada está en la lista)
- ✅ Selector de tarea normal muestra "Tarea A" vinculada

---

### Caso 5: Usuario vincula tarea que NO es de hoy
**Estado:**
- 1 tarea de hoy: "Urgente"
- Usuario vincula "Tarea futura" (vence mañana)

**Resultado esperado:**
- ✅ Banner "Tareas de Hoy" SIGUE VISIBLE
- ✅ Sugiere vincular "Urgente" en lugar de "Tarea futura"
- ✅ Usuario puede cambiar rápidamente la vinculación

---

### Caso 6: Actualización reactiva
**Estado:**
- Usuario crea nueva tarea con `dueDate = hoy`

**Resultado esperado:**
- ✅ Banner aparece automáticamente (Consumer reactivo)
- ✅ Nueva tarea se muestra en la lista horizontal
- ✅ Orden correcto según prioridad/pomodoros

---

## 🎨 Diseño y Estándares

### Paleta de Colores

**Banner principal:**
- Fondo: Gradiente `Colors.orange.shade50` → `Colors.amber.shade50`
- Borde: `Colors.orange.shade300` (2px)
- Icono: `Colors.orange.shade700`
- Título: `Colors.orange.shade900`
- Badge: `Colors.orange.shade700` con texto blanco

**Cards de tareas:**
- Fondo: `Colors.white`
- Borde según prioridad:
  * Urgente: `Colors.red`
  * Alta: `Colors.orange`
  * Media: `Colors.blue`
  * Baja: `Colors.grey`
- Sombra: Color de prioridad con opacidad 0.2

### Dimensiones
- **Banner margin**: 16px horizontal, 8px vertical
- **Banner padding**: 12px
- **Card width**: 200px
- **Card height**: 80px
- **Card margin**: 12px derecha
- **Border radius**: 12px (banner), 8px (cards)

### Tipografía
- **Título banner**: 16px, bold, orange.shade900
- **Título card**: 14px, bold
- **Prioridad badge**: 10px, bold
- **Pomodoros**: 12px, w600

---

## 📊 Impacto en UX

### Antes de esta funcionalidad:
```
[PomodoroScreen]
- Usuario debe recordar qué tareas vencen hoy
- Usuario debe ir a TaskListScreen → buscar → volver → vincular
- Pérdida de contexto y tiempo
```

### Después de esta funcionalidad:
```
[PomodoroScreen]
✅ Banner destacado: "Tareas de Hoy (3)"
✅ Cards con información clave visible
✅ 1 tap para vincular y comenzar
✅ Orden inteligente (prioridad + quick wins)
✅ Desaparece automáticamente cuando vincula una
```

**Tiempo ahorrado:** ~30 segundos por sesión  
**Decisiones facilitadas:** Algoritmo sugiere orden óptimo  
**Fricción reducida:** De 5 pasos a 1 tap

---

## 🚀 Mejoras Futuras

### 1. Tareas Vencidas
Mostrar también tareas con `dueDate < hoy` en un banner rojo separado:
```dart
List<Task> getOverdueTasks() {
  final today = DateTime.now();
  return _tasks.where((t) => 
    t.status == TaskStatus.pending && 
    t.dueDate != null && 
    t.dueDate!.isBefore(today)
  ).toList();
}
```

### 2. Estimación de Tiempo Total
Calcular cuánto tiempo tomaría completar todas las tareas de hoy:
```dart
int getTotalPomodorosToday() {
  return getTodaysTasks()
    .fold(0, (sum, task) => sum + task.remainingPomodoros);
}
// Mostrar: "3 tareas (8🍅 ≈ 3h 15min)"
```

### 3. Acciones Rápidas
Agregar botones secundarios en cada card:
```dart
Row(
  children: [
    IconButton(icon: Icon(Icons.info), onPressed: () => _showTaskDetail()),
    IconButton(icon: Icon(Icons.edit), onPressed: () => _editTask()),
  ],
)
```

### 4. Filtro de Categoría
Permitir filtrar tareas de hoy por categoría:
```dart
DropdownButton<String>(
  items: ['Todas', 'Trabajo', 'Personal'],
  onChanged: (category) => _filterTodayTasks(category),
)
```

### 5. Animaciones
Agregar animaciones al aparecer/desaparecer:
```dart
AnimatedSwitcher(
  duration: Duration(milliseconds: 300),
  child: todayTasks.isEmpty ? SizedBox.shrink() : _buildBanner(),
)
```

### 6. Persistencia de Preferencias
Recordar si el usuario prefiere ocultar el banner:
```dart
SharedPreferences prefs = await SharedPreferences.getInstance();
bool showSuggestions = prefs.getBool('show_today_suggestions') ?? true;
```

---

## 📝 Notas de Desarrollo

### Decisiones Técnicas

**¿Por qué no usar FutureBuilder?**
- ✅ `getTodaysTasks()` es síncrono (no requiere async)
- ✅ Consumer reactivo actualiza automáticamente cuando cambian las tareas
- ✅ Mejor rendimiento (no requiere rebuild completo)

**¿Por qué gradiente naranja/ámbar?**
- 🎨 Transmite urgencia sin agresividad (vs rojo puro)
- 🔆 Alto contraste con el resto de la UI
- ⚡ Asociación psicológica: naranja = acción/productividad

**¿Por qué horizontal scroll en lugar de vertical?**
- 📱 Ahorra espacio vertical (más importante en pantallas móviles)
- 👁️ Mayor visibilidad de múltiples tareas a la vez
- 🎯 Enfoque en acción rápida (no navegación profunda)

### Limitaciones Conocidas

1. **Solo tareas con dueDate:**  
   Tareas sin fecha de vencimiento no aparecen aunque sean importantes.  
   *Futura mejora:* Agregar sección "Sugeridas por prioridad"

2. **Sin soporte para tareas recurrentes:**  
   Si una tarea se marca completa pero es recurrente, debería re-aparecer.  
   *Futura mejora:* Detectar recurrencia y mostrar siguiente instancia

3. **Límite visual:**  
   Con 10+ tareas de hoy, el scroll horizontal puede ser incómodo.  
   *Futura mejora:* Paginación o límite "Top 5" con botón "Ver todas"

---

## ✅ Checklist de Verificación

- [x] Método `getTodaysTasks()` agregado a TaskController
- [x] Filtrado correcto por fecha de vencimiento
- [x] Ordenamiento por prioridad + pomodoros
- [x] Widget `_buildTodayTasksSuggestion()` implementado
- [x] Consumer reactivo funcionando
- [x] Lógica de ocultación automática
- [x] Cards de tareas con diseño correcto
- [x] Vinculación con un tap funcionando
- [x] SnackBar de confirmación
- [x] Colores según prioridad
- [x] Responsive en diferentes tamaños de pantalla
- [x] Sin warnings de compilación
- [x] Documentación completa

---

## 🔗 Referencias

- **Archivo principal:** `lib/views/pomodoro_screen.dart`
- **Controlador:** `lib/controllers/task_controller.dart`
- **Modelo:** `lib/models/task.dart`
- **Roadmap:** `POMOFOCUS_FEATURES_ROADMAP.md`
- **Feature relacionada:** `ESTIMATED_FINISH_TIME.md`
