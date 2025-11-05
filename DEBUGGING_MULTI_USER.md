# 🐛 Debugging Multi-Usuario - Guía de Verificación

**Fecha:** 5 de Noviembre, 2025  
**Estado:** ✅ CORRECCIONES APLICADAS

---

## 🎯 Problema Reportado

**Síntoma:** Categorías (y posiblemente otros datos) de un usuario aparecen en la sesión de otro usuario.

**Causa Identificada:** 
1. Los streams de Firebase requerían índices compuestos (`where + orderBy`)
2. Sin índices, Firebase podía retornar datos sin filtrar correctamente
3. La ordenación ahora se hace localmente para evitar índices compuestos

---

## ✅ Correcciones Aplicadas

### 1. **Streams de Firebase - Eliminado orderBy()**

**Archivos modificados:**
- `lib/services/firebase_service.dart`

**Cambios:**
- ✅ `getEventsStream()`: Removido `.orderBy('startTime')`, ordenación local
- ✅ `getCategoriesStream()`: Removido `.orderBy('name')`, ordenación local
- ✅ `getTasksStream()`: Removido `.orderBy('createdAt')`, ordenación local
- ✅ `getPomodoroSessionsStream()`: Removido `.orderBy('startTime')`, ordenación local

**Beneficio:**
- No requiere índices compuestos en Firebase
- Filtrado `.where('userId', isEqualTo: currentUserId)` funciona con índice simple automático
- Ordenación en memoria es instantánea

### 2. **Logs de Debugging Agregados**

Todos los streams ahora imprimen:
```dart
🔍 getXXXStream: currentUserId = xxx-xxx-xxx
📦 getXXXStream: Recibidos X items de Firebase
```

Esto permite verificar:
- Qué userId está activo en el stream
- Cuántos items están siendo retornados de Firebase

---

## 🧪 Cómo Verificar el Aislamiento

### Paso 1: Limpiar Datos Existentes (Opcional pero Recomendado)

**Opción A: Limpiar Firebase Console**
1. Abre: `https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/firestore/data`
2. Elimina todas las categorías existentes (o al menos las de prueba)
3. Elimina eventos/tareas si también quieres probar esos

**Opción B: Limpiar SQLite Local**
```bash
# Desinstalar y reinstalar la app
flutter clean
flutter run
# O simplemente:
# Configuración de Android → Apps → Mi Agenda → Borrar datos
```

### Paso 2: Registro de Usuario A

1. Ejecutar la app: `flutter run`
2. Registrar nuevo usuario:
   - Email: `usuarioA@test.com`
   - Password: `test123456`
   - Nombre: `Usuario A`
3. Crear 2-3 categorías:
   - Categoría A1: "Trabajo A"
   - Categoría A2: "Personal A"
4. Crear 1-2 eventos en esas categorías
5. **Cerrar sesión** (AppDrawer → Cerrar Sesión)

### Paso 3: Registro de Usuario B

1. Registrar nuevo usuario:
   - Email: `usuarioB@test.com`
   - Password: `test123456`
   - Nombre: `Usuario B`
2. **VERIFICAR**: ¿Se ven las categorías de Usuario A?
   - ✅ **CORRECTO**: Solo se ven las categorías del sistema (predeterminadas)
   - ❌ **INCORRECTO**: Se ven "Trabajo A", "Personal A"
3. Crear 2-3 categorías diferentes:
   - Categoría B1: "Estudio B"
   - Categoría B2: "Hobbies B"
4. **VERIFICAR**: ¿Se ven ambas categorías (A y B)?
   - ✅ **CORRECTO**: Solo "Estudio B", "Hobbies B" + sistema
   - ❌ **INCORRECTO**: También "Trabajo A", "Personal A"

### Paso 4: Verificar Logs

**Buscar en los logs de Flutter:**

```bash
flutter logs | grep "getCategories"
```

**Esperado:**
```
🔍 getCategoriesStream: currentUserId = xxx-usuario-A-xxx
📦 getCategoriesStream: Recibidas 2 categorías de Firebase
   - Trabajo A (userId: xxx-usuario-A-xxx)
   - Personal A (userId: xxx-usuario-A-xxx)

# Después de logout y login con Usuario B:
🔍 getCategoriesStream: currentUserId = yyy-usuario-B-yyy
📦 getCategoriesStream: Recibidas 2 categorías de Firebase
   - Estudio B (userId: yyy-usuario-B-yyy)
   - Hobbies B (userId: yyy-usuario-B-yyy)
```

**Si ves esto (INCORRECTO):**
```
📦 getCategoriesStream: Recibidas 4 categorías de Firebase
   - Trabajo A (userId: xxx-usuario-A-xxx)  ← ❌ NO DEBERÍA APARECER
   - Personal A (userId: xxx-usuario-A-xxx) ← ❌ NO DEBERÍA APARECER
   - Estudio B (userId: yyy-usuario-B-yyy)
   - Hobbies B (userId: yyy-usuario-B-yyy)
```

