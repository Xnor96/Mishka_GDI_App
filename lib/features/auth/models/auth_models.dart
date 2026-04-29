// Refleja exactamente el AuthResponse del backend Go
class AuthResponse {
  final bool   success;
  final String message;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int    expiresIn;
  final String username;
  final String rol;

  AuthResponse({
    required this.success,
    required this.message,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.username,
    required this.rol,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    success:      json['success']       ?? false,
    message:      json['message']       ?? '',
    accessToken:  json['access_token']  ?? '',
    refreshToken: json['refresh_token'] ?? '',
    tokenType:    json['token_type']    ?? 'Bearer',
    expiresIn:    json['expires_in']    ?? 86400,
    username:     json['username']      ?? '',
    rol:          json['rol']           ?? '',
  );
}
