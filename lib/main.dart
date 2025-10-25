import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/event_controller.dart';
import 'controllers/task_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/pomodoro_controller.dart';
import 'controllers/template_controller.dart';
import 'services/database_service.dart';
import 'services/database_service_hybrid_v2.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'views/main_screen.dart';

/// Punto de entrada de la aplicación Mi Agenda
/// Implementa arquitectura MVC con inyección de dependencias
void main() async {
  // Asegurar inicialización de widgets
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicios
  await _initializeServices();
  
  runApp(const MiAgendaApp());
}

/// Inicializar servicios antes de ejecutar la aplicación
Future<void> _initializeServices() async {
  try {
    // Verificar integridad de la base de datos local
    final dbService = DatabaseService();
    final isIntegrity = await dbService.checkDatabaseIntegrity();
    
    if (!isIntegrity) {
      debugPrint('⚠️ Base de datos corrupta, reseteando...');
      await dbService.resetDatabase();
      debugPrint('✅ Base de datos reseteada correctamente');
    }
    
    // Inicializar Firebase primero
    await FirebaseService.initialize();
    
    // Inicializar servicio de notificaciones
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    // Crear canales de notificación (Android)
    await notificationService.createNotificationChannels();
  } catch (e) {
    // Manejar errores de inicialización sin bloquear la app
    debugPrint('Error al inicializar servicios: $e');
  }
}

/// Aplicación principal con configuración de tema y providers
class MiAgendaApp extends StatelessWidget {
  const MiAgendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provider para el controlador de eventos con inyección de dependencias
        ChangeNotifierProvider(
          create: (context) => EventController(
            databaseService: DatabaseServiceHybridV2(),
            notificationService: NotificationService(),
          ),
        ),
        // Provider para el controlador de tareas con inyección de dependencias
        ChangeNotifierProvider(
          create: (context) => TaskController(
            databaseService: DatabaseServiceHybridV2(),
            notificationService: NotificationService(),
          ),
        ),
        // Provider para el controlador de categorías
        ChangeNotifierProvider(
          create: (context) => CategoryController(
            databaseService: DatabaseServiceHybridV2(),
          ),
        ),
        // Provider para el controlador de Pomodoro
        ChangeNotifierProvider(
          create: (context) => PomodoroController(
            databaseService: DatabaseServiceHybridV2(),
            notificationService: NotificationService(),
          ),
        ),
        // Provider para el controlador de Templates
        ChangeNotifierProvider(
          create: (context) => TemplateController(
            databaseService: DatabaseServiceHybridV2(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Mi Agenda',
        debugShowCheckedModeBanner: false,
        
        // Configuración de tema con Material Design 3
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        
        // Pantalla inicial con navegación
        home: const MainScreen(),
        
        // Configuración de navegación y rutas
        onGenerateRoute: _generateRoute,
        
        // Configuración de localización (opcional)
        // locale: const Locale('es', 'ES'),
      ),
    );
  }

  /// Configurar tema claro con Material Design 3
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  /// Configurar tema oscuro con Material Design 3
  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
    );
  }

  /// Generar rutas de navegación (para futuras expansiones)
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const MainScreen());
      default:
        return null;
    }
  }
}
