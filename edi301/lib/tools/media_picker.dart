import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaPicker {
  MediaPicker._();

  static final ImagePicker _picker = ImagePicker();

  /// Muestra un bottom sheet para elegir Cámara o Galería
  /// y regresa el XFile (o null si cancelan).
  static Future<XFile?> pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return null;
    if (!context.mounted) return null;

    // image_picker invoca el diálogo nativo de iOS/Android cuando se usa la
    // cámara. No hacemos una petición previa: en iOS esa comprobación puede
    // reportar "denegado" antes de que el sistema muestre el diálogo.
    return _picker.pickImage(source: source, imageQuality: 85);
  }

  /// Abre la galería directamente. En iOS el selector nativo administra el
  /// acceso a fotos; no se solicita permiso total de biblioteca previamente.
  static Future<XFile?> pickFromGallery({
    int imageQuality = 85,
    double? maxWidth,
  }) {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
  }
}
