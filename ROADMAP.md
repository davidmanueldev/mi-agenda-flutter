# 🗺️ Roadmap - Mi Agenda App

## 📌 Estado Actual
**Versión:** 0.5.0 (MVP Parcial)
**Completado:** ~40% del MVP

### ✅ Implementado
- Gestión completa de Eventos (CRUD)
- Calendario interactivo mensual
- Categorías con iconos y colores
- Arquitectura MVC + Provider
- Firebase + SQLite híbrido
- Notificaciones locales
- Tema claro/oscuro
- Autenticación Firebase

---

## 🚀 FASE 1A - Completar MVP Base (2-3 semanas)

### 1. Sistema de Tareas (PRIORITARIO)
**Archivos a crear:**
- `lib/models/task.dart` - Modelo de tarea
- `lib/controllers/task_controller.dart` - Controlador de tareas
- `lib/views/tasks_screen.dart` - Pantalla de tareas
- `lib/views/add_edit_task_screen.dart` - Formulario de tarea
- `lib/widgets/task_card.dart` - Widget de tarea

**Funcionalidades:**
- [ ] Modelo Task con: título, descripción, fecha vencimiento, categoría, prioridad (alta/media/baja), estado (pendiente/completada/archivada)
- [ ] CRUD completo de tareas
- [ ] Vista lista de tareas del día
- [ ] Vista lista de todas las tareas
- [ ] Marcar como completada con animación
- [ ] Filtros: por categoría, prioridad, estado
- [ ] Búsqueda de tareas
- [ ] Sincronización Firebase + SQLite

### 2. Temporizador Pomodoro
**Archivos a crear:**
- `lib/models/focus_session.dart` - Modelo de sesión de foco
- `lib/services/pomodoro_service.dart` - Servicio del temporizador
- `lib/views/pomodoro_screen.dart` - Pantalla del temporizador
- `lib/widgets/circular_timer.dart` - Widget visual del timer

**Funcionalidades:**
- [ ] Temporizador 25min trabajo + 5min pausa + 15min pausa larga
- [ ] Configuración personalizable (duraciones, ciclos)
- [ ] Vincular sesión a tarea específica
- [ ] Sonido/vibración al terminar
- [ ] Modo foco (pantalla limpia)
- [ ] Registro de sesiones completadas
- [ ] Pausar/reanudar/cancelar

### 3. Vistas Mejoradas
**Archivos a modificar/crear:**
- `lib/views/home_screen.dart` - Rediseñar home
- `lib/views/today_screen.dart` - Vista "Hoy"
- `lib/widgets/quick_add_button.dart` - FAB mejorado

**Funcionalidades:**
- [ ] Vista "Hoy": tareas + eventos del día
- [ ] Lista unificada: tareas pendientes ordenadas por prioridad
- [ ] Navegación por pestañas: Hoy | Calendario | Tareas | Foco | Estadísticas
- [ ] FAB con opciones: + Tarea | + Evento | 🕐 Iniciar Foco
- [ ] Drag-and-drop para reordenar prioridades

### 4. Notificaciones Mejoradas
**Archivos a modificar:**
- `lib/services/notification_service.dart`

**Funcionalidades:**
- [ ] Notificaciones de tareas vencidas
- [ ] Recordatorio diario de tareas pendientes
- [ ] Notificación al terminar sesión Pomodoro
- [ ] Canales separados: eventos | tareas | foco
- [ ] Acción rápida desde notificación (completar tarea)

---

## 🎨 FASE 1B - UX y Estadísticas Básicas (1-2 semanas)

### 5. Dashboard de Productividad
**Archivos a crear:**
- `lib/views/stats_screen.dart`
- `lib/widgets/stats_chart.dart`
- `lib/services/analytics_service.dart`

**Funcionalidades:**
- [ ] Tareas completadas hoy/semana/mes
- [ ] Sesiones de foco completadas
- [ ] Tiempo total de foco por categoría
- [ ] Gráfico de tendencias (barras/líneas)
- [ ] Tarjetas de resumen

### 6. Mejoras UX
- [ ] Animaciones suaves (completar tarea, transiciones)
- [ ] Gestos: deslizar para completar/eliminar
- [ ] Feedback visual inmediato
- [ ] Modo offline con indicador visual
- [ ] Onboarding inicial (primera vez)
- [ ] Mejora de formularios (validación visual)

---

## 🔄 FASE 2 - Funcionalidades Avanzadas (3-4 semanas)

### 7. Sub-tareas y Checklists
- [ ] Modelo subtask
- [ ] UI para agregar/editar subtareas
- [ ] Progreso visual (3/5 completadas)

### 8. Vista Kanban/Tablero
- [ ] Pantalla tablero con columnas
- [ ] Drag-and-drop entre estados
- [ ] Agrupación por categoría o proyecto

