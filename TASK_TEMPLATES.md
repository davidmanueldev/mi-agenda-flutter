# Task Templates - Implementación Completa

**Fecha:** 25 de Octubre, 2025  
**Versión:** 1.0  
**Estado:** ✅ COMPLETADO (90%)

---

## 📋 Resumen de Cambios

Se ha implementado un sistema completo de plantillas de tareas que permite guardar configuraciones de tareas frecuentes para reutilización rápida. Esta funcionalidad mejora significativamente la productividad al eliminar la necesidad de configurar manualmente tareas repetitivas.

---

## 🎯 Funcionalidades Implementadas

### 1️⃣ Modelo TaskTemplate

**Descripción:**
Modelo de datos que almacena la configuración completa de una tarea para reutilización.

**Archivo:** `lib/models/task_template.dart`

**Campos:**
```dart
class TaskTemplate {
  final String id;              // ID único
  final String userId;          // Usuario propietario
  final String name;            // Nombre de la plantilla (ej: "Reunión Semanal")
  final String title;           // Título de tarea a crear
  final String description;     // Descripción
  final String category;        // Categoría
  final TaskPriority priority;  // Prioridad
  final int estimatedPomodoros; // Estimación de pomodoros
  final List<String> steps;     // Lista de títulos de pasos
  final DateTime createdAt;     // Fecha de creación
  final DateTime updatedAt;     // Última actualización
}
```

**Características:**
- ✅ Serialización dual: `toMap()`/`fromMap()` para SQLite, `toJson()`/`fromJson()` para Firebase
- ✅ Método `copyWith()` para actualizaciones inmutables
- ✅ Steps almacenados como lista de strings (sin IDs ni estado)
- ✅ Validación y sanitización de entrada

---

### 2️⃣ Database Schema v6

**Descripción:**
Nueva tabla `task_templates` en SQLite con migración automática desde v5.

**Archivo:** `lib/services/database_service.dart`

**Esquema:**
```sql
CREATE TABLE task_templates (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  priority TEXT NOT NULL,
  estimated_pomodoros INTEGER NOT NULL DEFAULT 1,
  steps TEXT,  -- JSON encoded List<String>
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_templates_userId ON task_templates(user_id);
```

**Migración:**
```dart
// Actualización automática de v5 a v6
if (oldVersion < 6) {
  await db.execute('CREATE TABLE task_templates...');
  await db.execute('CREATE INDEX idx_templates_userId...');
}
```

**Métodos CRUD:**
- `insertTaskTemplate(TaskTemplate)` - Crear nueva plantilla
- `updateTaskTemplate(TaskTemplate)` - Actualizar existente
- `deleteTaskTemplate(String id)` - Eliminar por ID
- `getAllTaskTemplates()` - Obtener todas (ordenadas por fecha)
- `getTaskTemplateById(String id)` - Obtener una específica

---

### 3️⃣ Firebase Integration

**Descripción:**
Sincronización en tiempo real con Firestore para compartir plantillas entre dispositivos.

**Archivo:** `lib/services/firebase_service.dart`

**Colección:** `task_templates`

**Métodos:**
```dart
// CRUD Operations
Future<void> createTaskTemplate(TaskTemplate)
Future<void> updateTaskTemplate(TaskTemplate)
Future<void> deleteTaskTemplate(String id)
Future<List<TaskTemplate>> getAllTaskTemplates()
Future<TaskTemplate?> getTaskTemplateById(String id)

// Real-time Stream
Stream<List<TaskTemplate>> getTaskTemplatesStream()
```

**Estructura de documento:**
```json
{
  "id": "template_abc123",
  "userId": "user_xyz",
  "name": "Reunión Semanal",
  "title": "Reunión de Equipo",
  "description": "Revisar progreso semanal",
  "category": "Trabajo",
  "priority": "high",
  "estimatedPomodoros": 2,
  "steps": ["Preparar agenda", "Revisar métricas", "Discutir blockers"],
  "createdAt": Timestamp(2025, 10, 25, 14, 30),
  "updatedAt": Timestamp(2025, 10, 25, 14, 30)
}
```

