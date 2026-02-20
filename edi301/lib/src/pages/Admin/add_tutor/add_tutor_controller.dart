import 'package:flutter/material.dart';
import 'package:edi301/services/users_api.dart';

class AddTutorController {
  final UsersApi _usersApi = UsersApi();

  final nombreCtrl = TextEditingController();
  final apellidoCtrl = TextEditingController();
  final correoCtrl = TextEditingController();
  final contrasenaCtrl = TextEditingController();

  final idRolSeleccionado = ValueNotifier<int>(2);
  final loading = ValueNotifier<bool>(false);

  void dispose() {
    nombreCtrl.dispose();
    apellidoCtrl.dispose();
    correoCtrl.dispose();
    contrasenaCtrl.dispose();
    idRolSeleccionado.dispose();
    loading.dispose();
  }

  Future<void> save(BuildContext context) async {
    final nombre = nombreCtrl.text.trim();
    final apellido = apellidoCtrl.text.trim();
    final correo = correoCtrl.text.trim();
    final contrasena = contrasenaCtrl.text.trim();

    if (nombre.isEmpty || correo.isEmpty || contrasena.isEmpty) {
      _snack(context, 'Nombre, correo y contraseña son obligatorios');
      return;
    }

    loading.value = true;

    try {
      final result = await _usersApi.registerExterno(
        nombre: nombre,
        apellido: apellido,
        email: correo,
        contrasena: contrasena,
        idRol: idRolSeleccionado.value,
      );

      if (context.mounted) {
        loading.value = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutor externo registrado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      loading.value = false;

      print("Error detectado en Flutter: $e");
      _snack(
        context,
        "Error al registrar: ${e.toString().replaceAll("Exception: ", "")}",
      );
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}
