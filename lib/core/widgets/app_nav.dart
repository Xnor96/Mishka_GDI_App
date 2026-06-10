import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Navegación lateral compartida por todas las pantallas principales.
/// [currentRoute] determina cuál ítem aparece resaltado.
/// [onLogout] callback para cerrar sesión (lo maneja cada pantalla).
class AppNav extends StatelessWidget {
  final String  currentRoute;
  final VoidCallback onLogout;
  final String username;

  const AppNav({
    super.key,
    required this.currentRoute,
    required this.onLogout,
    required this.username,
  });

  static const _items = [
    _NavItem(Icons.dashboard_outlined,     'Dashboard',      '/dashboard'),
    _NavItem(Icons.inventory_2_outlined,   'Productos',      '/productos'),
    _NavItem(Icons.arrow_downward_rounded, 'Entradas',       '/entradas'),
    _NavItem(Icons.arrow_upward_rounded,   'Ventas',         '/salidas'),
    _NavItem(Icons.bar_chart_outlined,     'Control Diario', '/control-diario'),
    _NavItem(Icons.calendar_month_outlined,'Resumen Mensual','/resumen-mensual'),
    _NavItem(Icons.analytics_outlined,     'Reportes',       '/reportes'),
  ];

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + IntrinsicHeight: el sidebar conserva el Spacer normal
    // cuando hay espacio suficiente, y se vuelve scrolleable cuando no
    // (por ejemplo, al abrir el teclado en Resumen Mensual).
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // ── Logo ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/mishka.jpeg',
                        height: 52,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Usuario
                  Text(
                    username,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 28),
                  // ── Items ────────────────────────────────────────────
                  ..._items.map((item) => _buildTile(context, item)),
                  const Spacer(),
                  // ── Logout ───────────────────────────────────────────
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white38, size: 20),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    onTap: onLogout,
                    dense: true,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, _NavItem item) {
    // Consideramos activo si la ruta actual empieza con la ruta del ítem
    // (ej: /productos/nuevo también resalta "Productos")
    final isActive = currentRoute == item.route ||
        (item.route != '/dashboard' && currentRoute.startsWith(item.route));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withOpacity(0.28) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isActive ? Colors.white : Colors.white54,
          size: 20,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          // Cierra drawer si está abierto (móvil)
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          if (!isActive) context.go(item.route);
        },
        dense: true,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String   label;
  final String   route;
  const _NavItem(this.icon, this.label, this.route);
}

// ── Widget de layout completo (sidebar + contenido) ───────────────────────────
/// Envuelve cualquier pantalla principal con el sidebar persistente.
/// Uso:
/// ```dart
/// return AppScaffold(
///   currentRoute: '/productos',
///   username: _username,
///   onLogout: _logout,
///   title: 'Productos',
///   actions: [...],
///   floatingActionButton: ...,
///   child: _buildContent(),
/// );
/// ```
class AppScaffold extends StatelessWidget {
  final String       currentRoute;
  final String       username;
  final VoidCallback onLogout;
  final String       title;
  final List<Widget> actions;
  final Widget?      floatingActionButton;
  final Widget       child;

  const AppScaffold({
    super.key,
    required this.currentRoute,
    required this.username,
    required this.onLogout,
    required this.title,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final nav = AppNav(
      currentRoute: currentRoute,
      onLogout: onLogout,
      username: username,
    );

    if (isDesktop) {
      // ── Escritorio: sidebar fijo a la izquierda, sin drawer ────────
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context, showMenuButton: false),
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            Container(width: 220, color: AppColors.textPrimary, child: nav),
            Expanded(child: child),
          ],
        ),
      );
    } else {
      // ── Móvil: drawer + hamburger ───────────────────────────────────
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context, showMenuButton: true),
        drawer: Drawer(
          backgroundColor: AppColors.textPrimary,
          child: nav,
        ),
        floatingActionButton: floatingActionButton,
        body: child,
      );
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, {required bool showMenuButton}) {
    return AppBar(
      leading: showMenuButton
          ? Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/images/mishka.jpeg',
              width: 26,
              height: 26,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      actions: [
        ...actions,
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white24,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(username,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
