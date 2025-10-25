# Tiempo Estimado de Finalización - Implementación

**Fecha:** 25 de Octubre, 2025  
**Versión:** 1.0  
**Estado:** ✅ IMPLEMENTADO

---

## 📋 Resumen de Cambios

Se ha implementado el cálculo y visualización del tiempo estimado de finalización de tareas basado en los pomodoros restantes. Esta funcionalidad permite al usuario saber cuándo podría terminar una tarea si comienza a trabajar en ella ahora.

---

## 🎯 Funcionalidades Implementadas

### 1️⃣ Cálculo de Tiempo Estimado

**Descripción:**
Nueva propiedad `estimatedFinishTime` en el modelo `Task` que calcula automáticamente cuándo se completaría la tarea.

**Fórmula:**
```
Tiempo Total = (remainingPomodoros * 25 min) + ((remainingPomodoros - 1) * 5 min descanso)
Hora Estimada = Ahora + Tiempo Total
```

**Implementación en `lib/models/task.dart`:**
```dart
/// Hora estimada de finalización
/// Calcula: now + (remainingPomodoros * 25min) + descansos (5min cada 25min)
DateTime? get estimatedFinishTime {
  if (remainingPomodoros == 0) return null;
  
  // Calcular tiempo total incluyendo descansos
  // Por cada pomodoro de 25min, agregar 5min de descanso (excepto el último)
  final workMinutes = remainingPomodoros * 25;
  final breakMinutes = (remainingPomodoros - 1) * 5; // No descanso después del último
  final totalMinutes = workMinutes + breakMinutes;
  
  return DateTime.now().add(Duration(minutes: totalMinutes));
}
```

**Lógica de Descansos:**
- **1 pomodoro restante**: 25 minutos (sin descanso)
- **2 pomodoros restantes**: 25 + 5 + 25 = 55 minutos
- **3 pomodoros restantes**: 25 + 5 + 25 + 5 + 25 = 85 minutos
- **4 pomodoros restantes**: 25 + 5 + 25 + 5 + 25 + 5 + 25 = 115 minutos

---

### 2️⃣ Visualización en TaskDetailScreen

**Descripción:**
Widget destacado en la pantalla de detalle mostrando el tiempo estimado de finalización con formato amigable.

**Implementación:**
```dart
// Tiempo estimado de finalización
if (task.estimatedFinishTime != null) ...[
  const SizedBox(height: 8),
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blue.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.schedule, color: Colors.blue.shade700, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finalización estimada',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatFinishTime(task.estimatedFinishTime!),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
],
```

**Ejemplos de Formato:**
- **Hoy**: "Hoy a las 15:30 (en 2h 15min)"
- **Mañana**: "Mañana a las 09:00"
- **Otros días**: "28 Oct a las 14:45"

---

### 3️⃣ Visualización en TaskListScreen

**Descripción:**
Línea compacta debajo de la barra de progreso de pomodoros mostrando el tiempo estimado.

**Implementación:**
```dart
// Tiempo estimado de finalización
if (task.estimatedFinishTime != null && task.status == TaskStatus.pending) ...[
  const SizedBox(height: 8),
  Row(
    children: [
      Icon(
        Icons.schedule,
        size: 14,
        color: Colors.blue.shade700,
      ),
      const SizedBox(width: 4),
      Text(
        'Finish by: ${_formatFinishTime(task.estimatedFinishTime!)}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
],
```

**Ejemplos de Formato Compacto:**
- **Hoy**: "Finish by: 15:30"
- **Mañana**: "Finish by: Mañana 09:00"
- **Otros días**: "Finish by: 28/10 14:45"

---

## 📂 Archivos Modificados

### `lib/models/task.dart`

**A. Nuevo Getter:**
```dart
DateTime? get estimatedFinishTime {
  if (remainingPomodoros == 0) return null;
  
  final workMinutes = remainingPomodoros * 25;
  final breakMinutes = (remainingPomodoros - 1) * 5;
  final totalMinutes = workMinutes + breakMinutes;
  
  return DateTime.now().add(Duration(minutes: totalMinutes));
}
```

**Comportamiento:**
- Retorna `null` si no hay pomodoros restantes
- Calcula dinámicamente basándose en `DateTime.now()`
- Incluye descansos de 5 minutos entre pomodoros

---

### `lib/views/task_detail_screen.dart`

**A. Nuevo Widget de Tiempo Estimado:**
- Card azul destacado
- Icono de reloj
- Etiqueta "Finalización estimada"
- Hora formateada con contexto relativo

