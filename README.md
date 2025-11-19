# Mi Agenda - Aplicación Flutter con Arquitectura MVC

Una aplicación completa de gestión personal y productividad desarrollada en Flutter, que integra agenda de eventos, gestión de tareas, temporizador Pomodoro, plantillas reutilizables y sistema de autenticación multi-usuario. Implementa arquitectura MVC con sincronización bidireccional Firebase + SQLite para funcionalidad offline-first.

## 📋 Estado del Proyecto

**Versión**: 0.1.0  
**Progreso MVP**: ~85% Completado  
**Estado**: En desarrollo activo  
**Última actualización**: Noviembre 18, 2025

### ✅ Funcionalidades Implementadas

#### 🔐 Sistema de Autenticación Multi-Usuario
- **Login/Registro**: Sistema completo con email/password
- **Recuperación de contraseña**: Reset por email con Firebase Auth
- **Gestión de perfil**: Edición de nombre, cambio de contraseña, eliminación de cuenta
- **Persistencia de sesión**: Auto-login en reinicios de app
- **Aislamiento de datos**: Cada usuario solo ve sus propios datos (events, tasks, categories, pomodoros, templates)
- **Pantalla de bienvenida**: SplashScreen animado con verificación de sesión

#### 📅 Gestión de Eventos
- **CRUD completo**: Crear, leer, actualizar y eliminar eventos
- **Calendario interactivo**: Vista mensual con navegación fluida (table_calendar)
- **Categorías personalizadas**: Organización con colores e iconos
- **Notificaciones inteligentes**: Recordatorios 15 minutos antes del evento
- **Validación robusta**: Sanitización de inputs y validación de formularios
- **Sincronización bidireccional**: Firebase Firestore + SQLite local

#### ✅ Sistema de Tareas
- **Gestión avanzada**: Tareas con título, descripción, categoría, prioridad
- **Estimación Pomodoro**: Asignación de pomodoros estimados por tarea
- **Pasos/Sub-tareas**: Lista de pasos para dividir tareas complejas
- **Fechas de vencimiento**: Alertas de tareas vencidas
- **Filtros múltiples**: Por estado (pendiente/completada), prioridad, categoría
- **Búsqueda en tiempo real**: Búsqueda instantánea por texto
- **Notificaciones de tareas**: Recordatorios configurables
- **Integración con Pomodoro**: Inicio de sesión Pomodoro desde detalle de tarea

#### 🍅 Temporizador Pomodoro
- **Timer completo**: 25min trabajo / 5min descanso corto / 15min descanso largo
- **Configuración personalizable**: Ajuste de duraciones
- **Auto-switch**: Cambio automático entre sesiones
- **Saltar sesión**: Completar sesión sin esperar el tiempo
- **Contador persistente**: Sesiones completadas guardadas en BD
- **Historial de sesiones**: Registro completo con filtros por fecha
- **Asociación con tareas**: Vincular sesiones a tareas específicas
- **Estadísticas**: Total de sesiones, tiempo trabajado, promedio diario
- **Sincronización**: Sesiones guardadas en Firebase + SQLite

#### 📋 Plantillas de Tareas
- **Reutilización eficiente**: Crear plantillas para tareas recurrentes
- **CRUD completo**: Crear, editar, eliminar plantillas
- **Configuración completa**: Título, descripción, categoría, prioridad, pomodoros, pasos
- **Creación rápida**: Generar tareas desde plantillas con un tap
- **Asociación de userId**: Plantillas privadas por usuario

#### 📊 Reportes Visuales
- **Gráfica de barras**: Pomodoros completados últimos 7 días (fl_chart)
- **Gráfica de pastel**: Distribución de tareas pendientes por categoría
- **Estadísticas detalladas**: Total pomodoros, promedio, mejor día, tareas por estado
- **Interfaz con tabs**: Navegación entre diferentes tipos de reportes