---

### 4️⃣ TemplateController

**Descripción:**
Controlador MVC con patrón Provider para gestión de estado de plantillas.

**Archivo:** `lib/controllers/template_controller.dart`

**Métodos públicos:**
```dart
// Getters
List<TaskTemplate> get templates
bool get isLoading
String? get errorMessage

// CRUD
Future<bool> createTemplate(TaskTemplate)
Future<bool> updateTemplate(TaskTemplate)
Future<bool> deleteTemplate(String id)
Future<TaskTemplate?> getTemplateById(String id)

// Utility
Future<void> refresh()
```

**Integración con HybridV2:**
- Registra callback `onDataChanged` para sincronización reactiva
- Notifica a listeners cuando datos cambian desde Firebase
- Ordena plantillas por fecha de creación (más recientes primero)

**Registro en main.dart:**
```dart
ChangeNotifierProvider(
  create: (context) => TemplateController(
    databaseService: DatabaseServiceHybridV2(),
  ),
),
```

---

### 5️⃣ TemplatesScreen

**Descripción:**
Pantalla de gestión de plantillas con UI moderna y funcional.

**Archivo:** `lib/views/templates_screen.dart`

**Componentes principales:**

#### A) Vista de Grid
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 0.85,
  ),
)
```

#### B) Template Card
Cada card muestra:
- **Header:** Nombre de plantilla + menú de acciones (editar/eliminar)
- **Body:** Título de tarea, categoría (chip)
- **Footer:** Badge de prioridad, contador de pomodoros 🍅

**Interacciones:**
- **Tap en card**: Crea tarea automáticamente desde la plantilla
- **Menú → Editar**: Abre diálogo de edición
- **Menú → Eliminar**: Muestra confirmación

#### C) Template Dialog
Formulario para crear/editar plantillas con:
- Nombre de plantilla (requerido)
- Título de tarea (requerido)
- Descripción (opcional)
- Categoría (dropdown)
- Prioridad (dropdown)
- Pomodoros estimados (contador +/-)
- Lista de pasos (agregar/eliminar)

**Validación:**
- Nombre y título requeridos
- Sanitización de inputs con `SecurityUtils.sanitizeInput()`
- Feedback visual de errores

#### D) Estados
- **Loading:** Spinner centrado
- **Error:** Mensaje + botón de reintentar
- **Empty:** Ilustración + mensaje motivacional + botón "Crear Plantilla"
- **Populated:** Grid de templates con pull-to-refresh

---

### 6️⃣ Sincronización Bidireccional

**Descripción:**
Integración completa en `DatabaseServiceHybridV2` para sync offline-online.

**Archivo:** `lib/services/database_service_hybrid_v2.dart`

**Flujo de datos:**

**CREATE:**
```
1. insertTaskTemplate(template)
2. → SQLite (local, inmediato)
3. → Online? Firebase.createTaskTemplate()
4. → Offline? SyncQueue.add(createTask)
```

**UPDATE:**
```
1. updateTaskTemplate(template)
2. → SQLite (local, inmediato)
3. → Online? Firebase.updateTaskTemplate()
4. → Offline? SyncQueue.add(updateTask)
```

**DELETE:**
```
1. deleteTaskTemplate(id)
2. → SQLite (local, inmediato)
3. → Online? Firebase.deleteTaskTemplate()
4. → Offline? SyncQueue.add(deleteTask)
```

**SYNC (cuando se reconecta):**
```
1. ConnectivityService detecta conexión
2. DatabaseServiceHybridV2.syncAll()
3. → Procesa SyncQueue (templates pendientes)
4. → Firebase listener actualiza cambios remotos
5. → SQLite se actualiza con datos de Firebase
6. → TemplateController.refresh() notifica UI
```

---

### 7️⃣ Integración con TaskDetailScreen

**Descripción:**
Botón para guardar tarea actual como plantilla.

**Archivo:** `lib/views/task_detail_screen.dart`

**Botón en AppBar:**
```dart
IconButton(
  icon: const Icon(Icons.save_alt),
  tooltip: 'Guardar como Plantilla',
  onPressed: () => _saveAsTemplate(context),
)
```

**Diálogo de Guardado:**
- Input para nombre de plantilla
- Preview de configuración que se guardará
- Botón "Guardar" que:
  * Extrae campos de la tarea (title, description, category, priority, pomodoros)
  * Convierte `steps` (TaskStep) a lista de strings (solo títulos)
  * Crea `TaskTemplate` con `SecurityUtils.generateSecureId()`
  * Llama a `TemplateController.createTemplate()`
  * Muestra SnackBar de confirmación

**Uso:**
```
Usuario → TaskDetailScreen (tarea existente)
  → Tap "Guardar como Plantilla"
    → Diálogo: Ingresar nombre
      → Tap "Guardar"
        → TemplateController.createTemplate()
          → DatabaseServiceHybridV2 (SQLite + Firebase)
            → SnackBar: "Plantilla creada ✅"