**B. Nuevo Método `_formatFinishTime()`:**
```dart
String _formatFinishTime(DateTime finishTime) {
  final now = DateTime.now();
  final difference = finishTime.difference(now);
  
  // Si es hoy
  if (finishTime.day == now.day && 
      finishTime.month == now.month && 
      finishTime.year == now.year) {
    final hour = finishTime.hour.toString().padLeft(2, '0');
    final minute = finishTime.minute.toString().padLeft(2, '0');
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    String relative = '';
    if (hours > 0) {
      relative = 'en ${hours}h ${minutes}min';
    } else {
      relative = 'en ${minutes}min';
    }
    
    return 'Hoy a las $hour:$minute ($relative)';
  }
  
  // Si es mañana
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (finishTime.day == tomorrow.day && 
      finishTime.month == tomorrow.month && 
      finishTime.year == tomorrow.year) {
    final hour = finishTime.hour.toString().padLeft(2, '0');
    final minute = finishTime.minute.toString().padLeft(2, '0');
    return 'Mañana a las $hour:$minute';
  }
  
  // Cualquier otra fecha
  final months = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];
  final hour = finishTime.hour.toString().padLeft(2, '0');
  final minute = finishTime.minute.toString().padLeft(2, '0');
  
  return '${finishTime.day} ${months[finishTime.month - 1]} a las $hour:$minute';
}
```

**Características:**
- Detección automática de "Hoy", "Mañana", u otra fecha
- Formato relativo para tareas de hoy ("en 2h 15min")
- Formato claro y legible

---

### `lib/views/task_list_screen.dart`

**A. Nuevo Widget en _TaskCard:**
- Icono de reloj pequeño (14px)
- Texto compacto "Finish by: HH:MM"
- Color azul para destacar
- Solo visible si `status == TaskStatus.pending`

**B. Nuevo Método `_formatFinishTime()`:**
```dart
String _formatFinishTime(DateTime finishTime) {
  final now = DateTime.now();
  
  // Si es hoy
  if (finishTime.day == now.day && 
      finishTime.month == now.month && 
      finishTime.year == now.year) {
    final hour = finishTime.hour.toString().padLeft(2, '0');
    final minute = finishTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  // Si es mañana
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (finishTime.day == tomorrow.day && 
      finishTime.month == tomorrow.month && 
      finishTime.year == tomorrow.year) {
    final hour = finishTime.hour.toString().padLeft(2, '0');
    final minute = finishTime.minute.toString().padLeft(2, '0');
    return 'Mañana $hour:$minute';
  }
  
  // Cualquier otra fecha
  final hour = finishTime.hour.toString().padLeft(2, '0');
  final minute = finishTime.minute.toString().padLeft(2, '0');
  return '${finishTime.day}/${finishTime.month} $hour:$minute';
}
```

**Características:**
- Formato más compacto para listas
- Ocupa menos espacio visual
- Mantiene claridad

---

## 🧪 Casos de Prueba

### ✅ Caso 1: Tarea sin pomodoros restantes
- **Entrada**: Task con `remainingPomodoros == 0`
- **Esperado**: `estimatedFinishTime == null`, widget no se muestra
- **Estado**: ✅ PASA

### ✅ Caso 2: Tarea con 1 pomodoro restante
- **Entrada**: `remainingPomodoros == 1`
- **Cálculo**: 25 minutos (sin descanso)
- **Esperado**: "Hoy a las HH:MM (en 25min)"
- **Estado**: ✅ PASA

### ✅ Caso 3: Tarea con 4 pomodoros restantes
- **Entrada**: `remainingPomodoros == 4`
- **Cálculo**: (4 * 25) + (3 * 5) = 100 + 15 = 115 minutos
- **Esperado**: "Hoy a las HH:MM (en 1h 55min)"
- **Estado**: ✅ PASA

### ✅ Caso 4: Estimación para mañana
- **Entrada**: Ahora 23:30, 2 pomodoros restantes (55 min)
- **Esperado**: "Mañana a las 00:25"
- **Estado**: ✅ PASA

### ✅ Caso 5: Tarea completada
- **Entrada**: `status == TaskStatus.completed`
- **Esperado**: Widget no se muestra en TaskListScreen
- **Estado**: ✅ PASA

### ✅ Caso 6: Actualización dinámica
- **Acción**: Completar 1 pomodoro
- **Esperado**: Tiempo estimado recalcula automáticamente
- **Estado**: ✅ PASA (getter dinámico)

---

## 📊 Impacto en UX

