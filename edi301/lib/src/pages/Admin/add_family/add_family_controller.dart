// lib/src/pages/Admin/add_family/add_family_controller.dart
import 'package:edi301/constants/member_types.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/search_api.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/services/members_api.dart';
import 'package:edi301/core/api_error.dart';
import 'package:flutter/foundation.dart';

/// Modelo temporal para un niño del hogar sin cuenta (pre-guardado en RAM).
class HogarChildDraft {
  final String nombre;
  final String apellido;
  final String? fechaNacimiento; // "yyyy-MM-dd"

  const HogarChildDraft({
    required this.nombre,
    required this.apellido,
    this.fechaNacimiento,
  });

  String get fullName => '$nombre $apellido'.trim();
}

class AddFamilyController {
  static final ValueNotifier<List<Family>> familyList =
      ValueNotifier<List<Family>>([]);

  final ValueNotifier<String> _familyName = ValueNotifier<String>('');
  String get familyName => _familyName.value;
  set familyName(String v) => _familyName.value = v;
  ValueListenable<String> get familyNameListenable => _familyName;

  final ValueNotifier<bool> _internalResidence = ValueNotifier<bool>(true);
  bool get internalResidence => _internalResidence.value;
  set internalResidence(bool v) => _internalResidence.value = v;
  ValueListenable<bool> get internalResidenceListenable => _internalResidence;

  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController fatherCtrl = TextEditingController();
  final TextEditingController motherCtrl = TextEditingController();
  final ValueNotifier<List<UserMini>> fatherResults =
      ValueNotifier<List<UserMini>>([]);
  final ValueNotifier<List<UserMini>> motherResults =
      ValueNotifier<List<UserMini>>([]);
  UserMini? _pickedFather;
  UserMini? _pickedMother;
  final TextEditingController searchChildCtrl = TextEditingController();
  final ValueNotifier<List<UserMini>> childResults =
      ValueNotifier<List<UserMini>>([]);
  final ValueNotifier<List<UserMini>> children = ValueNotifier<List<UserMini>>(
    [],
  );
  final TextEditingController searchUncleCtrl = TextEditingController();
  final ValueNotifier<List<UserMini>> uncleResults =
      ValueNotifier<List<UserMini>>([]);
  final ValueNotifier<List<UserMini>> uncles = ValueNotifier<List<UserMini>>(
    [],
  );

  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  ValueListenable<bool> get loading => _loading;

  // ── Hijos del hogar sin cuenta ──────────────────────────────────────────────
  final ValueNotifier<List<HogarChildDraft>> hogarChildren =
      ValueNotifier<List<HogarChildDraft>>([]);

  void addHogarChild(HogarChildDraft child) {
    hogarChildren.value = [...hogarChildren.value, child];
  }

