# 🔧 Fix: Autenticación Firebase - Login no aparecía

**Fecha:** 4 de Noviembre, 2025  
**Problema:** La app no mostraba LoginScreen, siempre autenticaba anónimamente  
**Estado:** ✅ CORREGIDO

---

## 🐛 Problema Identificado

### Síntoma
- La app nunca mostraba `LoginScreen`
- Siempre había un usuario autenticado automáticamente
- SplashScreen navegaba directamente a MainScreen

### Causa Raíz

**En `lib/services/firebase_service.dart`:**

```dart
// ❌ ANTES (INCORRECTO)
static Future<void> initialize() async {
  await Firebase.initializeApp(...);
  
  // ❌ Esto autenticaba automáticamente con usuario anónimo
  final FirebaseService service = FirebaseService();
  await service._ensureAuthenticated(); // ← Login anónimo automático
}

Future<void> _ensureAuthenticated() async {
  if (_auth.currentUser == null) {
    // ❌ Creaba usuario anónimo siempre
    await _auth.signInAnonymously();
  }
}
```

**Flujo incorrecto:**
```
App Start → Firebase.initialize() → signInAnonymously() → currentUser != null
   ↓
SplashScreen → checkAuthStatus() → Usuario autenticado (anónimo)
   ↓
MainScreen (nunca muestra LoginScreen)
```

---

## ✅ Solución Aplicada

### Cambios en `firebase_service.dart`

**1. Método `initialize()` actualizado:**

```dart
// ✅ DESPUÉS (CORRECTO)
static Future<void> initialize() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('✅ Firebase inicializado correctamente');
    // ✅ NO hacer autenticación automática
    // AuthController manejará el login
  } catch (e) {
    print('❌ Error al inicializar Firebase: $e');
    rethrow;
  }
}
```

**2. Método `_ensureAuthenticated()` actualizado:**

```dart
// ✅ DESPUÉS (CORRECTO)
Future<void> _ensureAuthenticated() async {
  if (_auth.currentUser == null) {
    // ✅ Ya no hace login anónimo, solo verifica
    throw FirebaseServiceException(
      'No hay usuario autenticado. Por favor inicia sesión primero.'
    );
  }
}
```

**Flujo correcto ahora:**
```
App Start → Firebase.initialize() (sin auth) → currentUser = null
   ↓
SplashScreen → checkAuthStatus() → No hay usuario
   ↓
LoginScreen (muestra pantalla de login)
```

---

## 🔥 PASO CRÍTICO: Habilitar Email/Password en Firebase Console

**⚠️ DEBES HACER ESTO MANUALMENTE:**

### 1. Abrir Firebase Console

Abre este enlace en tu navegador:

```
https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/authentication/providers
```

### 2. Habilitar Email/Password

1. En la sección **"Sign-in method"**
2. Busca **"Email/Password"** (primera opción generalmente)
3. Haz clic en **"Email/Password"**
4. **✅ Activa el switch** que dice "Habilitar"
5. **NO actives** "Email link (passwordless sign-in)" (dejar desactivado)
6. Haz clic en **"Guardar"**

### 3. Verificar

Deberías ver:
- ✅ Email/Password: **Habilitado** (en verde/azul)
- Estado: **Enabled**

---

## 🧪 Testing Después del Fix

### 1. Hot Restart (IMPORTANTE)

```bash
# En la terminal donde está corriendo flutter run, presiona:
r  # Hot reload (puede no ser suficiente)
R  # Hot restart (recomendado)

# O detén y vuelve a ejecutar:
flutter run -d infinix
```

### 2. Flujo Esperado

**Primera vez (usuario nuevo):**
```
1. App muestra SplashScreen (2 segundos con animación)
2. Navega automáticamente a LoginScreen
3. Usuario ve:
   - Campo Email
   - Campo Password
   - Botón "Iniciar Sesión"
   - Link "¿Olvidaste tu contraseña?"
   - Botón "Crear cuenta"
```

**Si creas una cuenta:**
```
1. Clic en "Crear cuenta"
2. RegisterScreen aparece
3. Llenar: Nombre, Email, Password, Confirmar Password
4. Aceptar términos (checkbox)
5. Clic "Registrarse"
6. ✅ Si email/password está habilitado → Registro exitoso → MainScreen
7. ❌ Si email/password NO está habilitado → Error: "EMAIL_NOT_ALLOWED"
```

