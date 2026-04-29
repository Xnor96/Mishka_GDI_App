import 'package:flutter/material.dart';

class AppColors {
  // ── Paleta principal — naranja fuego ─────────────────────────────────────
  static const Color primary       = Color(0xFFDA4109); // rgba(218, 65, 9)
  static const Color primaryLight  = Color(0xFFEE521D); // +10% claridad
  static const Color primaryDark   = Color(0xFFA83108); // -20% claridad
  static const Color accent        = Color(0xFFFFB300); // ámbar dorado (cálido)

  // ── Fondos ────────────────────────────────────────────────────────────────
  static const Color background    = Color(0xFFFFFBF8); // blanco cálido suave
  static const Color surface       = Color(0xFFFEFFFF); // rgba(254, 255, 255)
  static const Color surfaceVariant= Color(0xFFFCEAE0); // naranja muy tenue

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color textHint      = Color(0xFFAAAAAA);

  // ── Semáforo de stock (semántico — no se cambian) ─────────────────────────
  static const Color stockOk   = Color(0xFF2E7D32); // verde
  static const Color stockBajo = Color(0xFFF57C00); // naranja
  static const Color stockCero = Color(0xFFC62828); // rojo

  // ── Módulos ───────────────────────────────────────────────────────────────
  // Todos dentro de la familia naranja-rojo, diferenciados por tono/oscuridad
  static const Color colProductos = Color(0xFFDA4109); // naranja-rojo base
  static const Color colEntradas  = Color(0xFF3D7A4F); // verde oscuro cálido (entradas = ingreso de stock)
  static const Color colSalidas   = Color(0xFFC13B08); // rojo-naranja oscuro (ventas = salida)
  static const Color colControl   = Color(0xFF7A3520); // marrón cálido (control diario)
  static const Color colReportes  = Color(0xFF9C2E06); // naranja muy oscuro (reportes)
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary:   AppColors.primary,
      secondary: AppColors.accent,
      surface:   AppColors.surface,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.surface, // rgba(254,255,255) sobre naranja
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.surface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0D5CF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0D5CF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.stockCero),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textHint),
    ),

    // Botón primario
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Texto
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, color: AppColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12, color: AppColors.textSecondary,
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
        color: Color(0xFFEDE0D8), thickness: 1),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
