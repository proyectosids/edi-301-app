import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/users_api.dart';

class FamilyController {
  BuildContext? context;
  final UsersApi _usersApi = UsersApi();

  Future? init(BuildContext context) {
    this.context = context;
    return null;
  }

  Future<int?> resolveFamilyId() => _resolveFamilyId();

  Future<void> goToEditPage(BuildContext context, {int? familyId}) async {
    if (familyId != null && familyId > 0) {
      Navigator.pushNamed(context, 'edit', arguments: familyId);
      return;
    }

    final id = await _resolveFamilyId();

    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar la familia del usuario.'),
        ),
      );
      return;
    }

    Navigator.pushNamed(context, 'edit', arguments: id);
  }

  Future<int?> _resolveFamilyId() async {
    final cachedId = await _readFamilyIdFromSession();
    if (cachedId != null && cachedId > 0) {
      debugPrint(
        'FamilyController: ID encontrado en sesión local -> $cachedId',
      );
      return cachedId;
    }

    debugPrint(
      'FamilyController: ID no encontrado en sesión, consultando API...',
    );
    return _fetchFamilyIdByDocument();
  }

  Future<int?> _readFamilyIdFromSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('user');
    if (rawUser == null) return null;

    try {
      final dynamic decoded = jsonDecode(rawUser);

      return _extractFamilyId(decoded);
    } catch (e) {
      debugPrint('Error parseando usuario de sesión: $e');
      return null;
    }
  }

  int? _extractFamilyId(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      const keys = [
        'id_familia',
        'familia_id',
        'FamiliaID',
        'idFamilia',
        'familiaId',
      ];
      for (final key in keys) {
        if (data.containsKey(key)) {
          final val = _asInt(data[key]);
          if (val != null && val > 0) return val;
        }
      }

      if (data['familia'] is Map) {
        final nestedId = _asInt(
          data['familia']['id_familia'] ?? data['familia']['id'],
        );
        if (nestedId != null && nestedId > 0) return nestedId;
      }
    }

    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString().toLowerCase();

        if (key.contains('familia') && key.contains('id')) {
          final parsed = _asInt(entry.value);
          if (parsed != null && parsed > 0) return parsed;
        }
      }
      // Búsqueda profunda
      for (final entry in data.values) {
        if (entry is Map || entry is List) {
          final nested = _extractFamilyId(entry);
          if (nested != null) return nested;
        }
      }
    } else if (data is List) {
      for (final item in data) {
        final nested = _extractFamilyId(item);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.toLowerCase() == "null") return null;
      return int.tryParse(value);
    }
    return null;
  }

  Future<int?> _fetchFamilyIdByDocument() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUser = prefs.getString('user');
      if (rawUser == null) return null;

      final Map<String, dynamic> user = Map<String, dynamic>.from(
        jsonDecode(rawUser) as Map,
      );

      final matricula = _asInt(user['matricula'] ?? user['Matricula']);
      final numEmpleado = _asInt(
        user['num_empleado'] ?? user['numEmpleado'] ?? user['NumEmpleado'],
      );

      if (matricula == null && numEmpleado == null) {
        debugPrint('FamilyController: Usuario sin matrícula ni num_empleado.');
        return null;
      }

      final familias = await _usersApi.familiasByDocumento(
        matricula: matricula,
        numEmpleado: numEmpleado,
      );

      if (familias.isEmpty) {
        debugPrint(
          'FamilyController: La API devolvió 0 familias para este usuario.',
        );
        return null;
      }

      debugPrint(
        'FamilyController: Familia encontrada vía API -> ${familias.first.id}',
      );
      return familias.first.id;
    } catch (e) {
      debugPrint('Error fetchFamilyIdByDocument: $e');
      return null;
    }
  }
}
