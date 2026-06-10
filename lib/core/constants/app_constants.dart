class AppConstants {
  // ── API ──────────────────────────────────────────────────────────
  // Inyectable en build/run con: --dart-define=API_BASE_URL=http://IP:PUERTO
  // Si no se pasa, usa localhost (sirve para emulador iOS / escritorio).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // ── Storage keys ─────────────────────────────────────────────────
  static const String keyAccessToken    = 'access_token';
  static const String keyRefreshToken   = 'refresh_token';
  static const String keyUsername       = 'username';
  static const String keyRol            = 'rol';
  // Historial de "lugares de venta" tipeados por el admin (autocomplete)
  static const String keyLugaresCustom  = 'lugares_venta_custom';
  // Último lugar de venta usado — para preseleccionarlo en la próxima venta
  static const String keyUltimoLugar    = 'ultimo_lugar_venta';
  // Último tipo de pago usado
  static const String keyUltimoPago     = 'ultimo_tipo_pago';
  // Filtro activo de "Lugar" en la pantalla de ventas (para que el form de
  // nueva venta lo preseleccione)
  static const String keyFiltroLugar    = 'filtro_lugar_salidas';

  // ── Categorías ───────────────────────────────────────────────────
  static const Map<int, String> categorias = {
    1: 'ANILLO',
    2: 'ARETE',
    3: 'COLLAR',
    4: 'JUEGO',
    5: 'OTRO',
    6: 'PULSERA',
  };

  // ── Lugares de venta (del Excel) ─────────────────────────────────
  static const List<String> lugaresVenta = [
    'ALL BAZAR',
    'PINKSTORE',
    'PERSONAL',
    'OTRO',
  ];

  // ── Tipos de pago (del Excel) ────────────────────────────────────
  static const List<String> tiposPago = [
    'EFECTIVO',
    'TRANSFERENCIA',
    'CLIP',
    'OTRO',
  ];
}
