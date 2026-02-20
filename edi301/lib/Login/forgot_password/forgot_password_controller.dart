import 'package:edi301/services/users_api.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/otp_service.dart';

class ForgotPasswordController {
  final OtpService _otpService = OtpService();
  final UsersApi _usersApi = UsersApi();

  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  final step = ValueNotifier<int>(0);
  final loading = ValueNotifier<bool>(false);

  void dispose() {
    emailCtrl.dispose();
    otpCtrl.dispose();
    passCtrl.dispose();
    step.dispose();
    loading.dispose();
  }

  Future<void> sendOtp(BuildContext context) async {
    if (emailCtrl.text.trim().isEmpty) {
      _snack(context, 'Ingresa tu correo');
      return;
    }
    loading.value = true;
    try {
      await _otpService.sendOtp(emailCtrl.text.trim());
      step.value = 1; // Pasar a validar OTP
    } catch (e) {
      _snack(context, 'Error al enviar código. Verifica tu correo.');
    } finally {
      loading.value = false;
    }
  }

  Future<void> verifyOtp(BuildContext context) async {
    if (otpCtrl.text.trim().isEmpty) {
      _snack(context, 'Ingresa el código');
      return;
    }
    loading.value = true;
    try {
      final valid = await _otpService.verifyOtp(
        emailCtrl.text.trim(),
        otpCtrl.text.trim(),
      );
      if (valid) {
        step.value = 2;
      } else {
        _snack(context, 'Código incorrecto');
      }
    } catch (e) {
      _snack(context, 'Error al verificar código');
    } finally {
      loading.value = false;
    }
  }

  Future<void> updatePassword(BuildContext context) async {
    if (passCtrl.text.trim().length < 6) {
      _snack(context, 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    loading.value = true;
    try {
      final success = await _usersApi.resetPassword(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
      );

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contraseña actualizada con éxito',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _snack(context, 'Error al actualizar la base de datos');
      }
    } catch (e) {
      _snack(context, 'Error de servidor');
    } finally {
      loading.value = false;
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}