#### 🗂️ Categorías
- **Gestión completa**: Crear, editar, eliminar categorías personalizadas
- **Personalización visual**: Colores e iconos configurables
- **Aislamiento por usuario**: Categorías privadas (nullable userId para sistema)
- **Validación**: Prevención de eliminación de categorías en uso
- **Sincronización en tiempo real**: Listeners de Firebase actualizan UI automáticamente

### 🏗️ Arquitectura Técnica

#### Patrón MVC con Provider
```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   VIEWS     │ ←──→ │ CONTROLLERS  │ ←──→ │   MODELS    │
│ (Screens)   │      │ (ChangeNotify)│      │ (Entities)  │
└─────────────┘      └──────────────┘      └─────────────┘
                            ↓
                     ┌──────────────┐
                     │   SERVICES   │
                     │ (DB, Auth)   │
                     └──────────────┘
```

**Controladores implementados:**
- `AuthController`: Gestión de autenticación y perfil de usuario
- `EventController`: Lógica de eventos con recarga de categorías en cambios
- `TaskController`: Gestión de tareas con filtros y búsqueda
- `CategoryController`: CRUD de categorías con listeners
- `PomodoroController`: Timer, sesiones, contador persistente
- `TemplateController`: Gestión de plantillas de tareas

#### Sistema de Base de Datos Híbrido (Offline-First)

**DatabaseServiceHybridV2** - Arquitectura de 3 capas:

```
┌─────────────────────────────────────────────────────────┐
│                  CAPA DE APLICACIÓN                      │
│              (Controllers consume interface)             │
└────────────────────────┬────────────────────────────────┘
                         │ DatabaseInterface
┌────────────────────────▼────────────────────────────────┐
│              DatabaseServiceHybridV2                     │
│  • Coordina SQLite + Firebase                           │
│  • Listeners en tiempo real                             │
│  • Cola de sincronización offline                       │
│  • Callbacks onDataChanged → Controllers                │
└────────┬───────────────────────────────┬────────────────┘
         │                               │
         ▼                               ▼
┌─────────────────┐           ┌──────────────────────┐
│ DatabaseService │           │  FirebaseService     │
│   (SQLite)      │           │   (Firestore)        │
│                 │           │                      │
│ • Persistencia  │           │ • Sync en nube       │
│   local         │           │ • Real-time streams  │
│ • Offline-first │           │ • Multi-device sync  │
│ • Instantáneo   │           │ • Auth integration   │
└─────────────────┘           └──────────────────────┘
         │                               │
         ▼                               ▼
   ┌──────────┐                 ┌────────────────┐
   │ SQLite DB│                 │ Firestore DB   │
   │ v9       │                 │ Collections    │
   └──────────┘                 └────────────────┘
```

**Flujo de Sincronización:**

1. **Escritura (Create/Update/Delete)**:
   ```
   App → SQLite (instantáneo) → SyncQueue (si offline)
      → Firebase (cuando online) → Notificar otros dispositivos
   ```

2. **Lectura**:
   ```
   App → SQLite (siempre) → Retorna datos locales
   ```

3. **Sincronización Bidireccional**:
   ```
   Firebase Listener → Detecta cambio remoto
      → Actualiza SQLite local
      → Trigger onDataChanged callback
      → Controller.notifyListeners()
      → UI se actualiza automáticamente
   ```

**Componentes clave:**
- **SyncQueueService**: Cola de operaciones pendientes offline
- **ConnectivityService**: Monitor de estado de red
- **Listeners en tiempo real**: Streams de Firebase actualizan SQLite
- **Callbacks**: `onDataChanged()` notifica a controllers cuando hay cambios desde Firebase

**Colecciones Firebase:**
- `events/` - Eventos con filtro por userId
- `categories/` - Categorías (nullable userId para sistema)
- `tasks/` - Tareas con asociación userId
- `pomodoro_sessions/` - Sesiones de Pomodoro
- `task_templates/` - Plantillas de tareas
- `users/` - Perfiles de usuario

**Migraciones SQLite:**
- v7: Tabla `users` + userId en `events`
- v8: userId agregado a `events` (migración de datos existentes)
- v9: userId agregado a `categories` (soporte multi-usuario categorías)

