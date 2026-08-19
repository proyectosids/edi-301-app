import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/api_client_http.dart';

class Evento {
  final int idActividad;
  final String titulo;
  final String? descripcion;
  final DateTime fechaEvento;
  final String? horaEvento;
  final String? imagen;
  final String estadoPublicacion;
  final int? diasAnticipacion;

  Evento({
    required this.idActividad,
    required this.titulo,
    this.descripcion,
    required this.fechaEvento,
    this.horaEvento,
    this.imagen,
    required this.estadoPublicacion,
    this.diasAnticipacion,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      idActividad: json['id_actividad'] ?? json['id_evento'] ?? 0,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? json['mensaje'],
      fechaEvento: json['fecha_evento'] != null
          ? DateTime.parse(json['fecha_evento'].toString())
          : DateTime.now(),
      horaEvento: json['hora_evento'],
      imagen: json['imagen'],
      estadoPublicacion: json['estado_publicacion'] ?? 'Publicada',
      diasAnticipacion: json['dias_anticipacion'],
    );
  }
}

class EventosApi {
  final ApiHttp _http = ApiHttp();

  Future<bool> guardarEvento({
    int? id,
    required String titulo,
    required DateTime fecha,
    String? hora,
    String? descripcion,
    File? imagenFile,
    int diasAnticipacion = 3,
  }) async {
    try {
      final String endpoint = id == null ? '/api/agenda' : '/api/agenda/$id';
      final String method = id == null ? 'POST' : 'PUT';

      final Map<String, String> fields = {
        'titulo': titulo,
        'descripcion': descripcion ?? '',
        'fecha_evento': fecha.toIso8601String(),
        'hora_evento': hora ?? '',
        'dias_anticipacion': diasAnticipacion.toString(),
        'estado_publicacion': 'Publicada',
      };

      List<http.MultipartFile>? files;
      if (imagenFile != null) {
        files = [await http.MultipartFile.fromPath('imagen', imagenFile.path)];
      }

      final streamedResponse = await _http.multipart(
        endpoint,
        method: method,
        fields: fields,
        files: files,
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        print('Error Agenda (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      print('Excepción en guardarEvento: $e');
      return false;
    }
  }

  Future<List<Evento>> listar({int page = 1, int limit = 100}) async {
    try {
      final res = await _http.getJson(
        '/api/agenda',
        query: {'page': page, 'limit': limit},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data
              .map<Evento>((e) => Evento.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (e) {
      print('Error listando eventos: $e');
    }
    return [];
  }

  Future<List<Evento>> listarTodos({int limit = 200}) async {
    final all = <Evento>[];
    var page = 1;
    while (true) {
      final batch = await listar(page: page, limit: limit);
      all.addAll(batch);
      if (batch.length < limit) break;
      page++;
    }
    return all;
  }
}
