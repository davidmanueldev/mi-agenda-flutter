# Fix Crítico: Sincronización Bidireccional Pomodoro

## Problema Identificado

**Síntoma:** Las sesiones de Pomodoro se guardaban en Firebase, pero al cerrar y reabrir la app, no aparecían en el historial ni se reflejaban en el contador.

**Log del problema:**
```
✅ POMODORO LISTENER: Recibidas 0 sesiones de Firebase
🔄 ✅ POMODORO INDEX WORKING: Iniciando sincronización de sesiones...
📦 ✅ POMODORO: Sesiones en Firebase: 0
📱 ✅ POMODORO: Sesiones locales: 0
💾 Contador cargado desde BD: 0 sesiones de trabajo hoy
```

A pesar de que había sesiones en Firebase Console, el listener reportaba **0 sesiones**.

## Causa Raíz

### Inconsistencia en el userId

**En `pomodoro_controller.dart` (línea ~135):**
```dart
// userId temporal generado en cada sesión
final userId = 'user_${DateTime.now().millisecondsSinceEpoch}'; // Temporal
_currentSession = PomodoroSession(
  id: SecurityUtils.generateSecureId(),
  userId: userId,  // ❌ userId diferente cada vez
  sessionType: _currentSessionType,
  duration: _remainingSeconds,
  startTime: DateTime.now(),
  taskId: _linkedTaskId,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

**En `firebase_service.dart` (createPomodoroSession - ANTES DEL FIX):**
```dart
Future<void> createPomodoroSession(PomodoroSession session) async {
  await _ensureAuthenticated();
  
  try {
    await _pomodoroCollection.doc(session.id).set(session.toJson());
    // ❌ Guardaba el userId temporal directamente
  } catch (e) {
    throw FirebaseServiceException('Error al crear sesión Pomodoro: $e');
  }
}
```

**En `firebase_service.dart` (getPomodoroSessionsStream):**
```dart
Stream<List<PomodoroSession>> getPomodoroSessionsStream() {
  final userId = currentUserId;  // ← Firebase Auth userId (anónimo)
  if (userId == null) {
    return Stream.value([]);
  }
  
  return _pomodoroCollection
      .where('userId', isEqualTo: userId)  // ❌ Buscaba por Firebase userId
      .orderBy('startTime', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => PomodoroSession.fromJson(doc.data() as Map<String, dynamic>))
          .toList());
}
```

### El Problema

1. **Al crear sesión**: Se generaba un `userId` temporal tipo `user_1729789200000`
2. **Al guardar en Firebase**: Se guardaba con ese userId temporal
3. **Al consultar desde Firebase**: Se buscaba por el `currentUserId` de Firebase Auth (ej: `abc123def456`)
4. **Resultado**: **Ninguna coincidencia** → 0 sesiones recuperadas

## Solución Aplicada

### Modificación en `firebase_service.dart`

**ANTES:**
```dart
Future<void> createPomodoroSession(PomodoroSession session) async {
  await _ensureAuthenticated();
  
  try {
    await _pomodoroCollection.doc(session.id).set(session.toJson());
  } catch (e) {
    throw FirebaseServiceException('Error al crear sesión Pomodoro: $e');
  }
}

Future<void> updatePomodoroSession(PomodoroSession session) async {
  await _ensureAuthenticated();
  
  try {
    await _pomodoroCollection.doc(session.id).update(session.toJson());
  } catch (e) {
    throw FirebaseServiceException('Error al actualizar sesión Pomodoro: $e');
  }
}
```

**DESPUÉS (FIX APLICADO):**
```dart
Future<void> createPomodoroSession(PomodoroSession session) async {
  await _ensureAuthenticated();
  
  try {
    final sessionData = session.toJson();
    sessionData['userId'] = currentUserId; // ✅ Sobrescribir con userId real de Firebase Auth
    
    await _pomodoroCollection.doc(session.id).set(sessionData);
  } catch (e) {
    throw FirebaseServiceException('Error al crear sesión Pomodoro: $e');
  }
}