#### Sistema de Notificaciones
- **Plugin**: flutter_local_notifications ^17.2.2
- **Canales**: events_channel, tasks_channel, pomodoro_channel
- **Permisos**: Solicitud dinámica (Android 13+)
- **Timezone**: Soporte para programación exacta
- **Validación**: Solo notificaciones futuras

## 🛠️ Stack Tecnológico Completo

### Framework y Lenguaje
- **Flutter**: ^3.9.2
- **Dart**: ^3.9.2
- **Arquitectura**: MVC con Provider para gestión de estado

### Dependencias Core

#### Backend y Base de Datos
- `firebase_core`: ^3.6.0 - Inicialización de Firebase
- `cloud_firestore`: ^5.4.3 - Base de datos NoSQL en tiempo real
- `firebase_auth`: ^5.3.1 - Autenticación multi-usuario (email/password)
- `sqflite`: ^2.3.3 - Base de datos local SQLite (offline-first)
- `shared_preferences`: ^2.3.3 - Persistencia de preferencias locales

#### Gestión de Estado y UI
- `provider`: ^6.1.2 - State management con ChangeNotifier
- `table_calendar`: ^3.0.9 - Widget de calendario interactivo
- `fl_chart`: ^0.69.0 - Gráficas visuales (barras, pastel)
- `form_field_validator`: ^1.1.0 - Validación de formularios

#### Funcionalidades del Sistema
- `flutter_local_notifications`: ^17.2.2 - Notificaciones locales programadas
- `timezone`: ^0.9.4 - Manejo de zonas horarias para notificaciones
- `permission_handler`: ^11.3.1 - Gestión de permisos (notificaciones, alarmas)
- `connectivity_plus`: ^6.0.5 - Detección de estado de red (online/offline)

### Herramientas de Desarrollo
- `flutter_lints`: ^5.0.0 - Análisis estático de código
- `flutter_test`: Testing framework integrado

## 🔒 Seguridad y Validación

### Sanitización de Datos
**SecurityUtils** - Utilidad centralizada:
```dart
// Limpieza de inputs maliciosos
final sanitized = SecurityUtils.sanitizeInput(userInput);

// Generación de IDs criptográficamente seguros
final id = SecurityUtils.generateSecureId();
```

**Protecciones implementadas:**
- ✅ Eliminación de SQL injection
- ✅ Prevención de XSS
- ✅ Validación de longitud de campos
- ✅ IDs únicos con crypto.getRandomValues()

### Aislamiento Multi-Usuario

**Todas las queries filtradas por userId:**
```dart
// Ejemplo: Eventos por usuario
WHERE userId = ? AND date = ?

// Firebase
.where('userId', isEqualTo: currentUserId)
```

**Colecciones protegidas:**
- Events: `userId TEXT NOT NULL`
- Categories: `userId TEXT` (nullable para sistema)
- Tasks: `userId TEXT NOT NULL`
- Pomodoro Sessions: `userId TEXT NOT NULL`
- Task Templates: `userId TEXT NOT NULL`

### Validación de Formularios
- **Eventos**: Título requerido, fecha fin > fecha inicio
- **Tareas**: Título requerido, categoría válida, prioridad válida
- **Categorías**: Nombre único, color e icono válidos
- **Plantillas**: Nombre y título requeridos, validación de categoría existente

## 📱 Estructura del Proyecto Detallada

