// lib/src/pages/Family/family_match_modal.dart
//
// Modal "Elige tu familia" — se muestra al usuario tras registrarse y hacer
// login por primera vez, SI el admin había creado una familia manual cuyos
// padres pendientes matchean con su nombre+apellido. Permite vincularse a
// la familia correcta (en caso de ambigüedad) o saltar para revisarlo luego.
import 'package:flutter/material.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/core/api_error.dart';

class FamilyMatchModal extends StatefulWidget {
  final int idUsuario;
  final List<Map<String, dynamic>> candidatos;
  final FamiliaApi? api;

  const FamilyMatchModal({
    super.key,
    required this.idUsuario,
    required this.candidatos,
    this.api,
  });

  /// Muestra el modal de selección y devuelve `true` si el usuario se vinculó
  /// exitosamente a una familia, `false` si lo saltó o ocurrió un error.
  static Future<bool> show(
    BuildContext context, {
    required int idUsuario,
    required List<Map<String, dynamic>> candidatos,
    FamiliaApi? api,
  }) async {
    if (candidatos.isEmpty) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FamilyMatchModal(
        idUsuario: idUsuario,
        candidatos: candidatos,
        api: api,
      ),
    );
    return result ?? false;
  }

  @override
  State<FamilyMatchModal> createState() => _FamilyMatchModalState();
}

class _FamilyMatchModalState extends State<FamilyMatchModal> {
  late final FamiliaApi _api;
  int? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? FamiliaApi();
  }

  String _rolDeCandidato(Map<String, dynamic> c) {
    // El backend nos manda 'rol_candidato' = 'PAPA' o 'MAMA'.
    final raw = (c['rol_candidato'] ?? '').toString().toUpperCase();
    return raw == 'PAPA' || raw == 'MAMA' ? raw : 'PAPA';
  }

  Future<void> _confirmar() async {
    if (_selected == null) return;
    final candidato = widget.candidatos[_selected!];
    final idFamilia = candidato['id_familia'];
    if (idFamilia == null) return;

    setState(() => _saving = true);
    try {
      await _api.linkUserToFamily(
        idFamilia: idFamilia is int ? idFamilia : int.parse(idFamilia.toString()),
        idUsuario: widget.idUsuario,
        rol: _rolDeCandidato(candidato),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      setState(() => _saving = false);
    }
  }

  void _saltar() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    const primary = Color.fromRGBO(19, 67, 107, 1);
    final candidatos = widget.candidatos;

    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.family_restroom, color: primary),
          SizedBox(width: 8),
          Expanded(child: Text('¿Es esta tu familia?')),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidatos.length == 1
                  ? 'Encontramos una familia que parece corresponderte. '
                    'Confirma si es la tuya para vincularte automáticamente.'
                  : 'Encontramos ${candidatos.length} posibles familias. '
                    'Selecciona la tuya:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidatos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final f = candidatos[i];
                  final nombre = (f['nombre_familia'] ?? 'Familia').toString();
                  final residencia = (f['residencia'] ?? '').toString();
                  final papaPend = [
                    (f['papa_nombre_pendiente'] ?? '').toString(),
                    (f['papa_apellido_pendiente'] ?? '').toString(),
                  ].where((s) => s.isNotEmpty).join(' ');
                  final mamaPend = [
                    (f['mama_nombre_pendiente'] ?? '').toString(),
                    (f['mama_apellido_pendiente'] ?? '').toString(),
                  ].where((s) => s.isNotEmpty).join(' ');

                  return RadioListTile<int>(
                    value: i,
                    groupValue: _selected,
                    onChanged: _saving ? null : (v) => setState(() => _selected = v),
                    title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (papaPend.isNotEmpty) Text('Padre: $papaPend', style: const TextStyle(fontSize: 12)),
                        if (mamaPend.isNotEmpty) Text('Madre: $mamaPend', style: const TextStyle(fontSize: 12)),
                        if (residencia.isNotEmpty) Text('Residencia: $residencia', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _saltar,
          child: const Text('Ninguna / luego'),
        ),
        ElevatedButton.icon(
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
          label: Text(_saving ? 'Vinculando...' : 'Confirmar'),
          onPressed: (_selected == null || _saving) ? null : _confirmar,
          style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}