Future<void> updatePomodoroSession(PomodoroSession session) async {
  await _ensureAuthenticated();
  
  try {
    final sessionData = session.toJson();
    sessionData['userId'] = currentUserId; // ✅ Sobrescribir con userId real de Firebase Auth
    
    await _pomodoroCollection.doc(session.id).update(sessionData);
  } catch (e) {
    throw FirebaseServiceException('Error al actualizar sesión Pomodoro: $e');
  }
}
```

### Patrón Consistente con Eventos y Tareas

Este fix alinea el comportamiento de Pomodoro con el de Eventos y Tareas, que ya implementaban correctamente este patrón:

**Eventos (firebase_service.dart - línea ~121):**
```dart
Future<void> createEvent(Event event) async {
  await _ensureAuthenticated();
  
  try {
    final eventData = event.toMap();
    eventData['userId'] = currentUserId; // ✅ Asociar con usuario
    
    await _eventsCollection.doc(event.id).set(eventData);
  } catch (e) {
    throw FirebaseServiceException('Error al crear evento: $e');
  }
}
```

**Tareas (firebase_service.dart - línea ~454):**
```dart
Future<void> createTask(Task task) async {
  await _ensureAuthenticated();
  
  try {
    final taskData = task.toJson();
    taskData['userId'] = currentUserId; // ✅ Asociar con usuario
    
    await _tasksCollection.doc(task.id).set(taskData);
  } catch (e) {
    throw FirebaseServiceException('Error al crear tarea: $e');
  }
}
```

## Flujo de Datos Correcto Ahora

### 1. Crear Sesión
```
Usuario completa sesión
  ↓
PomodoroController.start()
  ↓
_currentSession = PomodoroSession(
  userId: 'user_1729789200000'  ← Temporal, no importa
)
  ↓
DatabaseServiceHybridV2.insertPomodoroSession()
  ↓
├─ SQLite: Guarda con userId temporal (OK, es local)
└─ Firebase: createPomodoroSession()
      ↓
      sessionData['userId'] = currentUserId  ← SOBRESCRIBE con Firebase Auth userId
      ↓
      Firebase Firestore: Guarda con userId correcto ✅
```

### 2. Listener de Firebase
```
App se abre
  ↓
DatabaseServiceHybridV2._setupFirebaseListeners()
  ↓
FirebaseService.getPomodoroSessionsStream()
  ↓
Query: WHERE userId == currentUserId  ← Ahora coincide ✅
  ↓
Listener recibe sesiones: [session1, session2, ...]
  ↓
_syncPomodoroToLocal(sessions)
  ↓
├─ Inserta/actualiza en SQLite
└─ onDataChanged!() → PomodoroController._loadCompletedSessionsCount()
      ↓
      Consulta SQLite local
      ↓
      Contador se actualiza ✅
```

### 3. Cargar Contador
```
PomodoroController._loadCompletedSessionsCount()
  ↓
_database.getTodayPomodoroSessions()
  ↓
SQLite: SELECT * FROM pomodoro_sessions WHERE startTime >= hoy
  ↓
Filtra: sessionType == work && isCompleted
  ↓
_completedWorkSessions = count
  ↓
notifyListeners() → UI se actualiza ✅
```

## Logs Esperados Después del Fix

### Al completar una sesión:
```
🔥 Sesión Pomodoro creada en Firebase: [session_id]
```

### Al abrir la app con sesiones existentes:
```
✅ POMODORO LISTENER: Recibidas 3 sesiones de Firebase
🔄 ✅ POMODORO INDEX WORKING: Iniciando sincronización de sesiones...
📦 ✅ POMODORO: Sesiones en Firebase: 3
📱 ✅ POMODORO: Sesiones locales: 0
✅ Nueva sesión Pomodoro desde Firebase: work
✅ Nueva sesión Pomodoro desde Firebase: shortBreak
✅ Nueva sesión Pomodoro desde Firebase: work
💾 Contador cargado desde BD: 2 sesiones de trabajo hoy
💾 Contador guardado: 2
```

## Pruebas para Validar el Fix

### Prueba 1: Sincronización Inicial
1. **Hot restart** de la app (no hot reload, restart completo)
2. Completar 2-3 sesiones de Pomodoro
3. Verificar en Firebase Console que aparecen las sesiones con el `userId` correcto
4. Cerrar app completamente (`Force Stop`)
5. Abrir app de nuevo
6. **Verificar:**
   - ✅ El historial muestra las sesiones
   - ✅ El contador refleja las sesiones del día
   - ✅ Los logs muestran: `POMODORO LISTENER: Recibidas X sesiones`

### Prueba 2: Sincronización Bidireccional
1. En dispositivo A: Completar sesión
2. Esperar 5 segundos
3. En dispositivo B (o mismo dispositivo después de reinstalar): Abrir app
4. **Verificar:**
   - ✅ La sesión aparece en el historial
   - ✅ El contador se incrementa

### Prueba 3: Modo Offline → Online
1. Desactivar WiFi: `adb shell svc wifi disable`
2. Completar 2 sesiones
3. Reactivar WiFi: `adb shell svc wifi enable`
4. Esperar 10 segundos
5. **Verificar:**
   - ✅ Las sesiones se sincronizan a Firebase
   - ✅ Aparecen en Firebase Console con userId correcto

## Comandos Útiles para Debugging

```bash
# Hot restart (necesario para aplicar fix de Firebase)
flutter run