```
lib/
├── main.dart                      # Entry point, MultiProvider setup
│
├── controllers/                   # Lógica de negocio (ChangeNotifier)
│   ├── auth_controller.dart      # Login, registro, perfil, logout
│   ├── event_controller.dart     # CRUD eventos + recarga categorías
│   ├── task_controller.dart      # Gestión tareas + filtros
│   ├── category_controller.dart  # CRUD categorías + listeners
│   ├── pomodoro_controller.dart  # Timer + sesiones + contador
│   └── template_controller.dart  # CRUD plantillas
│
├── models/                        # Entidades de datos
│   ├── event.dart                # userId, toMap(), toJson(), fromMap(), fromJson()
│   ├── category.dart             # userId nullable, Color, IconData
│   ├── task.dart                 # Steps, Priority, Status, Recurrence
│   ├── pomodoro_session.dart     # SessionType (work/break), duration
│   ├── task_template.dart        # Plantilla reutilizable
│   └── user_profile.dart         # Perfil de usuario (Firebase Auth)
│
├── services/                      # Capa de datos y servicios externos
│   ├── database_interface.dart   # Interfaz común (22+ métodos)
│   ├── database_service.dart     # SQLite local (v9)
│   ├── firebase_service.dart     # Firestore + Auth (streams)
│   ├── database_service_hybrid_v2.dart  # Orquestador principal ⭐
│   ├── sync_queue_service.dart   # Cola offline (SharedPreferences)
│   ├── connectivity_service.dart # Monitor de red
│   └── notification_service.dart # Local notifications + timezone
│
├── views/                         # Pantallas principales
│   ├── splash_screen.dart        # Animación + verificación sesión
│   ├── login_screen.dart         # UI login + validación
│   ├── register_screen.dart      # Registro nuevo usuario
│   ├── password_reset_screen.dart # Recuperación contraseña
│   ├── profile_screen.dart       # Editar perfil + cambiar password
│   ├── home_screen.dart          # Calendario + eventos del día
│   ├── add_edit_event_screen.dart # Formulario eventos
│   ├── event_detail_screen.dart  # Detalle + marcar completado
│   ├── list_categories_screen.dart # Gestión categorías
│   ├── task_list_screen.dart     # Lista tareas + filtros
│   ├── add_edit_task_screen.dart # Formulario tareas + pasos
│   ├── task_detail_screen.dart   # Detalle + iniciar Pomodoro
│   ├── templates_screen.dart     # Lista plantillas + crear desde plantilla
│   ├── pomodoro_screen.dart      # Timer + controles + sugerencias
│   ├── pomodoro_history_screen.dart # Historial sesiones + stats
│   ├── reports_screen.dart       # Gráficas visuales (tabs)
│   └── main_screen.dart          # Wrapper con navegación
│
├── widgets/                       # Componentes reutilizables
│   ├── app_drawer.dart           # Drawer con user info + navegación
│   ├── event_card.dart           # Tarjeta de evento
│   └── custom_app_bar.dart       # AppBar customizado
│
└── utils/                         # Utilidades
    └── security_utils.dart        # Sanitización + generación IDs
```

## 🔧 Configuración y Setup

### Prerrequisitos
```bash
# Verificar instalación
flutter doctor -v

# Versiones requeridas
Flutter SDK: >= 3.9.2
Dart SDK: >= 3.9.2
```

### Instalación Paso a Paso

#### 1. Clonar y Setup Inicial
```bash
git clone https://github.com/davidmanueldev/mi-agenda-flutter.git
cd mi_agenda
flutter pub get
```

#### 2. Configuración de Firebase

**Opción A - Script Automático:**
```bash
chmod +x scripts/setup_firebase.sh
./scripts/setup_firebase.sh
```

**Opción B - Manual:**
```bash
# 1. Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# 2. Login Firebase
firebase login

# 3. Configurar proyecto
flutterfire configure --project=mi-agenda-flutter-d4d7d

# 4. Habilitar Authentication en Firebase Console
# https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/authentication/providers
# → Email/Password: HABILITAR

# 5. Aplicar reglas de seguridad Firestore (IMPORTANTE)
# https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/firestore/rules
# → Copiar reglas desde FIREBASE_SECURITY_RULES.md
```

**Archivos generados:**
- `lib/firebase_options.dart` - Configuración automática
- `android/app/google-services.json` - Configuración Android
- `ios/Runner/GoogleService-Info.plist` - Configuración iOS

