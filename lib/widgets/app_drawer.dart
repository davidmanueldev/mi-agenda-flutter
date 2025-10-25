import 'package:flutter/material.dart';
import '../views/home_screen.dart';
import '../views/list_categories_screen.dart';
import '../views/task_list_screen.dart';
import '../views/templates_screen.dart';
import '../views/pomodoro_screen.dart';
import '../views/pomodoro_history_screen.dart';
import '../views/reports_screen.dart';

/// Drawer compartido de la aplicación
/// Accesible desde todas las pantallas principales
class AppDrawer extends StatelessWidget {
  final String? currentRoute;

  const AppDrawer({
    super.key,
    this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header del drawer con gradiente
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 48,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Mi Agenda',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Organiza tu vida',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // Navegación principal
          _buildDrawerTile(
            context,
            icon: Icons.home,
            title: 'Inicio',
            route: 'home',
            onTap: () => _navigateToHome(context),
          ),
          _buildDrawerTile(
            context,
            icon: Icons.task_alt,
            title: 'Tareas',
            route: 'tasks',
            onTap: () => _navigateTo(context, const TaskListScreen()),
          ),
          _buildDrawerTile(
            context,
            icon: Icons.timer,
            title: 'Pomodoro',
            route: 'pomodoro',
            onTap: () => _navigateTo(context, const PomodoroScreen()),
          ),
          _buildDrawerTile(
            context,
            icon: Icons.history,
            title: 'Historial Pomodoro',
            route: 'pomodoro_history',
            onTap: () => _navigateTo(context, const PomodoroHistoryScreen()),
          ),
          _buildDrawerTile(
            context,
            icon: Icons.bar_chart,
            title: 'Reportes',
            route: 'reports',
            onTap: () => _navigateTo(context, const ReportsScreen()),
          ),

          const Divider(),

          // Configuración y gestión
          _buildDrawerTile(
            context,
            icon: Icons.category,
            title: 'Categorías',
            route: 'categories',
            onTap: () => _navigateTo(context, const ListCategoriesScreen()),
          ),
          _buildDrawerTile(
            context,
            icon: Icons.dashboard_customize,
            title: 'Plantillas',
            route: 'templates',
            onTap: () => _navigateTo(context, const TemplatesScreen()),
          ),

          const Divider(),

          // Configuración
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configuración - Próximamente'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  /// Construir tile del drawer con selección visual
  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required VoidCallback onTap,
  }) {
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: isSelected,
      onTap: isSelected ? () => Navigator.pop(context) : onTap,
    );
  }

  /// Navegar a otra pantalla
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Cerrar drawer
    // Verificar si ya estamos en esa pantalla
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  /// Navegar al inicio
  void _navigateToHome(BuildContext context) {
    Navigator.pop(context); // Cerrar drawer
    // Navegar al inicio, limpiando el stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  /// Mostrar diálogo "Acerca de"
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Mi Agenda',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.calendar_today,
        size: 48,
      ),
      children: [
        const Text(
          'Una aplicación de gestión de eventos y tareas con sincronización en la nube.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Desarrollado con Flutter y Firebase.',
        ),
      ],
    );
  }
}
