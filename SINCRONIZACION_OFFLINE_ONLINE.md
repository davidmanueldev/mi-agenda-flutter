# 🔄 Sistema de Sincronización Offline/Online

## 📋 **Resumen de la Solución**

Hemos implementado un sistema completo de sincronización bidireccional que:

✅ **Funciona 100% offline** - Puedes crear, editar y eliminar eventos sin internet
✅ **Sincronización automática** - Cuando te conectas, los cambios se suben a Firebase
✅ **Tiempo real** - Los cambios en Firebase se reflejan inmediatamente en la app
✅ **Consistencia** - Si borras en Firebase, se borra en tu app también
✅ **Cola de operaciones** - Cambios offline se guardan y se sincronizan después
✅ **Detección de conectividad** - La app sabe cuando estás online/offline

---

## 🎯 **Cómo Funciona**

### **Modo Offline:**
```
Usuario crea evento → Se guarda en SQLite → Se agrega a cola de sincronización
```

### **Cuando se conecta:**
```
App detecta conexión → Procesa cola de sincronización → Sube cambios a Firebase
```

### **Modo Online:**
```
Usuario crea evento → Se guarda en SQLite + Firebase simultáneamente
Listener detecta cambio en Firebase → Se sincroniza a SQLite
```

### **Cambios en Firebase (desde otro dispositivo):**
```
Evento eliminado en Firebase → Listener detecta → Se elimina de SQLite local
```

---

## 🔧 **Archivos Creados**

### 1. `lib/services/connectivity_service.dart`
- Detecta si hay conexión a internet
- Emite eventos cuando cambia la conectividad
- Permite verificar manualmente el estado

### 2. `lib/services/sync_queue_service.dart`
- Guarda operaciones pendientes cuando estás offline
- Persiste en SharedPreferences
- Procesa la cola cuando hay conexión

### 3. `lib/services/database_service_hybrid_v2.dart`
- Servicio principal que reemplaza al anterior
- Maneja sincronización bidireccional
- Listeners en tiempo real de Firebase
- Cola de operaciones offline

### 4. Métodos agregados en `firebase_service.dart`
- `getEventsStream()` - Stream de eventos en tiempo real
- `getCategoriesStream()` - Stream de categorías en tiempo real

### 5. Métodos agregados en modelos
- `Event.toJson()` / `Event.fromJson()`
- `Category.toJson()` / `Category.fromJson()`

---

## 🚀 **Activar el Nuevo Sistema**

### **Paso 1: Modificar main.dart**

Abre `lib/main.dart` y cambia el servicio que se usa en el controller:

```dart
// BUSCAR esta línea (aproximadamente línea 30-40):
import 'services/database_service_hybrid.dart';

// REEMPLAZAR por:
import 'services/database_service_hybrid_v2.dart';
```

```dart
// BUSCAR en MultiProvider (aproximadamente línea 50):
ChangeNotifierProvider(
  create: (context) => EventController(
    databaseService: DatabaseServiceHybrid(),  // ← LÍNEA ANTIGUA
    notificationService: NotificationService(),
  ),
),

// REEMPLAZAR por:
ChangeNotifierProvider(
  create: (context) => EventController(
    databaseService: DatabaseServiceHybridV2(),  // ← LÍNEA NUEVA
    notificationService: NotificationService(),
  ),
),
```

### **Paso 2: Agregar Indicador de Estado (Opcional)**

Si quieres mostrar al usuario si está online/offline, agrega esto en `home_screen.dart`:

```dart
import '../services/connectivity_service.dart';

// En el build method, agregar StreamBuilder:
StreamBuilder<bool>(
  stream: ConnectivityService().connectionStream,
  initialData: ConnectivityService().isOnline,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? false;
    
    return Container(
      padding: EdgeInsets.all(8),
      color: isOnline ? Colors.green : Colors.orange,
      child: Text(
        isOnline ? '🟢 Conectado' : '🟠 Modo Offline',
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  },
)
```

---

## 🧪 **Cómo Probar**

### **Test 1: Crear offline**
1. Activa modo avión en tu dispositivo
2. Abre la app
3. Crea un evento → Debería guardarse sin error
4. Desactiva modo avión
5. Espera 2-3 segundos
6. Verifica en Firebase Console → El evento debería aparecer