  void removeHogarChild(int index) {
    final list = [...hogarChildren.value];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      hogarChildren.value = list;
    }
  }

  final _searchApi = SearchApi();
  final _familiaApi = FamiliaApi();
  final _membersApi = MembersApi();

  void dispose() {
    addressCtrl.dispose();
    fatherCtrl.dispose();
    motherCtrl.dispose();
    searchChildCtrl.dispose();
    searchUncleCtrl.dispose();
    fatherResults.dispose();
    motherResults.dispose();
    childResults.dispose();
    children.dispose();
    uncleResults.dispose();
    uncles.dispose();
    hogarChildren.dispose();
    _familyName.dispose();
    _internalResidence.dispose();
    _loading.dispose();
  }

  String _firstSurname(String? fullLastName) {
    if (fullLastName == null) return '';

    final text = fullLastName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';

    final parts = text.split(' ');
    if (parts.isEmpty) return '';

    final lower = parts.map((e) => e.toLowerCase()).toList();

    if (parts.length >= 3 && lower[0] == 'de' && lower[1] == 'la') {
      return '${parts[0]} ${parts[1]} ${parts[2]}';
    }

    if (parts.length >= 3 && lower[0] == 'de' && lower[1] == 'los') {
      return '${parts[0]} ${parts[1]} ${parts[2]}';
    }

    if (parts.length >= 3 && lower[0] == 'de' && lower[1] == 'las') {
      return '${parts[0]} ${parts[1]} ${parts[2]}';
    }

    if (parts.length >= 2 && (lower[0] == 'de' || lower[0] == 'del')) {
      return '${parts[0]} ${parts[1]}';
    }

    return parts.first;
  }

  /// Retorna el segundo apellido (todo lo que queda después del primer apellido).
  /// Ejemplo: "García López" → "López", "de la Cruz Martínez" → "Martínez"
  String _secondSurname(String? fullLastName) {
    if (fullLastName == null) return '';

    final text = fullLastName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';

    final parts = text.split(' ');
    if (parts.length <= 1) return '';

    final lower = parts.map((e) => e.toLowerCase()).toList();

    int firstSurnameLength;
    if (parts.length >= 3 &&
        lower[0] == 'de' &&
        (lower[1] == 'la' || lower[1] == 'los' || lower[1] == 'las')) {
      firstSurnameLength = 3;
    } else if (parts.length >= 2 && (lower[0] == 'de' || lower[0] == 'del')) {
      firstSurnameLength = 2;
    } else {
      firstSurnameLength = 1;
    }

    if (firstSurnameLength >= parts.length) return '';
    return parts.sublist(firstSurnameLength).join(' ');
  }

  void recomputeFamilyName() {
    final hasFather = _pickedFather != null;
    final hasMother = _pickedMother != null;

    String base;

    if (hasFather && hasMother) {
      // Ambos padres: primer apellido de cada uno
      final f = _firstSurname(_pickedFather!.apellido);
      final m = _firstSurname(_pickedMother!.apellido);
      base = [f, m].where((e) => e.trim().isNotEmpty).join(' ');
    } else if (hasFather) {
      // Solo papá: sus dos apellidos
      final f1 = _firstSurname(_pickedFather!.apellido);
      final f2 = _secondSurname(_pickedFather!.apellido);
      base = [f1, f2].where((e) => e.trim().isNotEmpty).join(' ');
    } else if (hasMother) {
      // Solo mamá: sus dos apellidos
      final m1 = _firstSurname(_pickedMother!.apellido);
      final m2 = _secondSurname(_pickedMother!.apellido);
      base = [m1, m2].where((e) => e.trim().isNotEmpty).join(' ');
    } else {
      base = '';
    }

    _familyName.value = base.isEmpty ? '' : 'Familia $base';
  }

  Future<void> searchEmployee(String q, {required bool isFather}) async {
    q = q.trim();
    final target = isFather ? fatherResults : motherResults;

    if (q.isEmpty) {
      target.value = [];
      return;
    }

    final res = await _searchApi.searchAll(q);
    final merged = <int, UserMini>{};
    for (final u in res.empleados) merged[u.id] = u;
    for (final u in res.externos) merged[u.id] = u;
    target.value = merged.values.toList();
  }

  void pickFather(UserMini u) => _pickParent(u, true);
  void pickMother(UserMini u) => _pickParent(u, false);

  void _pickParent(UserMini u, bool isFather) {
    if (isFather) {
      _pickedFather = u;
      fatherCtrl.text = '${u.nombre} ${u.apellido}'.trim();
      fatherResults.value = [];
    } else {
      _pickedMother = u;
      motherCtrl.text = '${u.nombre} ${u.apellido}'.trim();
      motherResults.value = [];
    }
    recomputeFamilyName();
  }

  Future<void> searchChildByText(String q) async {
    q = q.trim();
    if (q.isEmpty) {
      childResults.value = [];
      return;
    }
    final res = await _searchApi.searchAll(q);
    childResults.value = res.alumnos;
  }

  void addChild(UserMini u) {
    final list = [...children.value];
    if (!list.any((x) => x.id == u.id)) {
      list.add(u);
      children.value = list;
    }
  }

  void removeChild(int index) {
    final list = [...children.value];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      children.value = list;
    }
  }

  Future<void> searchUncleByText(String q) async {
    q = q.trim();
    if (q.isEmpty) {
      uncleResults.value = [];
      return;
    }
    final res = await _searchApi.searchAll(q);
    final matches = <int, UserMini>{};
    for (final u in [...res.alumnos, ...res.empleados]) {
      if (!uncles.value.any((selected) => selected.id == u.id))
        matches[u.id] = u;
    }
    uncleResults.value = matches.values.toList();
  }

  void addUncle(UserMini u) {
    if (!uncles.value.any((x) => x.id == u.id)) {
      uncles.value = [...uncles.value, u];
    }
    uncleResults.value = [];
    searchUncleCtrl.clear();
  }

  void removeUncle(int index) {
    final list = [...uncles.value];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      uncles.value = list;
    }
  }

  Future<void> save(BuildContext context) async {
    _loading.value = true;
    try {
      final isInternal = _internalResidence.value;
      final direccion = isInternal ? null : addressCtrl.text.trim();

      if (!isInternal && (direccion == null || direccion.isEmpty)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La dirección es requerida para residencia EXTERNA',
              ),
            ),
          );
        }
        return;
      }
      if (_pickedFather == null && _pickedMother == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona al menos Papá o Mamá')),
          );
        }
        return;
      }
      final hijosIds = children.value.map((kid) => kid.id).toList();
      final tiosIds = uncles.value.map((tio) => tio.id).toList();
      final created = await _familiaApi.createFamily(
        nombreFamilia: _familyName.value.trim().isEmpty
            ? 'Familia'
            : _familyName.value.trim(),
        residencia: isInternal ? 'INTERNA' : 'EXTERNA',
        direccion: direccion,
        papaId: _pickedFather?.id,
        mamaId: _pickedMother?.id,
        hijos: hijosIds,
        tios: tiosIds,
      );

      // ── Crear hijos del hogar sin cuenta ───────────────────────────────────
      if (hogarChildren.value.isNotEmpty && created.id != null) {
        for (final draft in hogarChildren.value) {
          try {
            await _familiaApi.createHogarChild(
              idFamilia: created.id!,
              nombre: draft.nombre,
              apellido: draft.apellido,
              fechaNacimiento: draft.fechaNacimiento,
            );
          } catch (e) {
            // No cancelar el flujo si uno falla — seguir con los demás
            debugPrint('Error creando hijo hogar: $e');
          }
        }
      }

      final withNames = created.copyWith(
        fatherName: _pickedFather == null
            ? null
            : '${_pickedFather!.nombre} ${_pickedFather!.apellido}'.trim(),
        motherName: _pickedMother == null
            ? null
            : '${_pickedMother!.nombre} ${_pickedMother!.apellido}'.trim(),
      );

      final list = [...AddFamilyController.familyList.value]..add(withNames);
      AddFamilyController.familyList.value = list;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Familia y miembros creados con éxito')),
        );
        Navigator.of(context).pop(true);
      }

      _pickedFather = null;
      _pickedMother = null;
      fatherCtrl.clear();
      motherCtrl.clear();
      addressCtrl.clear();
      children.value = [];
      uncles.value = [];
      hogarChildren.value = [];
      _familyName.value = '';
      _internalResidence.value = true;
      fatherResults.value = [];
      motherResults.value = [];
      childResults.value = [];
      uncleResults.value = [];
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      _loading.value = false;
    }
  }
}
