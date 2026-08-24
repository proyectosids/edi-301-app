import 'package:flutter/material.dart';
import 'package:edi301/services/familia_api.dart';
import 'dart:async';

class GetFamilyController {
  late BuildContext context;
  final FamiliaApi _familiaApi = FamiliaApi();

  List<dynamic> _allFamilies = [];
  String _query = '';
  String residenceFilter = 'TODAS';
  String studentFilter = 'TODOS';
  String capacityFilter = 'TODAS';

  ValueNotifier<List<dynamic>> families = ValueNotifier([]);
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(BuildContext context) async {
    this.context = context;
    await loadFamilies();
  }

  Future<void> loadFamilies() async {
    isLoading.value = true;
    try {
      final data = await _familiaApi.getAvailable();
      if (data != null) {
        _allFamilies = List<dynamic>.from(data);

        _applyFilters();
      }
    } catch (e) {
      print('Error cargando familias: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String query) {
    _query = query.trim().toLowerCase();
    _applyFilters();
  }

  void updateFilters({String? residence, String? student, String? capacity}) {
    if (residence != null) residenceFilter = residence;
    if (student != null) studentFilter = student;
    if (capacity != null) capacityFilter = capacity;
    _applyFilters();
  }

  void clearFilters() {
    residenceFilter = 'TODAS';
    studentFilter = 'TODOS';
    capacityFilter = 'TODAS';
    _applyFilters();
  }

  int get activeFilterCount => [
    residenceFilter != 'TODAS',
    studentFilter != 'TODOS',
    capacityFilter != 'TODAS',
  ].where((active) => active).length;

  void _applyFilters() {
    families.value = _allFamilies.where((f) {
      final nombre = (f['nombre_familia'] ?? '').toString().toLowerCase();
      final padres = (f['padres'] ?? '').toString().toLowerCase();
      if (_query.isNotEmpty &&
          !nombre.contains(_query) &&
          !padres.contains(_query)) {
        return false;
      }

      final residencia = (f['tipo_residencia'] ?? f['residencia'] ?? '')
          .toString()
          .toUpperCase();
      if (residenceFilter == 'INTERNA' && !residencia.startsWith('INT')) {
        return false;
      }
      if (residenceFilter == 'EXTERNA' && !residencia.startsWith('EXT')) {
        return false;
      }

      final colivi = _asInt(f['num_colivi']);
      final universitarios = _asInt(f['num_universitarios']);
      if (studentFilter == 'COLIVI' && colivi == 0) return false;
      if (studentFilter == 'UNIVERSITARIOS' && universitarios == 0) {
        return false;
      }

      final total = _asInt(f['num_alumnos']);
      final limite = _asInt(f['limite_hijos_edi'], fallback: 7);
      final llena =
          f['esta_llena'] == true || f['esta_llena'] == 1 || total >= limite;
      if (capacityFilter == 'LLENAS' && !llena) return false;
      if (capacityFilter == 'DISPONIBLES' && llena) return false;
      return true;
    }).toList();
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  Future<void> goToDetail(dynamic familia) async {
    await Navigator.pushNamed(
      context,
      'family_detail',
      arguments: familia['id_familia'],
    );
    // Recargar siempre al volver para reflejar ediciones, desactivaciones o eliminaciones
    await loadFamilies();
  }
}