#### 3. Configuración de Permisos

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<!-- Ya configurado en el proyecto -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSNotificationUsageDescription</key>
<string>Esta aplicación necesita enviar notificaciones para recordatorios</string>
```

#### 4. Ejecutar la Aplicación
```bash
# Listar dispositivos disponibles
flutter devices

# Ejecutar en dispositivo específico
flutter run -d <device_id>

# Ejemplo: Android
flutter run -d infinix

# Modo release (optimizado)
flutter run --release
```

### Verificación Post-Instalación

**Checklist:**
- ✅ App inicia mostrando SplashScreen
- ✅ Navega a LoginScreen (sin usuario autenticado)
- ✅ Firebase Console muestra proyecto activo
- ✅ Registro de nuevo usuario funciona
- ✅ Base de datos SQLite se crea en primer inicio
- ✅ Notificaciones solicitan permisos correctamente

## 🚀 Uso de la Aplicación

### Flujo de Usuario Completo

#### 1. Primera Vez (Registro)
```
SplashScreen (animación 2s)
  ↓
LoginScreen → Tap "Crear cuenta"
  ↓
RegisterScreen:
  - Nombre completo
  - Email válido
  - Contraseña (min 6 caracteres)
  - Confirmar contraseña
  - Aceptar términos
  ↓
MainScreen (Home - Calendario)
```

#### 2. Usuarios Existentes (Login)
```
SplashScreen → Verificar sesión
  ↓ (Usuario autenticado)
MainScreen automáticamente
  
  ↓ (No autenticado)
LoginScreen:
  - Email
  - Contraseña
  - ¿Olvidaste contraseña? → PasswordResetScreen
```

### Gestión de Eventos

**Crear Evento:**
1. HomeScreen → FAB (+)
2. Completar formulario:
   - Título (requerido)
   - Descripción (opcional)
   - Fecha y hora inicio
   - Fecha y hora fin
   - Categoría (dropdown scrolleable)
3. Guardar → Notificación programada automáticamente

**Editar/Eliminar:**
1. Tap en evento → EventDetailScreen
2. Botón editar (lápiz) → Modificar datos
3. Botón eliminar (papelera) → Confirmación → Eliminar

**Marcar Completado:**
- Tap en checkbox de la tarjeta de evento
- Estado persiste en SQLite + Firebase

### Gestión de Tareas

**Crear Tarea:**
1. AppDrawer → "Tareas"
2. FAB (+) → AddEditTaskScreen
3. Completar:
   - Título (requerido)
   - Descripción
   - Categoría (dropdown scrolleable con +3 categorías)
   - Prioridad (Urgente/Alta/Media/Baja)
   - Fecha vencimiento
   - Estimación Pomodoros (spinner ±)
   - Pasos (agregar con + )
4. Guardar

**Filtrar Tareas:**
- Chips de filtro rápido: Todas, Pendientes, Completadas
- Filtro por prioridad (dropdown)
- Filtro por categoría (dropdown)
- Búsqueda en tiempo real (barra superior)

**Completar Tarea:**
- Tap en checkbox → Status = completed
- Se muestra con estilo tachado
- Filtro "Completadas" las agrupa

**Iniciar Pomodoro desde Tarea:**
1. TaskDetailScreen → Botón "Iniciar Pomodoro"
2. Navega a PomodoroScreen con taskId asociado
3. Sesiones se vinculan a la tarea

### Sistema Pomodoro

**Iniciar Sesión:**
1. AppDrawer → "Pomodoro"
2. Configurar (opcional):
   - Duración trabajo (default 25min)
   - Descanso corto (default 5min)
   - Descanso largo (default 15min)
3. Tap "Iniciar" → Timer comienza

**Controles:**
- ⏸️ **Pausar**: Detiene timer temporalmente
- ▶️ **Reanudar**: Continúa desde donde pausó
- ⏹️ **Detener**: Finaliza sesión (no cuenta como completada)
- ⏭️ **Saltar**: Completa sesión actual y pasa a siguiente

**Flujo Automático:**
```
Trabajo (25min) → Descanso corto (5min) → Trabajo → Descanso corto
                                                    ↓ (4 ciclos)
                                          Descanso largo (15min)