### 9. Proyectos
- [ ] Modelo Project
- [ ] Agrupar tareas bajo proyectos
- [ ] Vista de proyecto con tareas

### 10. Etiquetas/Tags
- [ ] Sistema de tags multi-selección
- [ ] Filtrado por tags
- [ ] Colores de tags

### 11. Repetición de Tareas/Eventos
- [ ] Patrón de repetición (diario, semanal, mensual, personalizado)
- [ ] Generación automática de instancias
- [ ] Editar serie vs instancia individual

### 12. Exportación de Datos
- [ ] Exportar a CSV/JSON
- [ ] Backup manual
- [ ] Importar datos

---

## 🌟 FASE 3 - Funcionalidades Premium (Futuro)

### 13. Colaboración
- [ ] Compartir listas con otros usuarios
- [ ] Asignación de tareas
- [ ] Comentarios en tareas

### 14. Integraciones
- [ ] Calendario del sistema (import/export)
- [ ] Recordatorios por ubicación
- [ ] Widget de home

### 15. Gamification
- [ ] Sistema de logros
- [ ] Racha de productividad
- [ ] Recompensas visuales

### 16. Hábitos
- [ ] Módulo separado de hábitos
- [ ] Seguimiento diario
- [ ] Estadísticas de consistencia

### 17. Personalización Avanzada
- [ ] Temas personalizados
- [ ] Vista Eisenhower Matrix
- [ ] Configuración avanzada de categorías

---

## 📅 Timeline Estimado

| Fase | Duración | Objetivo |
|------|----------|----------|
| **1A - Completar MVP** | 2-3 semanas | Tareas + Pomodoro + Vistas |
| **1B - UX/Stats** | 1-2 semanas | Dashboard + Animaciones |
| **2 - Avanzadas** | 3-4 semanas | Subtareas + Kanban + Proyectos |
| **3 - Premium** | Variable | Colaboración + Gamification |

**Total MVP Completo:** 3-5 semanas
**App Completa Fase 2:** 6-9 semanas

---

## 🎯 Próximos Pasos Inmediatos

### Esta Sesión (Ahora):
1. ✅ Crear modelo Task
2. ✅ Crear TaskController
3. ✅ Pantalla básica de lista de tareas
4. ✅ Formulario agregar/editar tarea
5. ✅ Sincronización con Firebase

### Siguiente Sesión:
1. Temporizador Pomodoro básico
2. Vista "Hoy" combinada
3. Mejoras de navegación

---

## 📝 Notas de Arquitectura

### Estructura de Carpetas Expandida:
```
lib/
├── controllers/
│   ├── event_controller.dart
│   ├── task_controller.dart        # NUEVO
│   └── pomodoro_controller.dart    # NUEVO
├── models/
│   ├── event.dart
│   ├── task.dart                   # NUEVO
│   ├── focus_session.dart          # NUEVO
│   ├── project.dart                # FUTURO
│   └── category.dart
├── services/
│   ├── database_interface.dart
│   ├── firebase_service.dart
│   ├── database_service.dart
│   ├── database_service_hybrid.dart
│   ├── notification_service.dart
│   ├── pomodoro_service.dart       # NUEVO
│   └── analytics_service.dart      # NUEVO
├── views/
│   ├── home_screen.dart
│   ├── today_screen.dart           # NUEVO
│   ├── tasks_screen.dart           # NUEVO
│   ├── add_edit_task_screen.dart   # NUEVO
│   ├── pomodoro_screen.dart        # NUEVO
│   ├── stats_screen.dart           # NUEVO
│   ├── add_edit_event_screen.dart
│   └── event_detail_screen.dart
└── widgets/
    ├── task_card.dart              # NUEVO
    ├── circular_timer.dart         # NUEVO
    ├── quick_add_button.dart       # NUEVO
    ├── event_card.dart
    └── custom_app_bar.dart
```

---

## 🔧 Dependencias Adicionales Necesarias

```yaml
# Ya tenemos:
# provider, firebase_core, cloud_firestore, firebase_auth, 
# sqflite, flutter_local_notifications, table_calendar

# A agregar:
dependencies:
  # Para gráficos y estadísticas
  fl_chart: ^0.66.0
  
  # Para drag & drop en Kanban
  flutter_reorderable_list: ^1.3.1
  
  # Para exportación
  csv: ^5.1.1
  path_provider: ^2.1.1
  
  # Para animaciones avanzadas
  lottie: ^2.7.0
  
  # Para tags/chips
  flutter_tags_x: ^1.1.0
```

---

**Última actualización:** 2025-10-22
**Siguiente revisión:** Cada fin de sprint (2 semanas)
