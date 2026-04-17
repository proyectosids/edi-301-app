import 'package:flutter/material.dart';
import 'package:edi301/services/users_api.dart';
import 'package:edi301/core/api_error.dart';

class AddTutorController {
  final UsersApi _usersApi = UsersApi();

  final nombreCtrl = TextEditingController();
  final apellidoCtrl = TextEditingController();
  final correoCtrl = TextEditingController();
  final contrasenaCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();

  final idRolSeleccionado = ValueNotifier<int>(2);
  final loading = ValueNotifier<bool>(false);
  final fechaNacimiento = ValueNotifier<DateTime?>(null);
  final mostrarContrasena = ValueNotifier<bool>(false);

  void dispose() {
    nombreCtrl.dispose();
    apellidoCtrl.dispose();
    correoCtrl.dispose();
    contrasenaCtrl.dispose();
    telefonoCtrl.dispose();
    direccionCtrl.dispose();
    idRolSeleccionado.dispose();
    loading.dispose();
    fechaNacimiento.dispose();
    mostrarContrasena.dispose();
  }

  Future<void> seleccionarFecha(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );
    if (picked != null) fechaNacimiento.value = picked;
  }

  String? get fechaFormateada {
    final f = fechaNacimiento.value;
    if (f == null) return null;
    return '${f.year.toString().padLeft(4, '0')}-'
        '${f.month.toString().padLeft(2, '0')}-'
        '${f.day.toString().padLeft(2, '0')}';
  }

  String get fechaDisplay {
    final f = fechaNacimiento.value;
    if (f == null) return 'Seleccionar fecha';
    return '${f.day.toString().padLeft(2, '0')}/'
        '${f.month.toString().padLeft(2, '0')}/'
        '${f.year}';
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
    if (fechaNacimiento.value == null) {
      _snack(context, 'La fecha de nacimiento es obligatoria');
      return;
    }

    loading.value = true;
    try {
      await _usersApi.registerExterno(
        nombre: nombre,
        apellido: apellido,
        email: correo,
        contrasena: contrasena,
        idRol: idRolSeleccionado.value,
        telefono: telefonoCtrl.text.trim(),
        direccion: direccionCtrl.text.trim(),
        fechaNacimiento: fechaFormateada,
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
      _snack(context, friendlyError(e));
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}
