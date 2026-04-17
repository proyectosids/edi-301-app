import 'package:flutter/material.dart';
import 'package:edi301/services/familia_api.dart';
import 'dart:async';

class GetFamilyController {
  late BuildContext context;
  final FamiliaApi _familiaApi = FamiliaApi();

  List<dynamic> _allFamilies = [];

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

        families.value = _allFamilies;
      }
    } catch (e) {
      print('Error cargando familias: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String query) {
    if (query.isEmpty) {
      families.value = _allFamilies;
      return;
    }

    final lowerQuery = query.toLowerCase();

    families.value = _allFamilies.where((f) {
      final nombre = (f['nombre_familia'] ?? '').toString().toLowerCase();
      final padres = (f['padres'] ?? '').toString().toLowerCase();

      return nombre.contains(lowerQuery) || padres.contains(lowerQuery);
    }).toList();
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