```

**Historial:**
- AppDrawer → "Historial Pomodoro"
- Filtros por rango de fechas
- Estadísticas: Total sesiones, tiempo trabajado, promedio

### Plantillas de Tareas

**Crear Plantilla:**
1. AppDrawer → "Plantillas de Tareas"
2. FAB (+) → Dialog
3. Completar:
   - Nombre plantilla (ej: "Reunión Semanal")
   - Título de tarea generada
   - Descripción
   - Categoría (dropdown scrolleable)
   - Prioridad
   - Pomodoros estimados
   - Pasos (opcional)
4. Crear

**Usar Plantilla:**
1. Tap en tarjeta de plantilla
2. Confirma creación
3. Tarea creada automáticamente en TaskListScreen

**Editar/Eliminar Plantilla:**
- Menú 3 puntos → Editar / Eliminar

### Categorías

**Gestionar:**
1. AppDrawer → "Categorías"
2. FAB (+) → Dialog
3. Configurar:
   - Nombre (requerido)
   - Descripción
   - Color (ColorPicker)
   - Icono (IconPicker)
4. Guardar

**Editar/Eliminar:**
- Tap en tarjeta → Dialog con datos precargados
- Validación: No permite eliminar categorías con eventos/tareas asociadas

### Reportes y Estadísticas

**Visualizar Gráficas:**
1. AppDrawer → "Reportes"
2. Tabs disponibles:
   - **Pomodoros**: Barras últimos 7 días
   - **Tareas**: Pastel por categoría
   - **Eventos**: (Próximamente)
3. Estadísticas resumen en cards

### Perfil de Usuario

**Acceder:**
- AppDrawer → Header (nombre/email) O
- AppDrawer → "Perfil"

**Editar Nombre:**
1. Sección "Información Personal"
2. Tap lápiz → Campo editable
3. Guardar → Actualiza en Firebase + local

**Cambiar Contraseña:**
1. Sección "Seguridad"
2. Tap "Cambiar contraseña"
3. Completar:
   - Contraseña actual
   - Nueva contraseña
   - Confirmar nueva contraseña
4. Guardar

**Eliminar Cuenta:**
1. Sección "Zona Peligrosa"
2. Tap "Eliminar cuenta"
3. Confirmación (dialog)
4. Autenticación (contraseña)
5. Eliminación permanente (Firebase Auth + Firestore)

**Cerrar Sesión:**
- Botón "Cerrar Sesión" → Vuelve a LoginScreen

## 📊 Funcionalidades Técnicas Avanzadas

### Sincronización Offline-First

**Escenario 1: Usuario crea evento sin internet**
```
1. Usuario crea evento → Guardado en SQLite (instantáneo)
2. SyncQueue añade operación: { type: 'createEvent', data: {...} }
3. ConnectivityService detecta WiFi → Trigger sync
4. DatabaseServiceHybridV2.syncPendingOperations()
5. Evento creado en Firebase → Sincronizado
6. SyncQueue elimina operación completada
```

**Escenario 2: Otro dispositivo edita evento**
```
1. Dispositivo B edita evento en Firebase
2. Dispositivo A: Firebase listener detecta cambio
3. Callback onDataChanged() ejecutado
4. SQLite local actualizado
5. EventController.loadEvents() llamado
6. UI se actualiza automáticamente (notifyListeners)
```

### Manejo de Errores y Estados

**Estados de UI:**
- `isLoading`: true durante operaciones async
- `errorMessage`: String con error user-friendly
- `isEmpty`: Listas vacías muestran EmptyState

**Patrón en Controllers:**
```dart
Future<void> someOperation() async {
  _setLoading(true);
  _clearError();
  try {
    await _database.someMethod();
    notifyListeners();
  } catch (e) {
    _setError('Error: $e');
  } finally {
    _setLoading(false);
  }
}
```

### Optimizaciones de Performance

**Queries Indexadas:**
```sql
-- SQLite
CREATE INDEX idx_events_userId ON events(userId);
CREATE INDEX idx_events_startTime ON events(startTime);
CREATE INDEX idx_categories_userId ON categories(userId);
CREATE INDEX idx_tasks_userId ON tasks(userId);
CREATE INDEX idx_pomodoro_userId ON pomodoro_sessions(userId);
```

**Firebase Composite Indexes:**
```javascript
// Removidos orderBy() para evitar índices compuestos
// Ordenación ahora local en memoria