**Si cierras y reabres la app (con sesión activa):**
```
1. SplashScreen (2 segundos)
2. Detecta sesión → MainScreen (sin mostrar login)
```

---

## 📋 Checklist de Verificación

### ✅ En el Código (YA HECHO)
- [x] `FirebaseService.initialize()` NO hace login anónimo
- [x] `_ensureAuthenticated()` solo verifica, no crea usuarios
- [x] `AuthController` inyectado en MultiProvider
- [x] `SplashScreen` como pantalla inicial en main.dart
- [x] Métodos de auth en `FirebaseService`: signUp, signIn, signOut, resetPassword

### ⏳ En Firebase Console (DEBES HACER)
- [ ] Abrir: https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/authentication/providers
- [ ] Habilitar "Email/Password"
- [ ] Guardar cambios

### 🧪 Testing
- [ ] Hot restart la app
- [ ] Verificar que muestra LoginScreen
- [ ] Intentar crear cuenta
- [ ] Verificar que el registro funciona
- [ ] Cerrar y reabrir app → debe mantener sesión

---

## 🚨 Errores Comunes y Soluciones

### Error: "EMAIL_NOT_ALLOWED"

**Causa:** Email/Password no está habilitado en Firebase Console  
**Solución:** Sigue los pasos de "Habilitar Email/Password" arriba

**Log en Flutter:**
```
❌ Error al registrar usuario: [firebase_auth/operation-not-allowed] 
   The operation is not allowed.
```

### Error: La app sigue sin mostrar LoginScreen

**Posibles causas:**
1. No hiciste hot restart (solo hot reload no es suficiente)
2. Hay una sesión de usuario anónimo guardada

**Solución:**
```bash
# Opción 1: Hot restart
R  (en la terminal de flutter run)

# Opción 2: Limpiar y reinstalar
flutter clean
flutter pub get
flutter run -d infinix
```

### Error: "WEAK_PASSWORD"

**Causa:** Password menor a 6 caracteres (regla de Firebase)  
**Solución:** Usa contraseñas de mínimo 6 caracteres

### Error: "INVALID_EMAIL"

**Causa:** Email con formato incorrecto  
**Solución:** Verifica formato (ejemplo: user@example.com)

---

## 🔍 Logs para Debugging

Con el fix aplicado, deberías ver estos logs:

### Al iniciar la app:
```
✅ Firebase inicializado correctamente
🔐 Verificando estado de autenticación...
⚠️  No hay usuario autenticado
```

### Al intentar registrar:
```
📝 Intentando registrar usuario: user@example.com
✅ Usuario registrado exitosamente: user@example.com
💾 Guardando perfil en Firestore...
✅ Perfil guardado exitosamente
```

### Al iniciar sesión:
```
🔑 Intentando iniciar sesión: user@example.com
✅ Usuario autenticado: user@example.com
🔄 Actualizando lastLoginAt...
✅ Login exitoso
```

---

## 📚 Archivos Modificados

1. **`lib/services/firebase_service.dart`**
   - `initialize()`: Eliminado login anónimo automático
   - `_ensureAuthenticated()`: Ahora solo verifica, no autentica

---

## 🎯 Próximos Pasos

Una vez que verifiques que el login funciona:

1. **Actualizar DatabaseServiceHybridV2** para multi-usuario
   - Filtrar queries por `currentUserId`
   - Eventos, tareas, categorías, etc.

2. **Crear ProfileScreen**
   - Ver/editar perfil
   - Cambiar contraseña
   - Logout

3. **Actualizar AppDrawer**
   - Mostrar nombre/email del usuario
   - Botón de logout
   - Avatar

---

## ✅ Resultado Esperado

Después de aplicar este fix y habilitar Email/Password:

```
✅ LoginScreen aparece al abrir la app
✅ Registro de usuarios funciona correctamente
✅ Login con email/password funciona
✅ Sesión persiste al cerrar/reabrir app
✅ Password reset envía emails correctamente
✅ No más autenticación anónima automática
```
