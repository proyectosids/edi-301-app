import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/otp_service.dart';
import 'package:edi301/services/users_api.dart';
import 'package:edi301/auth/token_storage.dart';

/// Controlador del flujo "Eliminar mi cuenta" con verificación OTP.
///
/// Pasos:
///   0 → Explicación de la consecuencia + botón para enviar el código.
///   1 → Captura del OTP de 4 dígitos enviado al correo del usuario.
///
/// Tras verificar el código se llama al endpoint DELETE /api/usuarios/me,
/// se borra la sesión local y se redirige a la pantalla de login.
class DeleteAccountController {
  final OtpService _otpService = OtpService();
  final UsersApi _usersApi = UsersApi();
  final TokenStorage _storage = TokenStorage();

  final TextEditingController otpCtrl = TextEditingController();

  final ValueNotifier<int> step = ValueNotifier<int>(0);
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  String _email = '';
  String get email => _email;

  /// Carga el correo del usuario autenticado desde SharedPreferences.
  Future<void> loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null || userJson.isEmpty) return;
    try {
      final start = userJson.indexOf('"correo"');
      if (start >= 0) {
        // Extraer correo de forma simple sin importar dart:convert otra vez.
        final tail = userJson.substring(start);
        final colon = tail.indexOf(':');
        final firstQuote = tail.indexOf('"', colon + 1);
        final secondQuote = tail.indexOf('"', firstQuote + 1);
        if (firstQuote > 0 && secondQuote > firstQuote) {
          _email = tail.substring(firstQuote + 1, secondQuote);
        }
      }
    } catch (_) {}
  }

  void dispose() {
    otpCtrl.dispose();
    step.dispose();
    loading.dispose();
  }

  /// Envía el OTP al correo del usuario.
  Future<void> sendOtp(BuildContext context) async {
    if (_email.isEmpty) {
      _snack(context, 'No se pudo obtener tu correo.');
      return;
    }
    loading.value = true;
    try {
      await _otpService.sendOtp(_email);
      step.value = 1;
      if (context.mounted) {
        _snack(
          context,
          'Te enviamos un código a tu correo. Revisa tu bandeja de entrada.',
          color: Colors.green,
        );
      }
    } catch (e) {
      _snack(
        context,
        'No pudimos enviar el código. Intenta de nuevo en unos segundos.',
      );
    } finally {
      loading.value = false;
    }
  }

  /// Verifica el OTP y, si es válido, desactiva la cuenta y limpia la sesión.
  /// Devuelve `true` si la cuenta fue eliminada con éxito.
  Future<bool> verifyAndDelete(BuildContext context) async {
    final code = otpCtrl.text.trim();
    if (code.isEmpty) {
      _snack(context, 'Ingresa el código de verificación.');
      return false;
    }

    loading.value = true;
    try {
      final valid = await _otpService.verifyOtp(_email, code);
      if (!valid) {
        _snack(context, 'Código incorrecto.');
        return false;
      }

      // OTP correcto: desactivar cuenta en el backend.
      await _usersApi.deleteMyAccount();

      // Limpiar sesión local.
      await _storage.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      await prefs.remove('session_token');
      await prefs.remove('last_fcm_token_sent');

      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _snack(
        context,
        msg.isNotEmpty
            ? 'No se pudo eliminar la cuenta: $msg'
            : 'No se pudo eliminar la cuenta. Intenta de nuevo.',
      );
      return false;
    } finally {
      loading.value = false;
    }
  }

  void _snack(BuildContext context, String msg, {Color? color}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color ?? Colors.red,
      ),
    );
  }
}
