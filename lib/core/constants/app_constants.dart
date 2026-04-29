class AppConstants {
  // ── API ──────────────────────────────────────────────────────────
  static const String baseUrl = 'http://localhost:8080';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // ── Storage keys ─────────────────────────────────────────────────
  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUsername     = 'username';
  static const String keyRol          = 'rol';

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
