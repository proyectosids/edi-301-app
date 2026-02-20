import 'dart:convert';
import 'dart:io';
import 'package:edi301/core/api_client_http.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:edi301/auth/token_storage.dart';

class FotosApi {
  final ApiHttp _http = ApiHttp();
  final String _baseUrl = '${ApiHttp.baseUrl}/api';
  final TokenStorage _tokenStorage = TokenStorage();

  Future<List<dynamic>> getFotosFamilia(int idFamilia) async {
    try {
      final res = await _http.getJson('/api/fotos/familia/$idFamilia');

      if (res.statusCode == 200) {
        return List<dynamic>.from(jsonDecode(res.body));
      }
      return [];
    } catch (e) {
      print("Error obteniendo galería: $e");
      return [];
    }
  }

  Future<String> _uploadImage(String endpoint, File imageFile) async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw Exception('Token no encontrado. Inicie sesión de nuevo.');
    }

    var uri = Uri.parse('$_baseUrl/$endpoint');
    var request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';

    String fileName = imageFile.path.split('/').last;
    request.files.add(
      await http.MultipartFile.fromPath(
        'foto',
        imageFile.path,
        filename: fileName,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.body;
    } else {
      throw Exception(
        'Error al subir imagen. Código: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<void> uploadProfileImage(File imageFile) async {
    try {
      await _uploadImage('fotos/perfil', imageFile);
      print('Foto de perfil subida exitosamente.');
    } catch (e) {
      print('Error en uploadProfileImage: $e');
      rethrow;
    }
  }

  Future<void> uploadCoverImage(File imageFile) async {
    try {
      await _uploadImage('fotos/portada', imageFile);
      print('Foto de portada subida exitosamente.');
    } catch (e) {
      print('Error en uploadCoverImage: $e');
      rethrow;
    }
  }
}