// ANTES (requería índice):
.where('userId', isEqualTo: uid)
.orderBy('startTime')  // ❌ Índice compuesto

// AHORA:
.where('userId', isEqualTo: uid)
// Ordenación: events.sort((a,b) => ...) // ✅ Local
```

**Debouncing en Búsqueda:**
- Búsqueda de tareas usa `setState()` sin debounce (suficientemente rápido)
- Queries locales a SQLite (<5ms)

## 🐛 Problemas Conocidos y Soluciones

### ✅ RESUELTOS

#### 1. Categories Table Missing userId (Nov 18, 2025)
**Problema**: Error "table categories has no column named userId"  
**Causa**: `_createTables()` no incluía columna userId para fresh installs  
**Solución**: Agregado userId a schema de categories + index  
**Commit**: [Ver database_service.dart líneas 45-107]

#### 2. Plantillas no se Guardaban
**Problema**: userId temporal 'user_temp' impedía guardar en Firebase  
**Causa**: No se obtenía userId del usuario autenticado  
**Solución**: Agregado getter `currentUserId` en TemplateController  
**Commit**: [Ver template_controller.dart línea 19]

#### 3. Categorías No Scrolleables en Dropdowns
**Problema**: Más de 3 categorías no visibles en DropdownButtonFormField  
**Solución**: Agregado `menuMaxHeight: 300` a dropdowns  
**Archivos**: add_edit_task_screen.dart, templates_screen.dart

#### 4. Categorías Eliminadas Aparecían en Eventos
**Problema**: EventController no se enteraba de eliminación de categorías  
**Solución**: Agregado `loadCategories()` en listener de Firebase  
**Commit**: [Ver event_controller.dart línea 37]

#### 5. Android Back Button Cerraba App
**Problema**: Botón atrás en HomeScreen salía de la app  
**Solución**: Agregado `PopScope` con dialog de confirmación  
**Commit**: [Ver home_screen.dart líneas 40-68]

### ⚠️ PENDIENTES

#### 1. Evento Huérfano en Firebase
**Síntoma**: Log "Error sincronizando Firebase: La categoría especificada no existe"  
**Causa**: Evento en Firebase referencia categoría eliminada  
**Solución Temporal**: Error no afecta funcionalidad  
**Solución Permanente**: Implementar cascade delete o limpiar manualmente en Firebase Console

#### 2. Firebase Security Rules Sin Aplicar
**Estado**: Reglas definidas en FIREBASE_SECURITY_RULES.md  
**Acción Requerida**: Copiar y publicar en Firebase Console  
**URL**: https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/firestore/rules

## 🧪 Testing y Validación

### Checklist de Pruebas Manual

#### Autenticación
- [ ] Registro nuevo usuario con email único
- [ ] Login usuario existente
- [ ] Recuperación contraseña (recibe email)
- [ ] Editar nombre de perfil
- [ ] Cambiar contraseña
- [ ] Cerrar sesión
- [ ] Persistencia de sesión (reabrir app)
- [ ] Eliminación de cuenta

#### Multi-Usuario
- [ ] Usuario A crea evento → No visible para Usuario B
- [ ] Usuario B crea categoría → No visible para Usuario A
- [ ] Ambos usuarios tienen datos independientes

#### Sincronización
- [ ] Crear evento offline → Sincroniza al conectar WiFi
- [ ] Editar evento en Firebase Console → App actualiza automáticamente
- [ ] Contador Pomodoro persiste al cerrar app
- [ ] Plantillas se guardan correctamente

#### Notificaciones
- [ ] Evento en 15min → Notificación aparece
- [ ] Permisos solicitados correctamente (Android 13+)
- [ ] Notificación muestra título y descripción correctos

### Comandos de Testing

```bash
# Análisis estático
flutter analyze

