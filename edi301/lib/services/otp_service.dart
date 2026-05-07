import 'dart:convert';
import 'package:http/http.dart' as http;

class OtpService {
  final String _baseUrl = 'https://api-otp.apps.isdapps.uk/api/v1';

  final String _serviceEmail = 'waldir.ozuna@ulv.edu.mx';
  final String _servicePassword = 'wozuna123456.';

  Future<String> _authenticate() async {
    final url = Uri.parse('$_baseUrl/user/login');
    print('Autenticando servicio OTP...');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _serviceEmail,
          'password': _servicePassword,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final token = body['token'].toString();
        print('Token obtenido (Longitud: ${token.length})');
        return token;
      } else {
        print('Error Auth: ${response.body}');
        throw Exception('Fallo la autenticación del servicio OTP.');
      }
    } catch (e) {
      print('Error Conexión Auth: $e');
      rethrow;
    }
  }

  Future<void> sendOtp(String userEmail) async {
    try {
      final token = await _authenticate();
      final url = Uri.parse('$_baseUrl/otp_app/');

      print('Enviando OTP a: $userEmail');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-access-token': token,
        'token': token,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'email': userEmail,
          'subject': 'Verificacion de Email',
          'message': 'Verifica tu email con el codigo de abajo',
          'duration': 1,
        }),
      );

      print('Estatus SendOTP: ${response.statusCode}');

      if (response.statusCode >= 400) {
        print('Error SendOTP Body: ${response.body}');
        try {
          final body = jsonDecode(response.body);
          throw Exception(body['message'] ?? 'Error (${response.statusCode})');
        } catch (_) {
          throw Exception(
            'Error al enviar (${response.statusCode}): ${response.body}',
          );
        }
      }

      print('OTP Enviado con éxito');
    } catch (e) {
      print('Excepción en sendOtp: $e');
      rethrow;
    }
  }

  Future<bool> verifyOtp(String userEmail, String otpCode) async {
    try {
      final token = await _authenticate();

      final url = Uri.parse('$_baseUrl/email_verification/verifyOTP');

      print('Verificando OTP...');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-access-token': token,
        'token': token,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'email': userEmail, 'otp': otpCode}),
      );

      if (response.statusCode == 200) {
        print('Código verificado. Body: ${response.body}');
        try {
          final body = jsonDecode(response.body);
          if (body['verified'] == true) return true;
        } catch (_) {}

        return true;
      }

      print('Código incorrecto o error: ${response.body}');
      return false;
    } catch (e) {
      print('Error VerifyOTP: $e');
      return false;
    }
  }
}