### **Test 2: Sincronización bidireccional**
1. Con internet, crea un evento en la app
2. Ve a Firebase Console → Borra ese evento
3. Vuelve a la app
4. El evento debería desaparecer automáticamente (2-3 segundos)

### **Test 3: Editar offline**
1. Crea evento con internet
2. Activa modo avión
3. Edita el evento
4. Desactiva modo avión
5. Los cambios deberían subir a Firebase

### **Test 4: Cola de sincronización**
1. Modo avión activado
2. Crea 3 eventos
3. Edita 2 eventos existentes
4. Elimina 1 evento
5. Desactiva modo avión
6. Verifica logs: debería decir "Sincronizando 6 operaciones pendientes"
7. Todos los cambios deberían reflejarse en Firebase

---

## 📊 **Monitorear Sincronización**

En los logs verás mensajes como:

```
✅ Estado de conectividad cambió: ONLINE
✅ Agregado a cola: SyncOperation.createEvent
✅ Iniciando sincronización de 3 operaciones pendientes...
✅ Sincronizado: SyncOperation.createEvent
✅ Sincronización completada
```

---

## ⚠️ **Resolución de Conflictos**

El sistema usa **"última escritura gana"** (last-write-wins):

- Si editas offline y alguien más edita online → Se guarda la última versión
- Los timestamps `updatedAt` determinan qué versión es más reciente
- Firebase siempre tiene prioridad cuando hay conexión

---

## 🔍 **Diagnosticar Problemas**

### **Problema: "Los cambios offline no se sincronizan"**

**Solución:**
1. Verifica logs para ver si hay errores de Firebase
2. Asegúrate que los índices de Firebase estén creados
3. Revisa que la autenticación de Firebase funcione
4. Verifica permisos de internet en AndroidManifest.xml:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
   ```

### **Problema: "Eventos duplicados"**

**Solución:**
- Limpia la base de datos SQLite y Firebase
- Reinstala la app
- Esto puede pasar si hubo migraciones entre versiones

### **Problema: "No detecta cambios de conectividad"**

**Solución:**
1. Verifica permisos de red en AndroidManifest.xml
2. En iOS, agrega en Info.plist:
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
     <key>NSAllowsArbitraryLoads</key>
     <true/>
   </dict>
   ```

---

## 📈 **Ventajas del Nuevo Sistema**

| Característica | Sistema Anterior | Sistema Nuevo |
|----------------|------------------|---------------|
| **Funciona offline** | ❌ Solo lectura | ✅ CRUD completo |
| **Sincronización** | ⚠️ Manual/parcial | ✅ Automática |
| **Tiempo real** | ❌ No | ✅ Sí |
| **Consistencia** | ❌ Se desincroniza | ✅ Siempre sincronizado |
| **Cola de ops** | ❌ No | ✅ Persiste cambios offline |
| **Detección conexión** | ❌ No | ✅ Automática |

---

## 🎯 **Próximos Pasos Recomendados**

1. ✅ **Activar el nuevo sistema** (modificar main.dart)
2. ✅ **Probar en tu dispositivo** (tests descritos arriba)
3. ✅ **Crear índices de Firebase** (si no lo has hecho)
4. ⏳ **Agregar indicador visual** de estado online/offline
5. ⏳ **Implementar botón "Sincronizar"** manual (opcional)
6. ⏳ **Agregar notificaciones** de sincronización completada

---

## 💡 **Tips de Uso**

- **No reinventar**: Usa siempre `DatabaseServiceHybridV2` en todos los controllers
- **Logs útiles**: Los logs te dicen exactamente qué está pasando
- **Paciencia**: La sincronización toma 1-3 segundos después de conectarse
- **Testing**: Siempre prueba con modo avión antes de publicar

---

## 🆘 **Soporte**

Si algo no funciona:
1. Revisa los logs en la terminal
2. Verifica que todos los archivos se hayan creado
3. Asegúrate que `flutter pub get` se ejecutó correctamente
4. Verifica que Firebase esté configurado correctamente

**El sistema está diseñado para ser robusto y recuperarse automáticamente de errores.**