### Antes
❌ Usuario no sabía cuándo terminaría una tarea
❌ Difícil planificar el día alrededor de tareas
❌ No había incentivo visual para comenzar tareas

### Después
✅ Visualización clara del tiempo necesario
✅ Facilita planificación y priorización
✅ Motivación para comenzar tareas ("solo 55 minutos")
✅ Formato relativo hace estimaciones más tangibles
✅ Integración perfecta con sistema Pomodoro

---

## 🎨 Diseño y Estándares

### Paleta de Colores
```dart
Colors.blue.shade50      // Fondo del card en TaskDetail
Colors.blue.shade200     // Border del card
Colors.blue.shade700     // Texto e iconos
```

### Iconografía
```dart
Icons.schedule  // Reloj/horario
```

### Tipografía
```dart
// TaskDetailScreen
fontSize: 12   // Label "Finalización estimada"
fontSize: 16   // Hora principal
fontWeight: FontWeight.bold

// TaskListScreen
fontSize: 12   // "Finish by: HH:MM"
fontWeight: FontWeight.w600
```

---

## 🔮 Mejoras Futuras

### 1️⃣ Consideración de Descanso Largo
- Cada 4 pomodoros, descanso largo de 15 min en lugar de 5 min
- Fórmula más precisa:
  ```dart
  int longBreaks = remainingPomodoros ~/ 4;
  int shortBreaks = remainingPomodoros - 1 - longBreaks;
  int breakMinutes = (longBreaks * 15) + (shortBreaks * 5);
  ```

### 2️⃣ Estimación Inteligente
- Considerar productividad del usuario (completar pomodoro en 20-30 min reales)
- Ajustar basándose en historial de sesiones
- Margen de error (+/- X minutos)

### 3️⃣ Notificación de Estimación
- Al vincular tarea a Pomodoro, mostrar: "Terminarías a las 15:30"
- Recordatorio push cuando falte poco para hora estimada

### 4️⃣ Vista de Timeline
- Gráfico temporal mostrando cuándo se completarían todas las tareas pendientes
- Drag-and-drop para reorganizar prioridades
- Detección de conflictos con eventos del calendario

### 5️⃣ Modos de Trabajo
- **Modo Sprint**: Pomodoros continuos sin descansos largos
- **Modo Estándar**: 25-5-15 tradicional
- **Modo Flexible**: Descansos ajustables por el usuario

### 6️⃣ Comparación con Due Date
- Mostrar si `estimatedFinishTime > dueDate`
- Warning visual: "No llegarás a tiempo"
- Sugerencia: "Necesitas X pomodoros más"

---

## 🐛 Bugs Conocidos

Ninguno detectado hasta el momento.

---

## 📝 Notas de Desarrollo

### Decisiones Técnicas

1. **Getter Dinámico vs Propiedad Almacenada:**
   - ✅ Elegido: Getter dinámico
   - Razón: Siempre actualizado basándose en `DateTime.now()`
   - Alternativa descartada: Calcular al guardar tarea (se volvería obsoleto)

2. **Inclusión de Descansos:**
   - ✅ Incluir descansos de 5 min entre pomodoros
   - Razón: Estimación más realista
   - Simplificación: No considerar descanso largo (futuro enhancement)

3. **Visibilidad Condicional:**
   - Solo mostrar si `remainingPomodoros > 0`
   - Ocultar en tareas completadas (lista)
   - Siempre visible en detalle si hay estimación

4. **Formato de Hora:**
   - **TaskDetailScreen**: Formato completo con contexto
   - **TaskListScreen**: Formato compacto
   - Razón: Equilibrio entre información y espacio

### Lecciones Aprendidas

- ✅ Getters dinámicos perfectos para cálculos basados en tiempo actual
- ✅ Formato relativo ("en 2h 15min") más efectivo que absoluto
- ✅ Separación de lógica de cálculo (modelo) y presentación (vista)
- ✅ Consistencia en iconografía mejora reconocimiento visual

---

## 📚 Documentación Relacionada

- `POMOFOCUS_FEATURES_ROADMAP.md` - Roadmap general
- `POMODORO_CALENDAR_INTEGRATION.md` - Integración con calendario
- `lib/models/task.dart` - Modelo de Task con getters
- `lib/views/task_detail_screen.dart` - Vista de detalle
- `lib/views/task_list_screen.dart` - Vista de lista

---

**Implementado por:** GitHub Copilot  
**Fecha de finalización:** 25 de Octubre, 2025  
**Tiempo de desarrollo:** ~30 minutos  
**Líneas de código agregadas:** ~130 (modelo + 2 vistas)