```

---

### 8️⃣ Navegación desde TaskListScreen

**Descripción:**
Acceso rápido a pantalla de plantillas desde lista de tareas.

**Archivo:** `lib/views/task_list_screen.dart`

**Botón en AppBar:**
```dart
IconButton(
  icon: const Icon(Icons.insert_drive_file_outlined),
  tooltip: 'Plantillas',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TemplatesScreen(),
      ),
    );
  },
)
```

**Ubicación:** Entre título "Mis Tareas" y botón de filtros

---

## 📊 Estadísticas de Implementación

### Archivos Modificados/Creados
| Archivo | Tipo | Líneas | Descripción |
|---------|------|--------|-------------|
| `task_template.dart` | CREADO | 185 | Modelo con serialización dual |
| `template_controller.dart` | CREADO | 145 | Controlador Provider |
| `templates_screen.dart` | CREADO | 680 | UI completa (grid + dialogs) |
| `database_service.dart` | MODIFICADO | +95 | Schema v6 + CRUD |
| `firebase_service.dart` | MODIFICADO | +95 | Collection + CRUD + stream |
| `database_interface.dart` | MODIFICADO | +17 | 5 métodos abstractos |
| `database_service_hybrid_v2.dart` | MODIFICADO | +90 | Sync bidireccional |
| `main.dart` | MODIFICADO | +8 | Provider registration |
| `task_detail_screen.dart` | MODIFICADO | +115 | Save as template |
| `task_list_screen.dart` | MODIFICADO | +15 | Navegación |
| **TOTAL** | - | **1,445** | **10 archivos** |

### Cobertura de Funcionalidad
- ✅ Modelo: 100%
- ✅ Database (SQLite): 100%
- ✅ Database (Firebase): 100%
- ✅ Sync Bidireccional: 100%
- ✅ Controller: 100%
- ✅ UI (CRUD): 100%
- ✅ UI (Integración): 90%
- ⏳ UI (Create from Template): 0% **← PENDIENTE**
- ⏳ Documentación: 90%
- ⏳ Tests: 0%

---

## 🚀 Casos de Uso

### Caso 1: Crear Plantilla desde Tarea Existente

**Escenario:**
Usuario tiene una tarea "Reunión de Retrospectiva" que se repite cada sprint.

**Pasos:**
1. Abrir tarea en `TaskDetailScreen`
2. Tap botón "Guardar como Plantilla" (icono save_alt)
3. Ingresar nombre: "Retrospectiva Sprint"
4. Tap "Guardar"
5. Ver SnackBar: "Plantilla 'Retrospectiva Sprint' creada ✅"

**Resultado:**
- Plantilla guardada en SQLite y Firebase
- Disponible en `TemplatesScreen`
- Sincronizada con otros dispositivos

---

### Caso 2: Crear Tarea desde Plantilla

**Escenario:**
Usuario necesita crear tarea de reunión semanal.

**Pasos:**
1. Ir a `TaskListScreen`
2. Tap botón "Plantillas" (icono insert_drive_file)
3. Ver grid de plantillas
4. Tap en card "Reunión Semanal"
5. Ver SnackBar: "Tarea creada desde 'Reunión Semanal' ✅"
6. Automáticamente vuelve a `TaskListScreen`

**Resultado:**
- Nueva tarea creada con:
  * Título: "Reunión de Equipo"
  * Categoría: "Trabajo"
  * Prioridad: Alta
  * Pomodoros estimados: 2
  * Pasos: ["Preparar agenda", "Revisar métricas"]
- Usuario puede editarla si necesita ajustes

---

### Caso 3: Editar Plantilla

**Escenario:**
Usuario quiere actualizar pasos de plantilla existente.

**Pasos:**
1. Ir a `TemplatesScreen`
2. Tap menú (⋮) en card de plantilla
3. Seleccionar "Editar"
4. Modificar pasos en el diálogo
5. Tap "Guardar"

**Resultado:**
- Plantilla actualizada en SQLite
- Sincronizada con Firebase
- Cambios reflejados en otros dispositivos
- Tareas creadas anteriormente NO se modifican

---

### Caso 4: Trabajo Offline

**Escenario:**
Usuario sin conexión crea nueva plantilla.

**Flujo:**
1. Usuario crea plantilla "Tarea Urgente"
2. `DatabaseServiceHybridV2.insertTaskTemplate()` guarda en SQLite ✓
3. Detecta offline → Agrega a `SyncQueue`
4. Usuario ve plantilla en `TemplatesScreen` (lectura desde SQLite)
5. Más tarde, dispositivo se conecta
6. `DatabaseServiceHybridV2.syncAll()` procesa cola
7. Plantilla se sube a Firebase
8. Disponible en todos los dispositivos

**Ventaja:**
Experiencia fluida sin depender de conexión.

---

## 🔧 Detalles Técnicos

### Seguridad
- **Sanitización:** Todos los inputs pasan por `SecurityUtils.sanitizeInput()`
- **IDs seguros:** `SecurityUtils.generateSecureId()` para prevenir colisiones
- **Firebase Auth:** Templates filtrados por `userId` (privacidad)

### Performance
- **Índice SQLite:** `idx_templates_userId` para búsquedas rápidas
- **Carga lazy:** Templates se cargan solo al abrir `TemplatesScreen`
- **Optimización UI:** Grid view con `childAspectRatio` optimizado

### Mantenibilidad
- **Arquitectura MVC:** Separación clara de responsabilidades
- **Interface pattern:** `DatabaseInterface` permite fácil cambio de backend
- **Provider pattern:** Estado reactivo sin boilerplate
- **Código documentado:** Comentarios explicativos en métodos clave

---

## 🐛 Errores Conocidos

### 1. Unnecessary Cast Warnings ⚠️
**Archivo:** `template_controller.dart`, línea 31

```dart
(_database as DatabaseServiceHybridV2).onDataChanged = () { ... }
```

**Problema:** Dart lint marca el cast como innecesario pero es requerido para acceder a `onDataChanged`.

**Impacto:** Solo warning, no afecta funcionalidad.

**Fix propuesto:** Crear interface `DataChangeNotifier` o ignorar con `// ignore: unnecessary_cast`.

