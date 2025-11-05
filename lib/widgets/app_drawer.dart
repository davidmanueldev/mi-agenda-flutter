import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../views/home_screen.dart';
import '../views/list_categories_screen.dart';
import '../views/task_list_screen.dart';
import '../views/templates_screen.dart';
import '../views/pomodoro_screen.dart';
import '../views/pomodoro_history_screen.dart';
import '../views/reports_screen.dart';
import '../views/profile_screen.dart';
import '../views/login_screen.dart';

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
          // Header del drawer con información del usuario
          Consumer<AuthController>(
            builder: (context, authController, child) {
              final user = authController.currentUser;
              final displayName = user?.displayName ?? 'Usuario';
              final email = user?.email ?? '';
              final initials = _getInitials(displayName);

              return UserAccountsDrawerHeader(
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
                currentAccountPicture: CircleAvatar(
                  backgroundColor: colorScheme.onPrimary,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                accountName: Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                accountEmail: Text(
                  email,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            },
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

          // Perfil de usuario
          _buildDrawerTile(
            context,
            icon: Icons.person,
            title: 'Mi Perfil',
            route: 'profile',
            onTap: () => _navigateTo(context, const ProfileScreen()),
          ),

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

          const Divider(),

          // Cerrar sesión
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _handleLogout(context),
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

  /// Obtener iniciales del nombre
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Manejar logout
  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Cerrar drawer
      Navigator.pop(context);
      
      // Logout
      final authController = Provider.of<AuthController>(context, listen: false);
      await authController.logout();

      // Navegar a login
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
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
