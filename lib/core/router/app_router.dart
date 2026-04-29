import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/app_shell.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/productos/screens/productos_screen.dart';
import '../../features/productos/screens/producto_form_screen.dart';
import '../../features/productos/models/producto_models.dart';
import '../../features/entradas/screens/entradas_screen.dart';
import '../../features/entradas/screens/entrada_form_screen.dart';
import '../../features/salidas/screens/salida_form_screen.dart';
import '../../features/salidas/screens/salidas_screen.dart';
import '../../features/control_diario/screens/control_diario_screen.dart';
import '../../features/control_diario/screens/control_diario_form_screen.dart';
import '../../features/resumen_mensual/screens/resumen_mensual_screen.dart';
import '../../features/reportes/screens/reportes_screen.dart';
import '../constants/app_constants.dart';

class AppRouter {
  // ── Constantes de ruta ────────────────────────────────────────────────────
  static const String login          = '/login';
  static const String dashboard      = '/dashboard';
  static const String productos      = '/productos';
  static const String entradas       = '/entradas';
  static const String salidas        = '/salidas';
  static const String controlDiario  = '/control-diario';
  static const String resumenMensual = '/resumen-mensual';
  static const String reportes       = '/reportes';

  static final GoRouter router = GoRouter(
    initialLocation: login,
    redirect: (context, state) async {
      final prefs      = await SharedPreferences.getInstance();
      final token      = prefs.getString(AppConstants.keyAccessToken) ?? '';
      final isLoggedIn = token.isNotEmpty;
      final loc        = state.matchedLocation;

      if (!isLoggedIn && loc != login) return login;
      if (isLoggedIn  && loc == login) return dashboard;
      return null;
    },
    routes: [
      // ── Login: sin shell ─────────────────────────────────────────────────
      GoRoute(
        path: login,
        name: 'login',
        pageBuilder: (context, state) => _fade(state, const LoginScreen()),
      ),

      // ── Shell: sidebar persistente en todas las pantallas principales ────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => _instant(state, const DashboardScreen()),
          ),
          GoRoute(
            path: productos,
            name: 'productos',
            pageBuilder: (context, state) => _instant(state, const ProductosScreen()),
          ),
          GoRoute(
            path: entradas,
            name: 'entradas',
            pageBuilder: (context, state) => _instant(state, const EntradasScreen()),
          ),
          GoRoute(
            path: salidas,
            name: 'salidas',
            pageBuilder: (context, state) => _instant(state, const SalidasScreen()),
          ),
          GoRoute(
            path: controlDiario,
            name: 'controlDiario',
            pageBuilder: (context, state) => _instant(state, const ControlDiarioScreen()),
          ),
          GoRoute(
            path: resumenMensual,
            name: 'resumenMensual',
            pageBuilder: (context, state) => _instant(state, const ResumenMensualScreen()),
          ),
          GoRoute(
            path: reportes,
            name: 'reportes',
            pageBuilder: (context, state) => _instant(state, const ReportesScreen()),
          ),
        ],
      ),

      // ── Formularios: pantalla completa con su propio Scaffold ────────────
      // (fuera del shell para tener AppBar con acciones específicas)
      GoRoute(
        path: '/productos/nuevo',
        name: 'productoNuevo',
        pageBuilder: (context, state) =>
            _slide(state, const ProductoFormScreen()),
      ),
      GoRoute(
        path: '/productos/:id',
        name: 'productoDetalle',
        pageBuilder: (context, state) {
          final extra = state.extra;
          return _slide(
            state,
            ProductoFormScreen(producto: extra is Producto ? extra : null),
          );
        },
      ),

      // P6 — Registrar Entrada (formulario completo fuera del shell)
      GoRoute(
        path: '/entradas/nueva',
        name: 'entradaNueva',
        pageBuilder: (context, state) => _slide(state, const EntradaFormScreen()),
      ),

      // P8 — Registrar Venta (formulario completo fuera del shell)
      GoRoute(
        path: '/salidas/nueva',
        name: 'salidaNueva',
        pageBuilder: (context, state) => _slide(state, const SalidaFormScreen()),
      ),

      // P10a — Registrar Movimiento Diario (formulario fuera del shell)
      GoRoute(
        path: '/control-diario/nuevo',
        name: 'controlDiarioNuevo',
        pageBuilder: (context, state) =>
            _slide(state, const ControlDiarioFormScreen()),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Ruta no encontrada: ${state.uri}',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
  );

  // ── Helpers de transición ─────────────────────────────────────────────────

  /// Sin animación — ideal para cambio de secciones en sidebar.
  static Page<void> _instant(GoRouterState state, Widget child) =>
      NoTransitionPage(key: state.pageKey, child: child);

  /// Fade suave 200ms — para login y vistas principales.
  static Page<void> _fade(GoRouterState state, Widget child) =>
      CustomTransitionPage(
        key: state.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  /// Slide desde derecha — para pantallas de detalle/formulario.
  static Page<void> _slide(GoRouterState state, Widget child) =>
      CustomTransitionPage(
        key: state.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      );
}
