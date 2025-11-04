# Configuración de Firebase Authentication

**Fecha:** 4 de Noviembre, 2025  
**Estado:** ⚠️ PENDIENTE DE ACTIVACIÓN

---

## 🔥 Pasos para Habilitar Email/Password Authentication

### 1. Acceder a Firebase Console

Abre el siguiente enlace en tu navegador:

```
https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/authentication/providers
```

### 2. Habilitar Email/Password

1. En la sección **"Sign-in method"** (Método de inicio de sesión)
2. Busca **"Email/Password"** en la lista de proveedores
3. Haz clic en **"Email/Password"**
4. **Activa el switch** para "Habilitar"
5. Haz clic en **"Guardar"**

### 3. Verificar Configuración

Una vez habilitado, deberías ver:
- ✅ **Email/Password**: Habilitado (en verde)

---

## ✅ Verificación de Integración en la App

### Archivos Modificados

**`lib/main.dart`:**
- ✅ Importado `AuthController`
- ✅ Importado `SplashScreen`
- ✅ `AuthController` agregado a MultiProvider (primero en la lista)
- ✅ Home cambiado de `MainScreen` a `SplashScreen`

### Flujo de Autenticación Implementado

```
App Start
   ↓
SplashScreen (logo animado)
   ↓
checkAuthStatus() en AuthController
   ↓
   ├─→ Usuario autenticado → MainScreen (Home)
   └─→ Usuario NO autenticado → LoginScreen
```

### Pantallas Disponibles

1. **SplashScreen** (`lib/views/splash_screen.dart`)
   - Muestra logo con animaciones
   - Verifica sesión activa
   - Navega automáticamente

2. **LoginScreen** (`lib/views/login_screen.dart`)
   - Email + Password
   - Validación de campos
   - Link a "¿Olvidaste tu contraseña?"
   - Link a "Crear cuenta"

3. **RegisterScreen** (`lib/views/register_screen.dart`)
   - Nombre completo
   - Email + Password + Confirmar Password
   - Checkbox de términos
   - Validación robusta

4. **PasswordResetScreen** (`lib/views/password_reset_screen.dart`)
   - Recuperación por email
   - Confirmación visual
   - Opción "Reenviar email"

---

## 🧪 Testing Después de Habilitar Auth

### 1. Ejecutar la App

```bash
flutter run
```

### 2. Probar Registro

1. La app debería mostrar **SplashScreen** primero
2. Luego navegar a **LoginScreen**
3. Clic en **"Crear cuenta"**
4. Llenar formulario de registro
5. Presionar **"Registrarse"**
6. ✅ Debería crear usuario en Firebase y navegar a MainScreen

### 3. Verificar en Firebase Console

Después de registrar un usuario, verifica en:

```
https://console.firebase.google.com/project/mi-agenda-flutter-d4d7d/authentication/users
```

Deberías ver:
- Email del usuario registrado
- UID generado
- Fecha de creación

### 4. Probar Login

1. Cerrar la app completamente
2. Reabrir la app
3. Debería mostrar **SplashScreen** → detectar sesión → ir a **MainScreen** directamente
4. Si cierras sesión (logout), debería regresar a **LoginScreen**

### 5. Probar Password Reset

1. En LoginScreen, clic en **"¿Olvidaste tu contraseña?"**
2. Ingresar email registrado
3. Presionar **"Enviar email"**
4. ✅ Verificar en la bandeja de entrada del email
5. Seguir enlace de Firebase para restablecer contraseña

---

## 📝 Logs Importantes

Durante el testing, buscar estos logs en la consola:

```dart
// Autenticación exitosa
✅ Usuario registrado exitosamente: user@email.com

// Sesión detectada
🔐 Usuario autenticado: user@email.com

// Error de autenticación
❌ Error al iniciar sesión: [error message]
```

---

## 🔒 Seguridad

### Usuario ID en Firebase

- Todos los datos (eventos, tareas, categorías, etc.) se asocian con `userId`
- El `userId` es el **UID de Firebase Auth**
- Cada usuario solo puede ver/editar sus propios datos
- **PRÓXIMO PASO**: Implementar filtrado multi-usuario en `DatabaseServiceHybridV2`

### Almacenamiento Dual

- **Firebase Firestore**: Datos sincronizados en la nube
- **SQLite Local**: Copia local para modo offline
- **UserProfile**: Se guarda en ambos sistemas

---

## 🚀 Próximos Pasos

1. ✅ **COMPLETADO**: Integración de AuthController en main.dart
2. ⏳ **PENDIENTE**: Habilitar Email/Password en Firebase Console (ESTE PASO)
3. ⏳ **PENDIENTE**: Actualizar `DatabaseServiceHybridV2` para multi-usuario
4. ⏳ **PENDIENTE**: Crear ProfileScreen
5. ⏳ **PENDIENTE**: Actualizar AppDrawer con info de usuario
6. ⏳ **PENDIENTE**: Testing completo del flujo

---

## 📞 Comandos Útiles

```bash
# Ver proyectos de Firebase
firebase projects:list

# Usar proyecto específico
firebase use mi-agenda-flutter-d4d7d

# Reconfigurar Firebase (si es necesario)
flutterfire configure

# Ejecutar app
flutter run

# Ver logs en tiempo real
flutter logs
```

---

## ⚠️ Troubleshooting

### Error: "EMAIL_NOT_ALLOWED"
**Causa**: Email/Password no está habilitado en Firebase Console  
**Solución**: Sigue los pasos de la sección "Habilitar Email/Password" arriba

### Error: "WEAK_PASSWORD"
**Causa**: Contraseña menor a 6 caracteres  
**Solución**: Firebase requiere mínimo 6 caracteres para contraseñas

### Error: "EMAIL_ALREADY_IN_USE"
**Causa**: El email ya está registrado  
**Solución**: Usa otro email o inicia sesión con el existente

### Error: "INVALID_EMAIL"
**Causa**: Formato de email inválido  
**Solución**: Verifica que el email tenga formato correcto (ej: user@example.com)

---

## 📚 Referencias

- [Firebase Authentication Docs](https://firebase.google.com/docs/auth)
- [FlutterFire Authentication](https://firebase.flutter.dev/docs/auth/usage/)
- [Email/Password Provider](https://firebase.google.com/docs/auth/web/password-auth)
