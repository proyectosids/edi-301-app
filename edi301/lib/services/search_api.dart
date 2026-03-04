// lib/services/search_api.dart
import 'dart:convert';
import '../core/api_client_http.dart';

class UserMini {
  final int id;
  final String nombre;
  final String apellido;
  final String tipo;
  final int? matricula;
  final int? numEmpleado;
  final String? email;
  final String? fotoPerfil;

  UserMini({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.tipo,
    this.matricula,
    this.numEmpleado,
    this.email,
    this.fotoPerfil,
  });

  factory UserMini.fromJson(Map<String, dynamic> j) => UserMini(
    id: (j['IdUsuario'] ?? j['id'] ?? j['id_usuario'] ?? 0) as int,
    nombre: (j['Nombre'] ?? j['nombre'] ?? '') as String,
    apellido: (j['Apellido'] ?? j['apellido'] ?? '') as String,
    tipo: (j['TipoUsuario'] ?? j['tipo_usuario'] ?? '') as String,
    matricula: _toIntOrNull(j['Matricula'] ?? j['matricula']),
    numEmpleado: _toIntOrNull(j['NumEmpleado'] ?? j['num_empleado']),
    email: (j['E_mail'] ?? j['correo'])?.toString(),
    fotoPerfil: (j['FotoPerfil'] ?? j['foto_perfil'] ?? j['fotoPerfil'])
        ?.toString(),
  );
}

class FamilyMini {
  final int id;
  final String nombre;
  final String? residencia;
  final String? biografia;

  FamilyMini({
    required this.id,
    required this.nombre,
    this.residencia,
    this.biografia,
  });

  factory FamilyMini.fromJson(Map<String, dynamic> j) => FamilyMini(
    id: (j['FamiliaID'] ?? j['id_familia'] ?? j['id'] ?? 0) as int,
    nombre:
        (j['Nombre_Familia'] ?? j['nombre_familia'] ?? j['nombre'] ?? '')
            as String,
    residencia: (j['Residencia'] ?? j['residencia'])?.toString(),
    biografia: (j['Biografia'] ?? j['biografia'])?.toString(),
  );
}

class SearchResult {
  final List<UserMini> alumnos;
  final List<UserMini> empleados;
  final List<FamilyMini> familias;
  final List<UserMini> externos;

  SearchResult({
    required this.alumnos,
    required this.empleados,
    required this.familias,
    required this.externos,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
    alumnos: _parseUsers(j['alumnos']),
    empleados: _parseUsers(j['empleados']),
    familias: _parseFamilies(j['familias']),
    externos: _parseUsers(j['externos']),
  );
}

List<UserMini> _parseUsers(dynamic v) {
  if (v is List) {
    return v
        .map((e) => UserMini.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return const [];
}

List<FamilyMini> _parseFamilies(dynamic v) {
  if (v is List) {
    return v
        .map((e) => FamilyMini.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return const [];
}

class SearchApi {
  final ApiHttp _http = ApiHttp();

  Future<dynamic> _safeGet(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _http.getJson(path, query: query);
      if (res.statusCode >= 400) return const [];
      return jsonDecode(res.body);
    } catch (_) {
      return const [];
    }
  }

  Future<SearchResult> searchAll(String input) async {
    final q = input.trim();
    if (q.isEmpty) {
      return SearchResult(
        alumnos: const [],
        empleados: const [],
        familias: const [],
        externos: const [],
      );
    }

    final isNumeric = RegExp(r'^\d+$').hasMatch(q);
    final alumnosF = _safeGet(
      '/api/usuarios',
      query: {'tipo': 'ALUMNO', 'q': q},
    );
    final empleadosF = _safeGet(
      '/api/usuarios',
      query: {'tipo': 'EMPLEADO', 'q': q},
    );
    final externosF = _safeGet(
      '/api/usuarios',
      query: {'tipo': 'EXTERNO', 'q': q},
    );
    final familiasByMatF = isNumeric
        ? _safeGet(
            '/api/usuarios/familias/by-doc/search',
            query: {'matricula': q},
          )
        : Future.value(const []);
    final familiasByEmpF = isNumeric
        ? _safeGet(
            '/api/usuarios/familias/by-doc/search',
            query: {'numEmpleado': q},
          )
        : Future.value(const []);
    final familiasByNameF = !isNumeric
        ? _safeGet('/api/familias/search', query: {'name': q})
        : Future.value(const []);

    final resps = await Future.wait<dynamic>([
      alumnosF,
      empleadosF,
      familiasByMatF,
      familiasByEmpF,
      familiasByNameF,
      externosF,
    ]);

    List<dynamic> _ensureList(dynamic d) {
      if (d == null) return const [];
      if (d is List) return d;
      if (d is Map && d.containsKey('data') && d['data'] is List) {
        return d['data'] as List;
      }
      if (d is Map && d.containsKey('rows') && d['rows'] is List) {
        return d['rows'] as List;
      }
      if (d is Map && d.values.length == 1 && d.values.first is List) {
        return List.from(d.values.first as List);
      }
      return const [];
    }

    final alumnos = _ensureList(resps[0])
        .map((e) => UserMini.fromJson(Map<String, dynamic>.from(e)))
        .where((u) => u.tipo.toUpperCase() == 'ALUMNO')
        .toList();

    final empleados = _ensureList(resps[1])
        .map((e) => UserMini.fromJson(Map<String, dynamic>.from(e)))
        .where((u) => u.tipo.toUpperCase() == 'EMPLEADO')
        .toList();

    final externos = _ensureList(resps[5])
        .map((e) => UserMini.fromJson(Map<String, dynamic>.from(e)))
        .where((u) => u.tipo.toUpperCase() == 'EXTERNO')
        .toList();

    List<FamilyMini> familias;
    if (isNumeric) {
      final a = _ensureList(
        resps[2],
      ).map((e) => FamilyMini.fromJson(Map<String, dynamic>.from(e))).toList();
      final b = _ensureList(
        resps[3],
      ).map((e) => FamilyMini.fromJson(Map<String, dynamic>.from(e))).toList();
      final map = <int, FamilyMini>{};
      for (final f in [...a, ...b]) map[f.id] = f;
      familias = map.values.toList();
    } else {
      familias = _ensureList(
        resps[4],
      ).map((e) => FamilyMini.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    return SearchResult(
      alumnos: alumnos,
      empleados: empleados,
      familias: familias,
      externos: externos,
    );
  }
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}
