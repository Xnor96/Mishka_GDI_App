import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/providers/dashboard_provider.dart';
import '../../features/productos/providers/productos_provider.dart';
import '../../features/entradas/providers/entradas_provider.dart';
import '../../features/salidas/providers/salidas_provider.dart';
import '../../features/control_diario/providers/control_diario_provider.dart';
import '../../features/reportes/providers/reportes_provider.dart';
import 'app_nav.dart';

/// Shell persistente: sidebar + AppBar se mantienen entre navegaciones.
/// Solo el área de contenido ([child]) cambia al navegar.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _username = prefs.getString(AppConstants.keyUsername) ?? 'Usuario';
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.stockCero),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go(AppRouter.login);
    }
  }

  // ── Título según ruta actual ──────────────────────────────────────────────
  String _titleFor(String loc) {
    if (loc.startsWith('/dashboard'))      return 'Dashboard';
    if (loc.startsWith('/productos'))      return 'Productos';
    if (loc.startsWith('/entradas'))       return 'Entradas';
    if (loc.startsWith('/salidas'))        return 'Ventas / Salidas';
    if (loc.startsWith('/control-diario')) return 'Control Diario';
    if (loc.startsWith('/resumen-mensual'))return 'Resumen Mensual';
    if (loc.startsWith('/reportes'))       return 'Reportes';
    return 'Mishka GDI';
  }

  // ── Acciones del AppBar según ruta ────────────────────────────────────────
  List<Widget> _actionsFor(String loc) {
    if (loc == AppRouter.dashboard) {
      return [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Actualizar dashboard',
          onPressed: () => ref.read(dashboardProvider.notifier).cargar(),
        ),
      ];
    }
    if (loc == AppRouter.productos) {
      final cargado = ref.watch(productosProvider).hasBuscado;
      if (cargado) {
        return [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Recargar productos',
            onPressed: () => ref.read(productosProvider.notifier).cargar(),
          ),
        ];
      }
    }
    if (loc == AppRouter.entradas) {
      return [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Recargar entradas',
          onPressed: () => ref.read(entradasProvider.notifier).cargar(),
        ),
      ];
    }
    if (loc == AppRouter.salidas) {
      return [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Recargar ventas',
          onPressed: () => ref.read(salidasProvider.notifier).cargar(),
        ),
      ];
    }
    if (loc == AppRouter.controlDiario) {
      return [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Recargar control diario',
          onPressed: () => ref.read(controlDiarioProvider.notifier).cargar(),
        ),
      ];
    }
    if (loc == AppRouter.reportes) {
      return [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Recargar reporte',
          onPressed: () {
            final n = ref.read(reportesProvider.notifier);
            n.cargarInventario();
            n.cargarMasVendidos();
            n.cargarValoracion();
          },
        ),
      ];
    }
    return [];
  }

  // ── FAB según ruta ────────────────────────────────────────────────────────
  Widget? _fabFor(String loc) {
    if (loc == AppRouter.productos) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/productos/nuevo'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo', style: TextStyle(color: Colors.white)),
      );
    }
    if (loc == AppRouter.entradas) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/entradas/nueva'),
        backgroundColor: AppColors.colEntradas,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Registrar', style: TextStyle(color: Colors.white)),
      );
    }
    if (loc == AppRouter.salidas) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/salidas/nueva'),
        backgroundColor: AppColors.colSalidas,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva venta', style: TextStyle(color: Colors.white)),
      );
    }
    if (loc == AppRouter.controlDiario) {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/control-diario/nuevo'),
        backgroundColor: AppColors.colControl,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Registrar', style: TextStyle(color: Colors.white)),
      );
    }
    return null;
  }

  // ── Chip de usuario ───────────────────────────────────────────────────────
  Widget _userChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white24,
            child: Text(
              _username.isNotEmpty ? _username[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(_username,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location  = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final sideNav = AppNav(
      currentRoute: location,
      onLogout: _logout,
      username: _username,
    );

    final appBar = AppBar(
      automaticallyImplyLeading: false,
      leading: isDesktop
          ? null
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
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
          Text(_titleFor(location)),
        ],
      ),
      actions: [
        ..._actionsFor(location),
        _userChip(),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        floatingActionButton: _fabFor(location),
        body: Row(
          children: [
            // Sidebar — persiste entre navegaciones
            Container(
              width: 220,
              color: AppColors.textPrimary,
              child: sideNav,
            ),
            // Área de contenido — solo esta parte cambia
            Expanded(child: widget.child),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        drawer: Drawer(
          backgroundColor: AppColors.textPrimary,
          child: sideNav,
        ),
        floatingActionButton: _fabFor(location),
        body: widget.child,
      );
    }
  }
}
