# 🔥 Configuración de Firebase para Mi Agenda

## 📋 **Pasos para Configurar Firebase**

### 1. **Crear Proyecto en Firebase Console**

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Haz clic en **"Crear un proyecto"** o **"Add project"**
3. Ingresa el nombre: `mi-agenda-flutter`
4. Habilita Google Analytics (opcional)
5. Acepta los términos y crea el proyecto

### 2. **Configurar Firestore Database**

1. En el panel izquierdo, ve a **"Firestore Database"**
2. Haz clic en **"Crear base de datos"**
3. Selecciona **"Empezar en modo de prueba"** (para desarrollo)
4. Elige una ubicación (recomendado: `southamerica-east1` para Latinoamérica)

### 3. **Configurar Reglas de Firestore**

Ve a **"Firestore Database"** → **"Reglas"** y usa estas reglas para desarrollo:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Reglas para desarrollo - CAMBIAR EN PRODUCCIÓN
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

**⚠️ IMPORTANTE:** Estas reglas son solo para desarrollo. En producción usar:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Solo usuarios autenticados pueden acceder a sus datos
    match /events/{eventId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
    
    match /categories/{categoryId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
    }
  }
}
```

### 4. **Configurar Authentication**

1. Ve a **"Authentication"** → **"Sign-in method"**
2. Habilita **"Anónimo"** (ya está configurado en la app)
3. Opcionalmente habilita **"Correo electrónico/contraseña"** para futuras mejoras

### 5. **Obtener Configuración para Android**

1. En **"Configuración del proyecto"** → **"General"**
2. Haz clic en **"Agregar app"** → **Android**
3. Ingresa el package name: `com.example.mi_agenda`
4. Descarga `google-services.json`
5. Coloca el archivo en: `android/app/google-services.json`

### 6. **Obtener Configuración para iOS** (Opcional)

1. Haz clic en **"Agregar app"** → **iOS**
2. Ingresa el Bundle ID: `com.example.miAgenda`
3. Descarga `GoogleService-Info.plist`
4. Coloca el archivo en: `ios/Runner/GoogleService-Info.plist`

### 7. **Actualizar firebase_options.dart**

Después de configurar las apps, reemplaza `lib/firebase_options.dart` con las claves reales:

```dart
// Reemplaza estos valores con los de tu proyecto Firebase
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'TU_ANDROID_API_KEY_AQUI',
  appId: 'TU_ANDROID_APP_ID_AQUI',
  messagingSenderId: 'TU_SENDER_ID_AQUI',
  projectId: 'TU_PROJECT_ID_AQUI',
  storageBucket: 'TU_PROJECT_ID_AQUI.appspot.com',
);
```

## 🛠️ **Comandos para Configuración Automática**

### Usando FlutterFire CLI (Recomendado):

```bash
# 1. Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# 2. Autenticar con Firebase
firebase login

# 3. Configurar automáticamente
flutterfire configure --project=mi-agenda-flutter
```

Este comando:
- ✅ Crea `lib/firebase_options.dart` automáticamente
- ✅ Configura Android (`google-services.json`)
- ✅ Configura iOS (`GoogleService-Info.plist`)
- ✅ Actualiza archivos de configuración

## 📱 **Configuración Adicional para Android**

### Actualizar `android/build.gradle.kts`:

```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

### Actualizar `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Agregar esta línea
}
```

## 🔄 **Modo Híbrido (Firebase + SQLite)**

La aplicación está configurada para funcionar en modo híbrido:

- **Firebase**: Base de datos principal en la nube
- **SQLite**: Backup local y funcionamiento offline

### Cambiar entre modos:

```dart
// En main.dart o donde inicialices el servicio
final databaseService = DatabaseServiceHybrid();

// Para usar solo Firebase
databaseService.setUseFirebase(true);

// Para usar solo SQLite (modo offline)
databaseService.setUseFirebase(false);
```

## 🧪 **Probar la Configuración**

1. **Ejecutar la app**:
   ```bash
   flutter run
   ```

2. **Verificar logs**:
   - Busca: `"Usuario autenticado anónimamente"`
   - Si ves errores de Firebase, verificar configuración

3. **Probar funcionalidad**:
   - Crear eventos
   - Verificar en Firebase Console → Firestore → Datos

## 🚨 **Solución de Problemas Comunes**

### Error: "No Firebase App '[DEFAULT]' has been created"
- ✅ Verificar que `Firebase.initializeApp()` se ejecute antes
- ✅ Comprobar `firebase_options.dart` con claves correctas

### Error: "API key not valid"
- ✅ Regenerar claves en Firebase Console
- ✅ Verificar que el package name coincida

### Error de permisos en Firestore
- ✅ Revisar reglas de Firestore
- ✅ Verificar autenticación anónima habilitada

### App funciona offline pero no sincroniza
- ✅ Verificar conexión a internet
- ✅ Comprobar reglas de Firestore
- ✅ Revisar logs de Firebase en debug

## 📊 **Estructura de Datos en Firestore**

### Colección: `events`
```json
{
  "id": "string",
  "title": "string",
  "description": "string",
  "startTime": "timestamp",
  "endTime": "timestamp",
  "category": "string",
  "isCompleted": "boolean",
  "userId": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Colección: `categories`
```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "color": "number",
  "icon": "number",
  "userId": "string",
  "createdAt": "timestamp"
}
```

## 🔒 **Consideraciones de Seguridad**

1. **Nunca hardcodear API keys** en código público
2. **Usar variables de entorno** para configuración sensible
3. **Implementar reglas de Firestore** restrictivas en producción
4. **Considerar autenticación real** para usuarios finales

---

**✅ Una vez completada la configuración, la aplicación funcionará con sincronización en tiempo real en la nube!**
