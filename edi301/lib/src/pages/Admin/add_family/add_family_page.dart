import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/search_api.dart';
import 'add_family_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AddFamilyPage extends StatefulWidget {
  const AddFamilyPage({super.key});
  @override
  State<AddFamilyPage> createState() => _AddFamilyPageState();
}

class _AddFamilyPageState extends State<AddFamilyPage> {
  final AddFamilyController c = AddFamilyController();
  final childSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    childSearchCtrl.dispose();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear familia'),
        backgroundColor: primary,
        actions: [
          IconButton(
            tooltip: 'Modo manual (sin usuarios registrados)',
            icon: const Icon(Icons.edit_note),
            onPressed: () => Navigator.of(context).pushNamed('add_family_manual'),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ValueListenableBuilder<String>(
                valueListenable: c.familyNameListenable,
                builder: (_, name, __) => ListTile(
                  leading: const Icon(Icons.family_restroom),
                  title: const Text('Nombre de la familia'),
                  subtitle: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              _employeeSearch(
                label: 'Papá (empleado)',
                ctrl: c.fatherCtrl,
                onChanged: (v) => c.searchEmployee(v, isFather: true),
                resultsListenable: c.fatherResults,
                onPick: c.pickFather,
              ),
              const SizedBox(height: 8),
              _employeeSearch(
                label: 'Mamá (empleado)',
                ctrl: c.motherCtrl,
                onChanged: (v) => c.searchEmployee(v, isFather: false),
                resultsListenable: c.motherResults,
                onPick: c.pickMother,
              ),

              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: c.internalResidenceListenable,
                builder: (_, internal, __) => Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: internal,
                      onChanged: (v) => c.internalResidence = v,
                      title: const Text('Residencia interna'),
                    ),
                    if (!internal)
                      TextField(
                        controller: c.addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dirección (requerida si es Externa)',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 32),
              const Text(
                'Hijos sanguíneos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: childSearchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar alumno por nombre o matrícula',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: c.searchChildByText,
              ),
              ValueListenableBuilder<List<UserMini>>(
                valueListenable: c.childResults,
                builder: (_, list, __) => Column(
                  children: list
                      .take(5)
                      .map(
                        (u) => ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text('${u.nombre} ${u.apellido}'.trim()),
                          subtitle: Text(
                            u.matricula != null
                                ? 'Matrícula: ${u.matricula}'
                                : '',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => c.addChild(u)),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              ValueListenableBuilder<List<UserMini>>(
                valueListenable: c.children,
                builder: (_, kids, __) => Wrap(
                  spacing: 6,
                  runSpacing: -8,
                  children: kids
                      .asMap()
                      .entries
                      .map(
                        (e) => Chip(
                          label: Text(
                            '${e.value.nombre} ${e.value.apellido}'.trim(),
                          ),
                          deleteIcon: const Icon(Icons.close),
                          onDeleted: () => setState(() => c.removeChild(e.key)),
                        ),
                      )
                      .toList(),
                ),
              ),

              const Divider(height: 32),
              // ── Niños sin cuenta ──────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.child_friendly, color: Color(0xFF1A5276), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Niños del hogar sin cuenta',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                    onPressed: () => _showHogarChildDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Para niños pequeños que aún no tienen cuenta en el sistema.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<HogarChildDraft>>(
                valueListenable: c.hogarChildren,
                builder: (_, kids, __) {
                  if (kids.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Ningún niño sin cuenta agregado.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    );
                  }
                  return Column(
                    children: kids.asMap().entries.map((e) {
                      final kid = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFFD6EAF8),
                            child: Icon(Icons.child_care,
                                size: 16, color: Color(0xFF1A5276)),
                          ),
                          title: Text(kid.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          subtitle: kid.fechaNacimiento != null
                              ? Text(
                                  'Nac: ${kid.fechaNacimiento}',
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red, size: 20),
                            onPressed: () =>
                                setState(() => c.removeHogarChild(e.key)),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),
              ValueListenableBuilder<bool>(
                valueListenable: c.loading,
                builder: (_, loading, __) => ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(loading ? 'Guardando...' : 'Guardar'),
                  onPressed: loading ? null : () => c.save(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Muestra un diálogo para capturar nombre, apellido y fecha de nacimiento
  /// de un niño del hogar sin cuenta.
  Future<void> _showHogarChildDialog(BuildContext context) async {
    final nombreCtrl = TextEditingController();
    final apellidoCtrl = TextEditingController();
    DateTime? selectedDate;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.child_care, color: Color(0xFF1A5276)),
              SizedBox(width: 8),
              Text('Agregar niño sin cuenta',
                  style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre(s) *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El nombre es requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: apellidoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Apellido(s) *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El apellido es requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // Selector de fecha de nacimiento
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now()
                            .subtract(const Duration(days: 365 * 5)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDlg(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de nacimiento',
                        prefixIcon: Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        selectedDate != null
                            ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                            : 'Seleccionar (opcional)',
                        style: TextStyle(
                          color: selectedDate != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5276),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                setState(() {
                  c.addHogarChild(HogarChildDraft(
                    nombre:   nombreCtrl.text.trim(),
                    apellido: apellidoCtrl.text.trim(),
                    fechaNacimiento: selectedDate != null
                        ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                        : null,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeeSearch({
    required String label,
    required TextEditingController ctrl,
    required void Function(String) onChanged,
    required ValueListenable<List<UserMini>> resultsListenable,
    required void Function(UserMini) onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: '$label (por nombre o No. empleado)',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: onChanged,
        ),
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: resultsListenable,
          builder: (_, list, __) => Column(
            children: list
                .take(5)
                .map(
                  (u) => ListTile(
                    dense: true,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('${u.nombre} ${u.apellido}'.trim()),
                    subtitle: Text(
                      u.numEmpleado != null
                          ? 'Empleado: ${u.numEmpleado}'
                          : (u.email ?? ''),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => onPick(u),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
