import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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

    final ok = await _ensurePermission(context, source);
    if (!ok) return null;

    return _picker.pickImage(
      source: source,
      imageQuality: 85, // opcional, reduce peso sin destruir calidad
    );
  }

  static Future<bool> _ensurePermission(
    BuildContext context,
    ImageSource source,
  ) async {
    PermissionStatus status;

    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      // Galería / Fotos
      if (Platform.isIOS) {
        status = await Permission.photos.request();
      } else {
        // Android (en 13+ puede usar photo picker sin permiso; aun así intentamos)
        status = await Permission.photos.request();

        // Fallback por si el device/ROM no mapea bien "photos"
        if (!status.isGranted) {
          final s2 = await Permission.storage.request();
          status = s2.isGranted ? s2 : status;
        }
      }
    }

    if (status.isGranted) return true;

    // Si lo negaron permanentemente, mandamos a Settings
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permiso requerido'),
          content: const Text(
            'Para continuar necesitas habilitar el permiso en Ajustes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Abrir Ajustes'),
            ),
          ],
        ),
      );
    } else {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Permiso denegado')));
    }

    return false;
  }
}
