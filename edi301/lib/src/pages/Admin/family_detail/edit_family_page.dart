// lib/src/pages/Admin/family_detail/edit_family_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/services/members_api.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

class EditFamilyPage extends StatefulWidget {
  final Family family;
  const EditFamilyPage({super.key, required this.family});

  @override
  State<EditFamilyPage> createState() => _EditFamilyPageState();
}

class _EditFamilyPageState extends State<EditFamilyPage> {
  static const _navy = Color.fromRGBO(19, 67, 107, 1);

  final FamiliaApi _familiaApi = FamiliaApi();
  final MembersApi _membersApi = MembersApi();
  final _formKey = GlobalKey<FormState>();
  final ApiHttp _api = ApiHttp();

  late TextEditingController _nombreCtrl;
  late TextEditingController _direccionCtrl;
  String _residencia = 'INTERNA';

  // Padre / Madre
  final TextEditingController _papaSearchCtrl = TextEditingController();
  final TextEditingController _mamaSearchCtrl = TextEditingController();
  Map<String, dynamic>? _selectedPapa;
  Map<String, dynamic>? _selectedMama;
  List<Map<String, dynamic>> _papaResults = [];
  List<Map<String, dynamic>> _mamaResults = [];
  Timer? _papaDebounce;
  Timer? _mamaDebounce;

  // Hijos en casa
  late List<FamilyMember> _hijos;
  final TextEditingController _hijoSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _hijoResults = [];
  Timer? _hijoDebounce;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.family;
    _nombreCtrl = TextEditingController(text: f.familyName);
    _direccionCtrl = TextEditingController(text: f.direccion ?? '');
    _residencia =
        (f.residencia?.toUpperCase().startsWith('INT') ?? true)
            ? 'INTERNA'
            : 'EXTERNA';