# Formatear código
flutter format lib/

# Limpiar y rebuildar
flutter clean
flutter pub get
flutter run

# Generar APK release
flutter build apk --release

# Generar App Bundle (Google Play)
flutter build appbundle --release

# Inspeccionar tamaño del APK
flutter build apk --analyze-size
```

## 📚 Documentación Técnica Adicional

### Documentos de Desarrollo
- `FIREBASE_FINAL_SETUP.md` - Configuración detallada Firebase
- `FIREBASE_AUTH_SETUP.md` - Habilitación Email/Password Auth
- `FIREBASE_SECURITY_RULES.md` - Reglas de seguridad Firestore
- `MULTI_USER_IMPLEMENTATION.md` - Implementación soporte multi-usuario
- `DEBUGGING_MULTI_USER.md` - Fixes y correcciones multi-usuario
- `SINCRONIZACION_OFFLINE_ONLINE.md` - Arquitectura sync híbrido
- `POMODORO_FIXES.md` - Correcciones timer Pomodoro
- `POMODORO_SYNC_FIX.md` - Fix contador persistente
- `POMODORO_SYNC_HISTORY.md` - Implementación historial
- `VERIFICACION_SYNC.md` - Tests integridad sincronización
- `FIXES_CATEGORIAS_NAVEGACION.md` - Fixes UI categorías
- `FEATURE_7_REPORTES.md` - Implementación gráficas fl_chart
- `ROADMAP.md` - Plan de desarrollo futuro
- `CHECKLIST_PRUEBAS.md` - Lista verificación testing

### Scripts Útiles
- `scripts/setup_firebase.sh` - Setup automático Firebase
- `scripts/clear_firebase_auth.sh` - Limpiar sesión y reiniciar

## 🔮 Roadmap Futuro

### Fase 1B (Próximos pasos)
- [ ] Vista "Hoy" unificada (eventos + tareas + sesiones Pomodoro)
- [ ] Widgets de sugerencias inteligentes
- [ ] Notificaciones push Firebase Cloud Messaging
- [ ] Soporte para tareas recurrentes
- [ ] Arrastrar y soltar en calendario

### Fase 2 (Funcionalidades Avanzadas)
- [ ] Modo oscuro persistente
- [ ] Exportar datos (CSV/PDF)
- [ ] Compartir eventos entre usuarios
- [ ] Integración con Google Calendar
- [ ] Voice input para crear tareas

### Fase 3 (Optimización)
- [ ] Tests unitarios (coverage >80%)
- [ ] Tests de integración
- [ ] CI/CD con GitHub Actions
- [ ] Publicación en Google Play Store
- [ ] Versión iOS (App Store)

## 🤝 Contribución

### Configuración Entorno Dev
```bash
# Fork del repo
git clone https://github.com/TU-USERNAME/mi-agenda-flutter.git
cd mi_agenda

# Crear rama feature
git checkout -b feature/nueva-funcionalidad

# Hacer cambios y commit
git add .
git commit -m "feat: descripción del cambio"

# Push y crear PR
git push origin feature/nueva-funcionalidad
```

### Convenciones de Código
- **Dart Style Guide**: Seguir guías oficiales
- **Nombres**: camelCase para variables, PascalCase para clases
- **Comentarios**: Documentar métodos públicos
- **Commits**: Conventional Commits (feat:, fix:, docs:, refactor:)

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

---

## 👨‍💻 Autor y Contacto

**David Manuel**  
*Especialista en tomar cafécito y escribir código, aveces.*

- GitHub: [@davidmanueldev](https://github.com/davidmanueldev)
- Proyecto: [mi-agenda-flutter](https://github.com/davidmanueldev/mi-agenda-flutter)

---

**Última actualización**: Noviembre 18, 2025  
**Versión del README**: 2.0.0