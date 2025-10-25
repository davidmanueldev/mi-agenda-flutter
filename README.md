# Mi Agenda - Aplicación Flutter con Arquitectura MVC

Una aplicación moderna de agenda personal desarrollada en Flutter siguiendo la arquitectura MVC (Modelo-Vista-Controlador) y utilizando una base de datos híbrida con Firebase Firestore y SQLite para garantizar funcionalidad offline y sincronización en la nube.

## 📋 Características Principales

### ✨ Funcionalidades
- **Gestión de Eventos**: Crear, editar, visualizar y eliminar eventos
- **Calendario Interactivo**: Vista mensual con navegación intuitiva
- **Categorías Personalizadas**: Organización por tipos de eventos (Trabajo, Personal, Salud, etc.)
- **Notificaciones**: Recordatorios automáticos 15 minutos antes del evento
- **Validación de Datos**: Validación robusta de formularios y entrada de datos
- **Interfaz Adaptiva**: Soporte para temas claro y oscuro

### 🏗️ Arquitectura
- **MVC (Model-View-Controller)**: Separación clara de responsabilidades
- **Provider**: Gestión de estado reactiva
- **Inyección de Dependencias**: Servicios desacoplados y testeable
- **Singleton Pattern**: Para servicios de base de datos y notificaciones

## 🛠️ Tecnologías Utilizadas

### Framework y Lenguaje
- **Flutter**: ^3.9.2
- **Dart**: ^3.9.2

### Dependencias Principales
- `provider`: ^6.1.2 - Gestión de estado
- `firebase_core`: ^3.6.0 - Firebase Core
- `cloud_firestore`: ^5.4.3 - Base de datos Firebase Firestore
- `firebase_auth`: ^5.3.1 - Autenticación Firebase
- `sqflite`: ^2.3.3 - Base de datos local SQLite (backup)
- `flutter_local_notifications`: ^17.2.2 - Notificaciones locales
- `table_calendar`: ^3.0.9 - Widget de calendario
- `form_field_validator`: ^1.1.0 - Validación de formularios
- `permission_handler`: ^11.3.1 - Manejo de permisos

## 📱 Estructura del Proyecto

```
lib/
├── controllers/           # Controladores MVC
│   └── event_controller.dart
├── models/               # Modelos de datos
│   ├── event.dart
│   └── category.dart
├── services/             # Servicios de la aplicación
│   ├── database_service.dart         # SQLite (backup)
│   ├── firebase_service.dart         # Firebase Firestore
│   ├── database_service_hybrid.dart  # Servicio híbrido
│   ├── database_interface.dart       # Interfaz común
│   └── notification_service.dart     # Notificaciones locales
├── views/                # Vistas/Pantallas
│   ├── home_screen.dart
│   ├── add_edit_event_screen.dart
│   └── event_detail_screen.dart
├── widgets/              # Widgets reutilizables
│   ├── event_card.dart
│   └── custom_app_bar.dart
├── utils/                # Utilidades y seguridad
│   └── security_utils.dart
└── main.dart            # Punto de entrada
```

## 🔒 Seguridad y Mejores Prácticas

### Validación y Sanitización
- **Sanitización de Entrada**: Limpieza automática de datos maliciosos
- **Validación Robusta**: Validadores personalizados para todos los campos
- **Rate Limiting**: Prevención de spam y abuso
- **IDs Seguros**: Generación criptográficamente segura de identificadores

### Base de Datos Híbrida (Firebase + SQLite)
- **Firebase Firestore**: Base de datos principal en la nube
- **SQLite**: Backup local y funcionamiento offline
- **Sincronización Automática**: Datos siempre actualizados
- **Fallback Inteligente**: Cambio automático a SQLite si Firebase falla
- **Índices Optimizados**: Consultas eficientes en ambas bases
- **Validación de Integridad**: Constraints y validaciones robustas

### Notificaciones
- **Permisos Granulares**: Solicitud explícita de permisos
- **Canales Organizados**: Separación por tipo de notificación
- **Programación Segura**: Validación de horarios futuros