    if (f.fatherEmployeeId != null) {
      _selectedPapa = {
        'id_usuario': f.fatherEmployeeId,
        'display': f.fatherName ?? '',
      };
      _papaSearchCtrl.text = f.fatherName ?? '';
    }
    if (f.motherEmployeeId != null) {
      _selectedMama = {
        'id_usuario': f.motherEmployeeId,
        'display': f.motherName ?? '',
      };
      _mamaSearchCtrl.text = f.motherName ?? '';
    }
    _hijos = List<FamilyMember>.from(f.householdChildren);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _papaSearchCtrl.dispose();
    _mamaSearchCtrl.dispose();
    _hijoSearchCtrl.dispose();
    _papaDebounce?.cancel();
    _mamaDebounce?.cancel();
    _hijoDebounce?.cancel();
    super.dispose();
  }

  // ── Search helpers ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _searchUsers(
      String q, String tipo) async {
    if (q.trim().isEmpty) return [];
    try {
      final res = await _api.getJson(
        '/api/usuarios',
        query: {'tipo': tipo, 'q': q.trim()},
      );
      if (res.statusCode >= 400) return [];
      final decoded = jsonDecode(res.body);
      final list = decoded is List
          ? decoded
          : (decoded is Map && decoded['data'] is List)
              ? decoded['data'] as List
              : [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  String _userName(Map<String, dynamic> u) =>
      '${u['Nombre'] ?? u['nombre'] ?? ''} ${u['Apellido'] ?? u['apellido'] ?? ''}'
          .trim();

  int _userId(Map<String, dynamic> u) =>
      (u['IdUsuario'] ?? u['id_usuario'] ?? 0) as int;

  // ── Debounced search triggers ───────────────────────────────────────────────
  void _onPapaSearch(String q) {
    _papaDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _papaResults = [];
        _selectedPapa = null;
      });
      return;
    }
    _papaDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _searchUsers(q, 'EMPLEADO');
      if (mounted) setState(() => _papaResults = r);
    });
  }

  void _onMamaSearch(String q) {
    _mamaDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _mamaResults = [];
        _selectedMama = null;
      });
      return;
    }
    _mamaDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _searchUsers(q, 'EMPLEADO');
      if (mounted) setState(() => _mamaResults = r);
    });
  }

  void _onHijoSearch(String q) {
    _hijoDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _hijoResults = []);
      return;
    }
    _hijoDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _searchUsers(q, 'ALUMNO');
      if (mounted) setState(() => _hijoResults = r);
    });
  }

  // ── Add / remove hijo ───────────────────────────────────────────────────────
  Future<void> _addHijo(Map<String, dynamic> user) async {
    final id = _userId(user);
    if (_hijos.any((h) => h.idUsuario == id)) return;
    try {
      await _membersApi.addMember(
        idFamilia: widget.family.id!,
        idUsuario: id,
        tipoMiembro: 'HIJO',
      );
      final nombre = _userName(user);
      if (mounted) {
        setState(() {
          _hijos.add(FamilyMember(
            idMiembro: 0,
            idUsuario: id,
            fullName: nombre,
            tipoMiembro: 'HIJO',
          ));
          _hijoSearchCtrl.clear();
          _hijoResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$nombre agregado.'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _removeHijo(FamilyMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Quitar hijo?'),
        content: Text('¿Quitar a ${m.fullName} de la familia?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (m.idMiembro != 0) await _membersApi.removeMember(m.idMiembro);
      setState(() => _hijos.removeWhere((h) => h.idUsuario == m.idUsuario));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Quitado correctamente.'),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700));
      }
    }
  }

  // ── Save family basic info ──────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _familiaApi.updateFamily(
        id: widget.family.id!,
        nombreFamilia: _nombreCtrl.text.trim(),
        residencia: _residencia,
        direccion: _direccionCtrl.text.trim().isEmpty
            ? null
            : _direccionCtrl.text.trim(),
        papaId: _selectedPapa?['id_usuario'] as int?,
        mamaId: _selectedMama?['id_usuario'] as int?,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Familia'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: 'Guardar cambios',
                  onPressed: _save,
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Nombre ──────────────────────────────────────────────────────
            _sectionTitle('Nombre de la familia'),
            TextFormField(
              controller: _nombreCtrl,
              decoration: _inputDeco('Nombre', Icons.family_restroom),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 20),

            // ── Residencia ───────────────────────────────────────────────────
            _sectionTitle('Residencia'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'INTERNA',
                    label: Text('Interna'),
                    icon: Icon(Icons.home)),
                ButtonSegment(
                    value: 'EXTERNA',
                    label: Text('Externa'),
                    icon: Icon(Icons.directions_walk)),
              ],
              selected: {_residencia},
              onSelectionChanged: (s) {
                setState(() {
                  _residencia = s.first;
                  // Las familias INTERNAS no tienen dirección externa
                  if (s.first == 'INTERNA') _direccionCtrl.clear();
                });
                _formKey.currentState?.validate();
              },
            ),
            const SizedBox(height: 16),

            // ── Dirección ────────────────────────────────────────────────────
            TextFormField(
              controller: _direccionCtrl,
              decoration: _inputDeco(
                _residencia == 'EXTERNA'
                    ? 'Dirección (requerida para EXTERNA)'
                    : 'Dirección (opcional)',
                Icons.location_on,
              ),
              validator: (v) {
                if (_residencia == 'EXTERNA' &&
                    (v == null || v.trim().length < 5)) {
                  return 'Ingresa la dirección (mín. 5 caracteres) cuando la residencia es EXTERNA';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Padre ────────────────────────────────────────────────────────
            _sectionTitle('Padre'),
            _buildPersonSearch(
              controller: _papaSearchCtrl,
              results: _papaResults,
              selected: _selectedPapa,
              onChanged: _onPapaSearch,
              onSelect: (u) => setState(() {
                _selectedPapa = {
                  'id_usuario': _userId(u),
                  'display': _userName(u),
                };
                _papaSearchCtrl.text = _userName(u);
                _papaResults = [];
              }),
              onClear: () => setState(() {
                _selectedPapa = null;
                _papaSearchCtrl.clear();
                _papaResults = [];
              }),
              hint: 'Buscar por nombre o núm. empleado',
              icon: Icons.man,
            ),
            const SizedBox(height: 20),

            // ── Madre ────────────────────────────────────────────────────────
            _sectionTitle('Madre'),
            _buildPersonSearch(
              controller: _mamaSearchCtrl,
              results: _mamaResults,
              selected: _selectedMama,
              onChanged: _onMamaSearch,
              onSelect: (u) => setState(() {
                _selectedMama = {
                  'id_usuario': _userId(u),
                  'display': _userName(u),
                };
                _mamaSearchCtrl.text = _userName(u);
                _mamaResults = [];
              }),
              onClear: () => setState(() {
                _selectedMama = null;
                _mamaSearchCtrl.clear();
                _mamaResults = [];
              }),
              hint: 'Buscar por nombre o núm. empleado',
              icon: Icons.woman,
            ),
            const SizedBox(height: 24),

            // ── Hijos en casa ─────────────────────────────────────────────────
            _sectionTitle('Hijos en casa / sanguíneos'),
            if (_hijos.isNotEmpty)
              ..._hijos.map(
                (h) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                        radius: 16,
                        child: Icon(Icons.child_care, size: 16)),
                    title: Text(h.fullName),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () => _removeHijo(h),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _hijoSearchCtrl,
              onChanged: _onHijoSearch,
              decoration: _inputDeco(
                  'Agregar hijo por nombre o matrícula', Icons.person_add),
            ),
            if (_hijoResults.isNotEmpty) ...[
              const SizedBox(height: 4),
              Card(
                elevation: 3,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _hijoResults.length,
                    itemBuilder: (_, i) {
                      final u = _hijoResults[i];
                      final mat =
                          u['Matricula'] ?? u['matricula'];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.school),
                        title: Text(_userName(u)),
                        subtitle: mat != null
                            ? Text('Matrícula: $mat',
                                style: const TextStyle(fontSize: 11))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.green),
                          onPressed: () => _addHijo(u),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // ── Guardar ───────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'GUARDANDO...' : 'GUARDAR CAMBIOS'),
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _navy,
            letterSpacing: 0.3,
          ),
        ),
      );

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _navy),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _navy, width: 2),
        ),
      );

  Widget _buildPersonSearch({
    required TextEditingController controller,
    required List<Map<String, dynamic>> results,
    required Map<String, dynamic>? selected,
    required ValueChanged<String> onChanged,
    required ValueChanged<Map<String, dynamic>> onSelect,
    required VoidCallback onClear,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: hint,
            prefixIcon: Icon(icon, color: _navy),
            suffixIcon: selected != null
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: onClear,
                  )
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _navy, width: 2),
            ),
            filled: selected != null,
            fillColor: selected != null ? Colors.blue.shade50 : null,
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 4),
          Card(
            elevation: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final u = results[i];
                  final emp = u['NumEmpleado'] ?? u['num_empleado'];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person),
                    title: Text(_userName(u)),
                    subtitle: emp != null
                        ? Text('Empleado: $emp',
                            style: const TextStyle(fontSize: 11))
                        : null,
                    onTap: () => onSelect(u),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