### Paso 5: Verificar en Firebase Console

1. Abre: `https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/firestore/data/~2Fcategories`
2. Verifica que cada categoría tenga el campo `userId` correcto
3. Copia el UID de Usuario A desde `https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/authentication/users`
4. Verifica que las categorías de Usuario A tengan ese UID en `userId`

---

## 🔧 Soluciones a Problemas Comunes

### Problema 1: Sigo viendo datos de otros usuarios

**Diagnóstico:**
```bash
flutter logs | grep "getCategoriesStream"
```

**Soluciones:**
1. **Limpiar caché de Firebase:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Verificar que userId se esté guardando:**
   - Ir a Firebase Console
   - Revisar documentos en `categories` collection
   - Verificar que tengan campo `userId` con valor correcto

3. **Eliminar datos antiguos sin userId:**
   ```javascript
   // En Firebase Console → Firestore → Query
   // Buscar categorías sin userId
   categories where userId == null
   // Eliminar manualmente (excepto las del sistema si las tienes)
   ```

### Problema 2: Error "requires an index"

**Error en logs:**
```
Error en stream de categorías: The query requires an index
```

**Solución:**
✅ **IGNORAR EL ERROR**. Los streams ya están configurados sin `orderBy()` para evitar índices compuestos.

Si persiste:
1. Verifica que estés usando la última versión del código
2. Ejecuta: `flutter clean && flutter pub get`
3. El filtro `.where('userId', isEqualTo: X)` NO requiere índice compuesto

### Problema 3: currentUserId es null

**Síntoma en logs:**
```
⚠️ getCategoriesStream: No hay usuario autenticado, retornando stream vacío
```

**Solución:**
1. Verificar que el usuario esté logueado
2. Revisar `AuthController.currentUser` no sea null
3. Verificar que `FirebaseService.currentUserId` retorne el UID correcto

---

## 📊 Checklist de Verificación Completa

### Categorías
- [ ] Usuario A crea categorías → Solo Usuario A las ve
- [ ] Usuario B crea categorías → Solo Usuario B las ve
- [ ] Logout Usuario A → Login Usuario B → Usuario B NO ve categorías de A
- [ ] Categorías del sistema visibles para ambos

### Eventos
- [ ] Usuario A crea evento → Solo Usuario A lo ve
- [ ] Usuario B crea evento → Solo Usuario B lo ve
- [ ] Usuario A NO ve eventos de Usuario B

### Tareas
- [ ] Usuario A crea tarea → Solo Usuario A la ve
- [ ] Usuario B crea tarea → Solo Usuario B la ve
- [ ] Usuario A NO ve tareas de Usuario B

### Sesiones Pomodoro
- [ ] Usuario A completa sesión → Solo Usuario A la ve en historial
- [ ] Usuario B completa sesión → Solo Usuario B la ve en historial
- [ ] Estadísticas independientes por usuario

---

## 🚨 Reporte de Problemas

Si después de estas verificaciones sigues viendo datos mezclados:

1. **Captura de pantalla** de:
   - Firebase Console mostrando los documentos con userId
   - Logs de Flutter con `getCategoriesStream`
   - La UI mostrando las categorías incorrectas

2. **Información adicional:**
   - ¿Limpiaste los datos antiguos?
   - ¿Cuántos usuarios has registrado?
   - ¿Qué versión del código estás usando?

3. **Proveer logs completos:**
   ```bash
   flutter logs > debug_log.txt
   ```

---

## ✅ Estado Esperado Después de las Correcciones

### Firebase Streams
```
✅ where('userId', isEqualTo: currentUserId)  // Filtrado por usuario
✅ Sin orderBy()                              // Sin índices compuestos
✅ Ordenación local en memoria                // Rápido y sin índices
```

### Aislamiento de Datos
```
✅ Cada usuario solo ve sus propios datos
✅ Categorías del sistema visibles para todos
✅ Logs muestran userId correcto en streams
✅ Firebase Console muestra userId en documentos
```

### Performance
```
✅ Sin necesidad de índices compuestos
✅ Filtrado eficiente con índice simple automático
✅ Ordenación en memoria instantánea
```

---

## 📞 Próximos Pasos

1. **Ejecutar testing completo** siguiendo esta guía
2. **Verificar logs** para confirmar filtrado correcto
3. **Aplicar Firebase Security Rules** (ver `FIREBASE_SECURITY_RULES.md`)
4. **Marcar feature como 100% completa** si todo funciona

🎉 **¡El sistema multi-usuario debería estar completamente aislado ahora!**