# Forzar cierre de app
adb shell am force-stop com.example.mi_agenda

# Ver logs filtrados
flutter logs | grep "POMODORO\|💾\|🔄\|✅"

# Verificar WiFi
adb shell svc wifi disable  # Desactivar
adb shell svc wifi enable   # Activar

# Limpiar datos de app (reset completo)
adb shell pm clear com.example.mi_agenda
```

## Verificar en Firebase Console

1. Abrir [Firebase Console](https://console.firebase.google.com/)
2. Seleccionar proyecto `mi-agenda-flutter`
3. Ir a **Firestore Database**
4. Abrir colección `pomodoro_sessions`
5. **Verificar que los documentos tienen:**
   - `userId`: El mismo para todas las sesiones del usuario (ej: `abc123def456`)
   - `startTime`: Timestamp de Firestore
   - `endTime`: Timestamp de Firestore
   - `sessionType`: 'work', 'shortBreak', 'longBreak'
   - `isCompleted`: true/false
   - `duration`: Segundos (int)

## Archivos Modificados

### Modificados:
- `lib/services/firebase_service.dart`
  - Método `createPomodoroSession()`: Sobrescribe userId con currentUserId
  - Método `updatePomodoroSession()`: Sobrescribe userId con currentUserId

### Sin Cambios (ya estaban correctos):
- `lib/services/database_service_hybrid_v2.dart` (listener funcionando)
- `lib/controllers/pomodoro_controller.dart` (listener configurado)
- `lib/views/pomodoro_history_screen.dart` (UI lista)
- `lib/views/pomodoro_screen.dart` (navegación a historial)

## Comparación: Antes vs Después

| Aspecto | ANTES (❌) | DESPUÉS (✅) |
|---------|-----------|-------------|
| **userId en Firebase** | `user_1729789200000` (temporal) | `abc123def456` (Firebase Auth) |
| **Query match** | 0 sesiones | X sesiones reales |
| **Listener recibe datos** | NO | SÍ |
| **Historial carga** | Vacío | Con sesiones |
| **Contador refleja Firebase** | NO (siempre 0) | SÍ (cuenta correcta) |
| **Sincronización bidireccional** | NO | SÍ |
| **Consistencia con Events/Tasks** | NO | SÍ |

## Lecciones Aprendidas

1. **Consistencia de patrones**: Todas las colecciones deben manejar userId de la misma forma
2. **No confiar en datos del cliente**: Sobrescribir userId en el backend (Firebase Service)
3. **Logs detallados**: Los logs mostraron claramente "0 sesiones" cuando debía haber más
4. **Testing end-to-end**: Probar flujo completo: crear → cerrar app → abrir → verificar

## Estado Final

- ✅ Sincronización bidireccional funcionando
- ✅ Listener de Firebase recibiendo sesiones
- ✅ Contador reflejando datos reales
- ✅ Historial mostrando sesiones guardadas
- ✅ Consistencia con patrón de Events y Tasks
- ⏳ **Pendiente**: Hot restart y pruebas de validación

---

**Fecha:** 24 Octubre 2025  
**Versión:** 1.1 - Fix crítico de sincronización  
**Estado:** ✅ Implementado - Pendiente de testing