---

## ⏳ Pendientes

### 1. "Create from Template" en AddEditTaskScreen
**Prioridad:** Alta  
**Estimación:** 1 hora

**Descripción:**
Agregar opción en `AddEditTaskScreen` para seleccionar plantilla al crear nueva tarea.

**Implementación sugerida:**
```dart
// En AddEditTaskScreen
Widget _buildTemplateSelector() {
  return Consumer<TemplateController>(
    builder: (context, controller, child) {
      if (controller.templates.isEmpty) return const SizedBox.shrink();
      
      return DropdownButtonFormField<TaskTemplate>(
        decoration: const InputDecoration(
          labelText: 'Usar Plantilla',
          prefixIcon: Icon(Icons.insert_drive_file),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Ninguna')),
          ...controller.templates.map((t) => DropdownMenuItem(
            value: t,
            child: Text(t.name),
          )),
        ],
        onChanged: (template) {
          if (template != null) _applyTemplate(template);
        },
      );
    },
  );
}

void _applyTemplate(TaskTemplate template) {
  setState(() {
    _titleController.text = template.title;
    _descriptionController.text = template.description;
    _selectedCategory = template.category;
    _selectedPriority = template.priority;
    _estimatedPomodoros = template.estimatedPomodoros;
    _steps = template.steps.map((title) => TaskStep(
      id: SecurityUtils.generateSecureId(),
      title: title,
      isCompleted: false,
    )).toList();
  });
}
```

