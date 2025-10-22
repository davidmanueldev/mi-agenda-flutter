import 'package:flutter/material.dart';

/// AppBar personalizada con diseño consistente
/// Implementa Material Design 3 y mejores prácticas de UI
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final double elevation;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      leading: leading,
      actions: actions,
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
      ),
      // Configuración para diferentes tamaños de pantalla
      toolbarHeight: _getToolbarHeight(context),
    );
  }

  /// Determinar altura de la toolbar basada en el tamaño de pantalla
  double _getToolbarHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Tablets y pantallas grandes
    if (screenWidth > 600) {
      return 64.0;
    }
    
    // Teléfonos
    return kToolbarHeight;
  }

  @override
  Size get preferredSize => Size.fromHeight(_getToolbarHeightStatic());

  /// Versión estática para preferredSize
  double _getToolbarHeightStatic() {
    return kToolbarHeight;
  }
}

/// AppBar con búsqueda integrada
class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String hintText;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;
  final List<Widget>? actions;

  const SearchAppBar({
    super.key,
    required this.title,
    this.hintText = 'Buscar eventos...',
    this.onSearchChanged,
    this.onSearchClear,
    this.actions,
  });

  @override
  State<SearchAppBar> createState() => _SearchAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SearchAppBarState extends State<SearchAppBar> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isSearching) {
      return AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopSearching,
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
          ),
          onChanged: widget.onSearchChanged,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearSearch,
          ),
        ],
      );
    }

    return CustomAppBar(
      title: widget.title,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _startSearching,
          tooltip: 'Buscar eventos',
        ),
        ...?widget.actions,
      ],
    );
  }

  /// Iniciar modo de búsqueda
  void _startSearching() {
    setState(() {
      _isSearching = true;
    });
    
    // Enfocar el campo de búsqueda después del rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  /// Detener modo de búsqueda
  void _stopSearching() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    
    // Notificar que se limpió la búsqueda
    widget.onSearchClear?.call();
    widget.onSearchChanged?.call('');
  }

  /// Limpiar texto de búsqueda
  void _clearSearch() {
    _searchController.clear();
    widget.onSearchChanged?.call('');
  }
}
