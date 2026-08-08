// lib/src/pages/Admin/add_family/add_family_manual_page.dart
//
// Pantalla para crear familias INGRESANDO LOS NOMBRES A MANO, sin buscar
// usuarios existentes. Útil cuando el cliente quiere preparar la familia
// antes de que los padres se registren — la app los vinculará automáticamente
// (o por confirmación) cuando se registren.
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'add_family_manual_controller.dart';

class AddFamilyManualPage extends StatefulWidget {
  const AddFamilyManualPage({super.key});

  @override
  State<AddFamilyManualPage> createState() => _AddFamilyManualPageState();
}

class _AddFamilyManualPageState extends State<AddFamilyManualPage> {
  final AddFamilyManualController c = AddFamilyManualController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear familia (manual)'),
        backgroundColor: primary,
        actions: [
          IconButton(
            tooltip: 'Ver familias con vinculación pendiente',
            icon: const Icon(Icons.hourglass_top),
            onPressed: () => Navigator.of(context).pushNamed('familias_pendientes'),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Banner informativo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los padres NO necesitan estar registrados. Cuando se '
                        'registren, la app los vinculará a esta familia '
                        'automáticamente si su nombre y apellido coinciden.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              ValueListenableBuilder<String>(
                valueListenable: c.familyNameListenable,
                builder: (_, name, __) => ListTile(
                  leading: const Icon(Icons.family_restroom),
                  title: const Text('Nombre de la familia (autogenerado)'),
                  subtitle: Text(
                    name.isEmpty ? '—' : name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const Divider(height: 32),
              const Text('Datos del Padre',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: c.papaNombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre(s) del Padre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: c.papaApellidoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Apellido(s) del Padre',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const Divider(height: 32),
              const Text('Datos de la Madre',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: c.mamaNombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre(s) de la Madre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: c.mamaApellidoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Apellido(s) de la Madre',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const Divider(height: 32),
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

              const SizedBox(height: 8),
              TextField(
                controller: c.descripcionCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),

              const SizedBox(height: 24),
              ValueListenableBuilder<bool>(
                valueListenable: c.loading,
                builder: (_, loading, __) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(loading ? 'Creando...' : 'Crear familia'),
                    onPressed: loading ? null : () => c.save(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
