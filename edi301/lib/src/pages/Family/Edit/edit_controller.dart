import 'dart:convert';
import 'dart:io';
import 'package:edi301/auth/token_storage.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edi301/tools/media_picker.dart';
import 'package:edi301/core/api_error.dart';

class EditController {
  BuildContext? context;
  int? familyId;

  final ImagePicker _picker = ImagePicker();
  final FamiliaApi _familiaApi = FamiliaApi();
  final TokenStorage _tokenStorage = TokenStorage();

  ValueNotifier<XFile?> profileImage = ValueNotifier(null);
  ValueNotifier<XFile?> coverImage = ValueNotifier(null);
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  final TextEditingController descripcionCtrl = TextEditingController();
  ValueNotifier<bool> descripcionModificada = ValueNotifier(false);

  late void Function(Family? family) _onDataLoadedCallback;

  Future<void> init(
    BuildContext context,
    int familyId,
    void Function(Family? family) loadData,
  ) async {
    this.context = context;
    this.familyId = familyId;

    this._onDataLoadedCallback = loadData;

    print('EditController inicializado con familia ID: $familyId');

    if (familyId <= 0) {
      print('ADVERTENCIA: familyId inválido: $familyId');
    }
    await _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    try {
      if (familyId == null) return;

      final token = await _tokenStorage.read();
      if (token == null) return;

      final data = await _familiaApi.getById(familyId!, authToken: token);

      if (data != null) {
        final family = Family.fromJson(data);
        descripcionCtrl.text = family.descripcion ?? '';
        _onDataLoadedCallback(family);

        print('Datos de familia cargados: ${family.familyName}');
      } else {
        _onDataLoadedCallback(null);
        print(' No se encontraron datos para la familia $familyId');
      }
    } catch (e) {
      _onDataLoadedCallback(null);
      print('Error al cargar datos de familia: $e');
    }
  }

  void dispose() {
    profileImage.dispose();
    coverImage.dispose();
    isLoading.dispose();
    descripcionCtrl.dispose();
    descripcionModificada.dispose();
  }

  Future<void> selectProfileImage() async {
    try {
      if (context == null) return;
      final XFile? pickedFile = await MediaPicker.pickImage(context!);
      if (pickedFile != null) profileImage.value = pickedFile;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('No se pudo seleccionar la imagen. Inténtalo de nuevo.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> selectCoverImage() async {
    try {
      if (context == null) return;
      final XFile? pickedFile = await MediaPicker.pickImage(context!);
      if (pickedFile != null) coverImage.value = pickedFile;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('No se pudo seleccionar la imagen. Inténtalo de nuevo.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> saveChanges() async {
    print('Intentando guardar cambios...');
    print('   - familyId: $familyId');
    print('   - profileImage: ${profileImage.value?.path}');
    print('   - coverImage: ${coverImage.value?.path}');

    if (isLoading.value) {
      print('Ya hay una operación en curso');
      return;
    }

    if (familyId == null || familyId! <= 0) {
      print(' Error: familyId es null o inválido: $familyId');
      if (context != null && context!.mounted) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('Error: ID de familia no encontrado')),
        );
      }
      return;
    }

    final hayImagenes = profileImage.value != null || coverImage.value != null;
    final hayDescripcion = descripcionModificada.value;

    if (!hayImagenes && !hayDescripcion) {
      if (context != null && context!.mounted) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('No hay cambios para guardar')),
        );
      }
      return;
    }

    isLoading.value = true;

    try {
      String? token = await _tokenStorage.read();

      if (token == null) {
        print('Token no encontrado');
        if (context != null && context!.mounted) {
          ScaffoldMessenger.of(context!).showSnackBar(
            const SnackBar(
              content: Text('Error: Sesión expirada. Vuelve a iniciar sesión.'),
            ),
          );
        }
        isLoading.value = false;
        return;
      }
      if (hayDescripcion) {
        print('Guardando descripción...');
        await _familiaApi.updateDescripcion(
          familyId: familyId!,
          descripcion: descripcionCtrl.text.trim(),
          authToken: token,
        );
        print('Descripción guardada');
      }

      if (hayImagenes) {
        File? profileFile = profileImage.value != null
            ? File(profileImage.value!.path)
            : null;
        File? coverFile = coverImage.value != null
            ? File(coverImage.value!.path)
            : null;

        print('Guardando imágenes...');

        await _familiaApi.updateFamilyFotos(
          familyId: familyId!,
          profileImage: profileFile,
          coverImage: coverFile,
          authToken: token,
        );

        print('Imágenes guardadas');
      }

      print('Todos los cambios guardados exitosamente');

      if (context != null && context!.mounted) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('¡Cambios guardados con éxito!')),
        );

        Navigator.pop(context!, true); // true → familiy_page recarga los datos
      }
    } catch (e) {
      print('Error al guardar: $e');
      if (context != null && context!.mounted) {
        ScaffoldMessenger.of(
          context!,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700));
      }
    } finally {
      isLoading.value = false;
    }
  }
}
