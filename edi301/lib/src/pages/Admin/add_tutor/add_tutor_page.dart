import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'add_tutor_controller.dart';

class AddTutorPage extends StatefulWidget {
  const AddTutorPage({super.key});

  @override
  State<AddTutorPage> createState() => _AddTutorPageState();
}

class _AddTutorPageState extends State<AddTutorPage> {
  final AddTutorController c = AddTutorController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Tutor Externo'),
        backgroundColor: primary,
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Registra a un padre o madre que no cuenta con correo institucional.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),

            const Text(
              'Relación:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ValueListenableBuilder<int>(
              valueListenable: c.idRolSeleccionado,
              builder: (context, rol, _) {
                return Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Papá EDI'),
                        value: 2, // ID Rol Papá
                        groupValue: rol,
                        onChanged: (v) => c.idRolSeleccionado.value = v!,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Mamá EDI'),
                        value: 3, // ID Rol Mamá
                        groupValue: rol,
                        onChanged: (v) => c.idRolSeleccionado.value = v!,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 10),
            TextField(
              controller: c.nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre(s)',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: c.apellidoCtrl,
              decoration: const InputDecoration(
                labelText: 'Apellidos',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: c.correoCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico personal',
                prefixIcon: Icon(Icons.email),
                hintText: 'ejemplo@gmail.com',
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: c.contrasenaCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña temporal',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 30),

            // Botón Guardar
            ValueListenableBuilder<bool>(
              valueListenable: c.loading,
              builder: (_, loading, __) => ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  loading ? 'Guardando...' : 'Crear Tutor',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: loading ? null : () => c.save(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
