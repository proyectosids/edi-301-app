import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/publicaciones_api.dart';
import 'package:edi301/tools/media_picker.dart';

class CreatePostPage extends StatefulWidget {
  final int idUsuario;
  final int? idFamilia;

  const CreatePostPage({Key? key, required this.idUsuario, this.idFamilia})
    : super(key: key);

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _mensajeController = TextEditingController();
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();
  final PublicacionesApi _api = PublicacionesApi();

  bool _esAutoridad = false;
  bool _cargando = false;

  final String _tipoSeleccionado = 'POST';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      final rol = user['nombre_rol'] ?? user['rol'] ?? '';

      if (mounted) {
        setState(() {
          const rolesJefes = [
            'Admin',
            'PapaEDI',
            'MamaEDI',
            'Padre',
            'Madre',
            'Tutor',
          ];
          _esAutoridad = rolesJefes.contains(rol);
        });
      }
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? photo = await MediaPicker.pickImage(context);
    if (photo != null) {
      setState(() => _imagenSeleccionada = File(photo.path));
    }
  }

  Future<void> _enviarPost() async {
    if (_mensajeController.text.isEmpty && _imagenSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Escribe algo o sube una foto")),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      await _api.crearPost(
        idUsuario: widget.idUsuario,
        idFamilia: widget.idFamilia,
        mensaje: _mensajeController.text,
        imagen: _imagenSeleccionada,
        categoria: 'Familiar',
        tipo: _tipoSeleccionado,
      );

      if (mounted) {
        String mensajeExito = _esAutoridad
            ? "¡Publicado correctamente! 🎉"
            : "Publicación enviada a aprobación ⏳";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeExito),
            backgroundColor: _esAutoridad ? Colors.green : Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Publicación"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _mensajeController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "¿Qué quieres compartir hoy?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 20),
            if (_imagenSeleccionada != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _imagenSeleccionada!,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _imagenSeleccionada = null),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _seleccionarImagen,
              icon: const Icon(Icons.photo_library),
              label: const Text("Agregar Foto"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _cargando ? null : _enviarPost,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: _esAutoridad
                    ? Colors.green[600]
                    : Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _esAutoridad ? "PUBLICAR AHORA" : "ENVIAR A APROBACIÓN",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