## 🚀 Instalación y Configuración

### Prerrequisitos
- Flutter SDK ^3.9.2
- Dart SDK ^3.9.2
- Android Studio / VS Code
- Dispositivo Android/iOS o Emulador

### Pasos de Instalación

1. **Clonar el proyecto**
   ```bash
   git clone https://github.com/davidmanueldev/mi-agenda-flutter
   cd mi_agenda
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Verificar configuración**
   ```bash
   flutter doctor
   ```

4. **Configurar Firebase (para sincronización en la nube)**
   ```bash
   # Ejecutar script de configuración
   ./scripts/setup_firebase.sh
   
   # O manualmente:
   firebase login
   flutterfire configure --project=tu-proyecto-firebase
   ```

5. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

### Configuración de Permisos

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSNotificationUsageDescription</key>
<string>Esta aplicación necesita enviar notificaciones para recordatorios de eventos</string>
```

## 📖 Uso de la Aplicación

### Pantalla Principal
- **Vista Calendario**: Navegación por meses y selección de fechas
- **Lista de Eventos**: Eventos del día seleccionado
- **FAB**: Botón flotante para agregar nuevos eventos

### Gestión de Eventos
1. **Crear Evento**: 
   - Toca el botón "+" 
   - Completa el formulario con título, descripción, horario y categoría
   - Guarda el evento

2. **Editar Evento**:
   - Toca un evento existente
   - Selecciona el icono de edición
   - Modifica los campos necesarios

3. **Marcar como Completado**:
   - Toca el icono de check en la tarjeta del evento
   - El evento se marca visualmente como completado

### Categorías Predefinidas
- 🏢 **Trabajo**: Eventos laborales
- 👤 **Personal**: Actividades personales  
- ❤️ **Salud**: Citas médicas y bienestar
- 🎓 **Estudio**: Actividades académicas
- 👥 **Social**: Eventos sociales y reuniones

## 🔥 **Configuración de Firebase**

### **Modo Híbrido (Firebase + SQLite)**
La aplicación funciona en **modo híbrido**:
- **Firebase Firestore**: Base de datos principal en la nube
- **SQLite**: Backup local automático
- **Fallback Automático**: Si Firebase falla, usa SQLite transparentemente
- **Sincronización**: Los datos se mantienen sincronizados entre ambas bases

### **Configuración Rápida**
```bash
# 1. Crear proyecto en Firebase Console (ver FIREBASE_SETUP.md)
# 2. Ejecutar configuración automática
./scripts/setup_firebase.sh

# 3. Configurar con FlutterFire CLI
firebase login
flutterfire configure --project=mi-agenda-flutter
```

### **Alternar Modos**
```dart
// Usar solo Firebase (requiere conexión)
databaseService.setUseFirebase(true);

// Usar solo SQLite (modo offline)
databaseService.setUseFirebase(false);
```

**📖 Documentación detallada en:** `FIREBASE_SETUP.md`

## 🔧 Desarrollo y Contribución

### Comandos Útiles

```bash
# Análisis de código
flutter analyze

# Formatear código
flutter format lib/

# Ejecutar pruebas
flutter test

# Generar APK
flutter build apk

# Generar bundle
flutter build appbundle
```

### Arquitectura MVC Implementada

#### Modelos (`models/`)
- Representan las entidades de datos
- Incluyen validación y serialización
- Inmutables con métodos `copyWith()`

#### Vistas (`views/` y `widgets/`)
- Interfaz de usuario reactiva
- Consumidores de Provider para estado
- Widgets reutilizables y modulares

#### Controladores (`controllers/`)
- Lógica de negocio
- Gestión de estado con ChangeNotifier
- Coordinación entre modelos y servicios

#### Servicios (`services/`)
- Acceso a datos (SQLite)
- Funcionalidades del sistema (Notificaciones)
- Patrón Singleton para instancias únicas

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 👨‍💻 Desarrollado por

David Manuel - Especialista en tomar cafécito y escribir código, aveces.