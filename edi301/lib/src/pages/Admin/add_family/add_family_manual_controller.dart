// lib/src/pages/Admin/add_family/add_family_manual_controller.dart
//
// Controlador del módulo "Familia Manual": crea una familia ingresando los
// nombres de los padres a mano, sin necesidad de que ya estén registrados.
// El nombre_familia se genera con la misma fórmula que el módulo principal
// (ver add_family_controller.dart -> recomputeFamilyName).
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/core/api_error.dart';

class AddFamilyManualController {
  // ── Inputs (texto plano, no se busca en BD) ────────────────────────────────
  final TextEditingController papaNombreCtrl   = TextEditingController();
  final TextEditingController papaApellidoCtrl = TextEditingController();
  final TextEditingController mamaNombreCtrl   = TextEditingController();
  final TextEditingController mamaApellidoCtrl = TextEditingController();
  final TextEditingController addressCtrl      = TextEditingController();
  final TextEditingController descripcionCtrl  = TextEditingController();

  // ── Estado UI ──────────────────────────────────────────────────────────────
  final ValueNotifier<String> _familyName = ValueNotifier<String>('');
  ValueListenable<String> get familyNameListenable => _familyName;
  String get familyName => _familyName.value;

  final ValueNotifier<bool> _internalResidence = ValueNotifier<bool>(true);
  bool get internalResidence => _internalResidence.value;
  set internalResidence(bool v) => _internalResidence.value = v;
  ValueListenable<bool> get internalResidenceListenable => _internalResidence;

  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  ValueListenable<bool> get loading => _loading;

  final FamiliaApi _familiaApi = FamiliaApi();

  AddFamilyManualController() {
    // Recalcular nombre_familia cada vez que cambian apellidos
    papaApellidoCtrl.addListener(_recompute);
    mamaApellidoCtrl.addListener(_recompute);
  }

  void dispose() {
    papaApellidoCtrl.removeListener(_recompute);
    mamaApellidoCtrl.removeListener(_recompute);

    papaNombreCtrl.dispose();
    papaApellidoCtrl.dispose();
    mamaNombreCtrl.dispose();
    mamaApellidoCtrl.dispose();
    addressCtrl.dispose();
    descripcionCtrl.dispose();
    _familyName.dispose();
    _internalResidence.dispose();
    _loading.dispose();
  }

  // ── Lógica de generación del nombre (idéntica al add_family_controller) ───
  String _firstSurname(String? fullLastName) {
    if (fullLastName == null) return '';
    final text = fullLastName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';
    final parts = text.split(' ');
    if (parts.isEmpty) return '';

    final lower = parts.map((e) => e.toLowerCase()).toList();
    if (parts.length >= 3 && lower[0] == 'de' && lower[1] == 'la')  return '${parts[0]} ${parts[1]} ${parts[2]}';
    if (parts.length >= 3 && lower[0] == 'de' && lower[1] == 'los') return '${parts[0]} ${parts[1]} ${parts[2]}';
    if (parts.length >= 3 && lower[0] == 'de' && lower[1] == 'las') return '${parts[0]} ${parts[1]} ${parts[2]}';
    if (parts.length >= 2 && (lower[0] == 'de' || lower[0] == 'del')) return '${parts[0]} ${parts[1]}';
    return parts.first;
  }

  String _secondSurname(String? fullLastName) {
    if (fullLastName == null) return '';
    final text = fullLastName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';
    final parts = text.split(' ');
    if (parts.length <= 1) return '';

    final lower = parts.map((e) => e.toLowerCase()).toList();
    int firstSurnameLength;
    if (parts.length >= 3 && lower[0] == 'de' && (lower[1] == 'la' || lower[1] == 'los' || lower[1] == 'las')) {
      firstSurnameLength = 3;
    } else if (parts.length >= 2 && (lower[0] == 'de' || lower[0] == 'del')) {
      firstSurnameLength = 2;
    } else {
      firstSurnameLength = 1;
    }
    if (firstSurnameLength >= parts.length) return '';
    return parts.sublist(firstSurnameLength).join(' ');
  }

  void _recompute() {
    final hasPapa = papaApellidoCtrl.text.trim().isNotEmpty;
    final hasMama = mamaApellidoCtrl.text.trim().isNotEmpty;

    String base;
    if (hasPapa && hasMama) {
      final f = _firstSurname(papaApellidoCtrl.text);
      final m = _firstSurname(mamaApellidoCtrl.text);
      base = [f, m].where((e) => e.trim().isNotEmpty).join(' ');
    } else if (hasPapa) {
      final f1 = _firstSurname(papaApellidoCtrl.text);
      final f2 = _secondSurname(papaApellidoCtrl.text);
      base = [f1, f2].where((e) => e.trim().isNotEmpty).join(' ');
    } else if (hasMama) {
      final m1 = _firstSurname(mamaApellidoCtrl.text);
      final m2 = _secondSurname(mamaApellidoCtrl.text);
      base = [m1, m2].where((e) => e.trim().isNotEmpty).join(' ');
    } else {
      base = '';
    }

    _familyName.value = base.isEmpty ? '' : 'Familia $base';
  }

  // ── Guardado ───────────────────────────────────────────────────────────────
  Future<void> save(BuildContext context) async {
    final papaNombre   = papaNombreCtrl.text.trim();
    final papaApellido = papaApellidoCtrl.text.trim();
    final mamaNombre   = mamaNombreCtrl.text.trim();
    final mamaApellido = mamaApellidoCtrl.text.trim();

    if (papaNombre.isEmpty && mamaNombre.isEmpty) {
      _snack(context, 'Ingresa al menos el nombre del padre o de la madre');
      return;
    }
    if (papaNombre.isNotEmpty && papaApellido.isEmpty) {
      _snack(context, 'Falta el apellido del padre');
      return;
    }
    if (mamaNombre.isNotEmpty && mamaApellido.isEmpty) {
      _snack(context, 'Falta el apellido de la madre');
      return;
    }

    final isInternal = _internalResidence.value;
    final direccion = isInternal ? null : addressCtrl.text.trim();
    if (!isInternal && (direccion == null || direccion.isEmpty)) {
      _snack(context, 'La dirección es requerida para residencia EXTERNA');
      return;
    }

    _loading.value = true;
    try {
      await _familiaApi.createFamilyManual(
        papaNombre:   papaNombre.isEmpty   ? null : papaNombre,
        papaApellido: papaApellido.isEmpty ? null : papaApellido,
        mamaNombre:   mamaNombre.isEmpty   ? null : mamaNombre,
        mamaApellido: mamaApellido.isEmpty ? null : mamaApellido,
        residencia:   isInternal ? 'INTERNA' : 'EXTERNA',
        direccion:    direccion,
        descripcion:  descripcionCtrl.text.trim().isEmpty ? null : descripcionCtrl.text.trim(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Familia creada manualmente. Quedará vinculada cuando los padres se registren.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      _loading.value = false;
    }
  }

  void _snack(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
