# 🔒 Reglas de Seguridad de Firebase - Multi-Usuario

**Fecha:** 5 de Noviembre, 2025  
**Estado:** ⚠️ PENDIENTE DE APLICAR

---

## 📋 Instrucciones de Aplicación

### 1. Acceder a Firebase Console

Abre el siguiente enlace en tu navegador:

```
https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/firestore/rules
```

### 2. Copiar y Pegar las Reglas

Reemplaza las reglas existentes con las siguientes:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ==================== HELPER FUNCTIONS ====================
    
    // Verificar que el usuario está autenticado
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Verificar que el userId del documento coincide con el usuario autenticado
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Verificar que el userId en el request coincide con el usuario autenticado
    function isOwnerInRequest() {
      return isAuthenticated() && request.resource.data.userId == request.auth.uid;
    }
    
    // ==================== COLECCIÓN: users ====================
    
    match /users/{userId} {
      // Solo el propietario puede leer su propio perfil
      allow read: if isAuthenticated() && request.auth.uid == userId;
      
      // Solo el propietario puede crear/actualizar su propio perfil
      allow create, update: if isAuthenticated() && 
                               request.auth.uid == userId &&
                               request.resource.data.id == userId;
      
      // Solo el propietario puede eliminar su propio perfil
      allow delete: if isAuthenticated() && request.auth.uid == userId;
    }
    
    // ==================== COLECCIÓN: events ====================
    
    match /events/{eventId} {
      // Solo leer eventos propios
      allow read: if isAuthenticated() && 
                     resource.data.userId == request.auth.uid;
      
      // Solo crear eventos con userId propio
      allow create: if isAuthenticated() && 
                       request.resource.data.userId == request.auth.uid;
      
      // Solo actualizar eventos propios
      allow update: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid &&
                       request.resource.data.userId == request.auth.uid;
      
      // Solo eliminar eventos propios
      allow delete: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid;
    }
    
    // ==================== COLECCIÓN: categories ====================
    
    match /categories/{categoryId} {
      // Leer: categorías propias O categorías del sistema (sin userId)
      allow read: if isAuthenticated() && 
                     (resource.data.userId == request.auth.uid || 
                      !('userId' in resource.data) ||
                      resource.data.userId == null);
      
      // Crear: solo categorías propias
      allow create: if isAuthenticated() && 
                       (request.resource.data.userId == request.auth.uid ||
                        !('userId' in request.resource.data));
      
      // Actualizar: solo categorías propias
      allow update: if isAuthenticated() && 
                       (resource.data.userId == request.auth.uid ||
                        !('userId' in resource.data));
      
      // Eliminar: solo categorías propias (no del sistema)
      allow delete: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid;
    }
    
    // ==================== COLECCIÓN: tasks ====================
    
    match /tasks/{taskId} {
      // Solo leer tareas propias
      allow read: if isAuthenticated() && 
                     resource.data.userId == request.auth.uid;
      
      // Solo crear tareas con userId propio
      allow create: if isAuthenticated() && 
                       request.resource.data.userId == request.auth.uid;
      
      // Solo actualizar tareas propias
      allow update: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid &&
                       request.resource.data.userId == request.auth.uid;
      
      // Solo eliminar tareas propias
      allow delete: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid;
    }
    
    // ==================== COLECCIÓN: pomodoro_sessions ====================
    
    match /pomodoro_sessions/{sessionId} {
      // Solo leer sesiones propias
      allow read: if isAuthenticated() && 
                     resource.data.userId == request.auth.uid;
      
      // Solo crear sesiones con userId propio
      allow create: if isAuthenticated() && 
                       request.resource.data.userId == request.auth.uid;
      
      // Solo actualizar sesiones propias
      allow update: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid &&
                       request.resource.data.userId == request.auth.uid;
      
      // Solo eliminar sesiones propias
      allow delete: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid;
    }
    
    // ==================== COLECCIÓN: task_templates ====================
    
    match /task_templates/{templateId} {
      // Solo leer plantillas propias
      // Nota: usa 'user_id' en lugar de 'userId' según el modelo
      allow read: if isAuthenticated() && 
                     resource.data.user_id == request.auth.uid;
      
      // Solo crear plantillas con user_id propio
      allow create: if isAuthenticated() && 
                       request.resource.data.user_id == request.auth.uid;
      
      // Solo actualizar plantillas propias
      allow update: if isAuthenticated() && 
                       resource.data.user_id == request.auth.uid &&
                       request.resource.data.user_id == request.auth.uid;
      
      // Solo eliminar plantillas propias
      allow delete: if isAuthenticated() && 
                       resource.data.user_id == request.auth.uid;
    }
    
    // ==================== DENEGAR TODO LO DEMÁS ====================
    
    // Por defecto, denegar cualquier acceso no especificado
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### 3. Publicar las Reglas