---

### 2. Tests Unitarios
**Prioridad:** Media  
**Estimación:** 3 horas

**Cobertura sugerida:**
- `TaskTemplate` serialization (toMap/fromMap/toJson/fromJson)
- `TemplateController` CRUD operations
- `DatabaseService` template methods
- `FirebaseService` template methods

---

### 3. Categorías Dinámicas en Dialog
**Prioridad:** Baja  
**Estimación:** 30 min

**Descripción:**
En `_TemplateDialog`, cargar categorías desde `CategoryController` en lugar de lista hardcodeada.

```dart
Consumer<CategoryController>(
  builder: (context, controller, child) {
    return DropdownButtonFormField<String>(
      items: controller.categories.map((cat) => 
        DropdownMenuItem(value: cat.name, child: Text(cat.name))
      ).toList(),
    );
  },
)
```

---

## 📚 Referencias

### Archivos Clave
- Modelo: `lib/models/task_template.dart`
- Controller: `lib/controllers/template_controller.dart`
- View: `lib/views/templates_screen.dart`
- Database: `lib/services/database_service.dart` (líneas 34, 124-146, 303-319, 1084-1163)
- Firebase: `lib/services/firebase_service.dart` (líneas 27, 836-930)
- Sync: `lib/services/database_service_hybrid_v2.dart` (líneas 1006-1090)

### Documentación Relacionada
- `POMOFOCUS_FEATURES_ROADMAP.md` - Feature #3
- `DOCUMENTO.md` - Arquitectura MVC
- `SINCRONIZACION_OFFLINE_ONLINE.md` - Sync bidireccional
- `FIREBASE_FINAL_SETUP.md` - Configuración Firebase

### Comandos Útiles
```bash
# Ver templates en Firestore
firebase firestore:get task_templates

# Resetear database (testing)
flutter run --dart-define=RESET_DB=true

# Ver logs de sync
flutter logs | grep "Template"
```

---

## ✅ Checklist de Verificación

- [x] Modelo TaskTemplate creado con dual serialization
- [x] Database schema v6 con migración automática
- [x] CRUD methods en DatabaseService
- [x] CRUD methods en FirebaseService
- [x] Real-time stream en FirebaseService
- [x] TemplateController con Provider pattern
- [x] TemplatesScreen con grid view
- [x] Create/Edit/Delete dialogs
- [x] Sincronización bidireccional en HybridV2
- [x] "Save as Template" en TaskDetailScreen
- [x] Navegación desde TaskListScreen
- [x] Provider registration en main.dart
- [x] Error handling en todas las operaciones
- [x] Loading/Error/Empty states en UI
- [x] Sanitización de inputs
- [x] Documentación completa
- [ ] "Create from Template" en AddEditTaskScreen
- [ ] Tests unitarios
- [ ] Tests de integración

---

**Última actualización:** 25 de Octubre, 2025 - 02:30 AM  
**Autor:** GitHub Copilot  
**Versión:** 1.0.0
