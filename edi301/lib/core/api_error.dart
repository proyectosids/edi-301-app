// lib/core/api_error.dart
//
// Utilidad centralizada para convertir respuestas HTTP y excepciones en
// mensajes amigables en español para mostrar al usuario.
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── parseHttpError ──────────────────────────────────────────────────────────
/// Extrae un mensaje legible de una respuesta HTTP.
/// Primero intenta leer el campo 'error' o 'message' del JSON.
/// Si no existe, devuelve un mensaje genérico según el código de estado.
String parseHttpError(http.Response res) {
  return _parse(res.statusCode, res.body);
}

/// Variante para cuando ya tienes el statusCode y el body como String
/// (p.ej. cuando se usó StreamedResponse).
String parseStreamError(int statusCode, String body) {
  return _parse(statusCode, body);
}

String _parse(int statusCode, String body) {
  // 1. Intentar extraer campo 'error' o 'message' del JSON del servidor
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final msg = decoded['error'] ?? decoded['message'] ?? decoded['msg'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString().trim();
      }
    }
  } catch (_) {}

  // 2. Fallback según código HTTP
  switch (statusCode) {
    case 400:
      return 'Datos inválidos. Verifica la información ingresada.';
    case 401:
      return 'Correo o contraseña incorrectos.';
    case 403:
      return 'No tienes permisos para realizar esta acción.';
    case 404:
      return 'No se encontró el recurso solicitado.';
    case 409:
      return 'Ya existe un registro con esos datos.';
    case 422:
      return 'Los datos enviados no son válidos.';
    case 429:
      return 'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.';
    case 500:
      return 'Error interno del servidor. Inténtalo más tarde.';
    case 502:
    case 503:
    case 504:
      return 'El servicio no está disponible temporalmente. Inténtalo más tarde.';
    default:
      if (statusCode >= 500) {
        return 'Error del servidor. Inténtalo más tarde.';
      }
      return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }
}

// ─── friendlyError ───────────────────────────────────────────────────────────
/// Limpia un objeto Exception para mostrarlo directamente al usuario.
/// Elimina prefijos técnicos y detecta errores de red.
String friendlyError(dynamic e) {
  final raw = e.toString();

  // Errores de conectividad / red
  if (raw.contains('SocketException') ||
      raw.contains('Connection refused') ||
      raw.contains('Network is unreachable') ||
      raw.contains('Failed host lookup') ||
      raw.contains('No route to host')) {
    return 'Sin conexión. Verifica tu internet e inténtalo de nuevo.';
  }
  if (raw.contains('TimeoutException') || raw.contains('timed out')) {
    return 'La solicitud tardó demasiado. Verifica tu conexión e inténtalo de nuevo.';
  }
  if (raw.contains('HandshakeException') || raw.contains('CERTIFICATE_VERIFY_FAILED')) {
    return 'Error de seguridad en la conexión. Contacta al soporte.';
  }

  // Limpiar prefijos técnicos de Dart
  return raw
      .replaceAll('Exception: ', '')
      .replaceAll('FormatException: ', 'Formato inválido: ')
      .trim();
}