1. Haz clic en el botón **"Publicar"** en la esquina superior derecha
2. Confirma la publicación
3. Espera a que se apliquen (generalmente instantáneo)

---

## ✅ Verificación de Reglas Aplicadas

Una vez publicadas las reglas, puedes verificarlas en:

```
https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/firestore/rules
```

**Indicadores de éxito:**
- ✅ Estado: "Activas"
- ✅ Fecha de publicación: Hoy
- ✅ Sin errores de sintaxis

---

## 🧪 Testing de Seguridad

Después de aplicar las reglas, realiza las siguientes pruebas:

### Test 1: Usuario Autenticado Puede Acceder a Sus Datos
```dart
// ✅ DEBERÍA FUNCIONAR
// Usuario A intenta leer sus propios eventos
// Resultado esperado: SUCCESS
```

### Test 2: Usuario No Puede Acceder a Datos de Otro Usuario
```dart
// ❌ DEBERÍA FALLAR
// Usuario A intenta leer eventos del Usuario B
// Resultado esperado: PERMISSION_DENIED
```

### Test 3: Usuario No Autenticado No Puede Acceder
```dart
// ❌ DEBERÍA FALLAR
// Usuario sin login intenta leer cualquier dato
// Resultado esperado: PERMISSION_DENIED
```

### Test 4: Categorías del Sistema Son Accesibles
```dart
// ✅ DEBERÍA FUNCIONAR
// Usuario A lee categorías con userId == null (sistema)
// Resultado esperado: SUCCESS
```

---

## 📝 Notas Importantes

### ⚠️ IMPORTANTE: Índices Compuestos NO Requeridos
**La app ordena los datos localmente para evitar índices compuestos en Firebase.**

Si Firebase muestra un error tipo:
```
"The query requires an index. You can create it here: https://..."
```

**NO CREAR EL ÍNDICE**. Los streams ya están configurados para ordenar localmente.

Los índices simples de `userId` se crean automáticamente.

### Sobre `task_templates`
- Los templates usan el campo `user_id` (con guion bajo) en lugar de `userId`
- Las reglas reflejan esta nomenclatura
- Esto es consistente con el modelo `TaskTemplate`

### Sobre `categories`
- Las categorías del sistema tienen `userId == null`
- Todos los usuarios pueden leer estas categorías
- Solo el propietario puede modificar/eliminar sus categorías personales

### Re-autenticación para Operaciones Sensibles
- Cambiar contraseña: requiere re-autenticación (manejado en app)
- Eliminar cuenta: puede requerir re-autenticación si la sesión es antigua

---

## 🚨 Errores Comunes

### Error: "PERMISSION_DENIED"
**Causa:** Usuario intenta acceder a datos que no le pertenecen  
**Solución:** Verificar que userId en el documento == auth.uid

### Error: "Missing or insufficient permissions"
**Causa:** Las reglas no están publicadas o son muy restrictivas  
**Solución:** Verificar que las reglas estén activas en Firebase Console

### Error: "Requires recent login"
**Causa:** Sesión muy antigua para operaciones sensibles  
**Solución:** Re-autenticar usuario con `reauthenticateWithCredential()`

---

## 📊 Estado de Implementación

- ✅ **Reglas definidas**: Sí
- ⏳ **Reglas publicadas**: PENDIENTE (usuario debe aplicarlas)
- ⏳ **Testing de seguridad**: PENDIENTE
- ✅ **Filtrado app-level**: Implementado (22 métodos)
- ⏳ **Filtrado Firebase-level**: PENDIENTE (este archivo)

---

## 🔗 Referencias

- [Firebase Security Rules - Documentación Oficial](https://firebase.google.com/docs/firestore/security/get-started)
- [Testing Security Rules](https://firebase.google.com/docs/firestore/security/test-rules-emulator)
- [Best Practices](https://firebase.google.com/docs/firestore/security/best-practices)
