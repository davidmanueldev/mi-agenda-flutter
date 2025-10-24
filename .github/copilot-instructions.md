# Mi Agenda - AI Coding Agent Instructions

## Project Overview
Flutter-based personal agenda app with **offline-first architecture**, Firebase sync, and MVC pattern. Manages events, tasks, and Pomodoro focus sessions. Currently at ~40% MVP completion.

## Architecture & Patterns

### MVC with Provider State Management
- **Models**: `lib/models/` - Data classes with `toMap()`, `fromMap()`, `toJson()`, `fromJson()` for dual persistence
- **Views**: `lib/views/` - Stateless/Stateful widgets, no business logic
- **Controllers**: `lib/controllers/` - `ChangeNotifier` classes injected via `Provider`
- **Services**: Singleton pattern (`FirebaseService`, `NotificationService`, `DatabaseService`)

### Hybrid Database Architecture (Critical!)
**Active Service**: `DatabaseServiceHybridV2` (not the older `DatabaseServiceHybrid`)
```dart
// All services implement DatabaseInterface
// Main.dart uses: DatabaseServiceHybridV2()
```

**Dual Persistence Layer**:
- **SQLite** (`DatabaseService`): Primary storage, offline-first, instant writes
- **Firebase Firestore** (`FirebaseService`): Cloud sync, real-time listeners
- **Sync Queue** (`SyncQueueService`): Queues operations when offline, replays on reconnection
- **Connectivity** (`ConnectivityService`): Monitors network state, triggers sync

**Data Flow**:
1. Write operations → SQLite (instant) → Queue for Firebase if offline
2. Read operations → SQLite (always)
3. Firebase listeners → Update SQLite → Notify controller via `onDataChanged` callback
4. Conflict resolution: Last-write-wins using `updatedAt` timestamp

### Dependency Injection in main.dart
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (context) => EventController(
        databaseService: DatabaseServiceHybridV2(),  // ← Must use V2!
        notificationService: NotificationService(),
      ),
    ),
  ],
)
```

## Critical Developer Workflows

### Firebase Setup Requirements
- Anonymous auth **must** be enabled in Firebase Console
- Run `scripts/setup_firebase.sh` for initial config (see `FIREBASE_FINAL_SETUP.md`)
- After modifying Firebase config: `flutterfire configure` then restart app

### Testing Sync Behavior
```bash
# Test offline mode
adb shell svc wifi disable  # Disable WiFi
# Perform CRUD operations
adb shell svc wifi enable   # Re-enable WiFi
# Check logs for: "🔄 Sincronizando cola..." and "✅ Sincronización completada"
```

### Running the App
```bash
flutter pub get
flutter run  # Automatically initializes Firebase, DB integrity check, notifications
```

### Database Debugging
```dart
// Check integrity on startup (automatic in main.dart)
final dbService = DatabaseService();
final isIntegrity = await dbService.checkDatabaseIntegrity();
if (!isIntegrity) await dbService.resetDatabase();
```

## Project-Specific Conventions

### Security & Validation
**Always sanitize user input** using `SecurityUtils.sanitizeInput()` before database writes:
```dart
final sanitizedTitle = SecurityUtils.sanitizeInput(title);
```

**ID Generation**: Use `SecurityUtils.generateSecureId()` for new entities (not `DateTime.now().toString()`)

### Model Serialization Pattern
All models must implement **4 serialization methods**:
```dart
Map<String, dynamic> toMap()        // SQLite (millisecondsSinceEpoch)
Map<String, dynamic> toJson()       // Firebase (Timestamp objects)
factory fromMap(Map)                // SQLite deserialization
factory fromJson(Map)               // Firebase deserialization
```

### Notification Scheduling
Schedule notifications **only for future events**:
```dart
if (event.startTime.isAfter(DateTime.now())) {
  await _notificationService.scheduleEventNotification(event);
}
```
Channels: `events_channel`, `tasks_channel`, `pomodoro_channel`

### Error Handling Pattern
Controllers wrap async operations:
```dart
_setLoading(true);
_clearError();
try {
  // Operation
  notifyListeners();
} catch (e) {
  _setError('Error message: $e');
} finally {
  _setLoading(false);
}
```

## File Organization Standards

### Adding New Features
1. **Model**: Create in `lib/models/` with all 4 serialization methods
2. **Database**: Add methods to `DatabaseInterface` → Implement in all services
3. **Controller**: Create in `lib/controllers/`, extend `ChangeNotifier`
4. **View**: Create in `lib/views/`, consume controller via `Provider.of<T>(context)`
5. **Register Provider**: Add to `main.dart` MultiProvider

### Widget Reusability
Shared widgets → `lib/widgets/` (e.g., `EventCard`, `CustomAppBar`)
Screen-specific widgets → Keep inline or in same file

## External Dependencies & Integration

### Firebase Collections Structure
```
events/
  {eventId}/
    title, description, startTime (Timestamp), endTime (Timestamp), 
    category, isCompleted, userId, createdAt, updatedAt

categories/
  {categoryId}/
    id, name, color (hex string), icon (codePoint int)
```

### Permissions (Android)
Required in `AndroidManifest.xml`:
- `POST_NOTIFICATIONS` (Android 13+)
- `SCHEDULE_EXACT_ALARM`
- `INTERNET`, `ACCESS_NETWORK_STATE`

### Material Design 3
Using `useMaterial3: true` with `ColorScheme.fromSeed()`. Themes defined in `main.dart` `_buildLightTheme()` / `_buildDarkTheme()`.

## Known Issues & Workarounds

### Task System (In Progress)
Task CRUD is partially implemented. Active files: `task_controller.dart`, `task_list_screen.dart`, `add_edit_task_screen.dart`. Not yet integrated with hybrid sync—currently uses SQLite only.

### Roadmap Reference
Check `ROADMAP.md` before adding features. Phase 1A priorities: Complete Tasks, Pomodoro timer, unified "Today" view.

### Testing Checklist
Before pushing changes, verify against `CHECKLIST_PRUEBAS.md`:
- Firebase Authentication working (anonymous user created)
- Events sync to Firestore
- Notifications trigger 15min before events
- Offline mode queues operations

## Quick Reference Commands

```bash
# Clean build (fix weird errors)
flutter clean && flutter pub get && flutter run

# Check for linting issues
flutter analyze

# Generate Firebase config
flutterfire configure

# View logs with filtering
flutter logs | grep "🔥\|✅\|⚠️\|❌"
```

## Context Files to Read First
When unfamiliar with a subsystem:
- **Sync system**: `SINCRONIZACION_OFFLINE_ONLINE.md`
- **Firebase setup**: `FIREBASE_FINAL_SETUP.md`
- **Architecture overview**: `DOCUMENTO.md` (sections 1-4)
- **Feature roadmap**: `ROADMAP.md`
