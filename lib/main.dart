import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/database/database_helper.dart';
import 'core/router/app_router.dart';
import 'core/services/backup_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);
  // Precalentar la conexión SQLite para que la primera navegación no espere
  // el bootstrap. Si falla, la app arranca igual y muestra el error al usar
  // el primer DAO.
  unawaited(DatabaseHelper.instance.db);
  runApp(
    const ProviderScope(
      child: MishkaApp(),
    ),
  );
}

class MishkaApp extends StatefulWidget {
  const MishkaApp({super.key});

  @override
  State<MishkaApp> createState() => _MishkaAppState();
}

class _MishkaAppState extends State<MishkaApp> with WidgetsBindingObserver {
  final _backup = BackupService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backup silencioso cada vez que la app pasa a background o se cierra.
    // 'paused'   = usuario cambió de app o bloqueó pantalla.
    // 'detached' = proceso a punto de ser terminado (raro en Android).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_safeBackup());
    }
  }

  Future<void> _safeBackup() async {
    try {
      await _backup.backup();
    } catch (_) {
      // Fallo silencioso — el backup es best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mishka GDI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
      // Necesario para que DatePicker, TimePicker y otros widgets Material
      // funcionen con locale 'es', 'MX'. Sin esto crashea con
      // "No MaterialLocalizations found" al abrir un DatePickerDialog.
      locale: const Locale('es', 'MX'),
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
