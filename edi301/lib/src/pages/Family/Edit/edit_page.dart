import 'dart:io';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/src/pages/Family/Edit/edit_controller.dart';
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';

class EditPage extends StatefulWidget {
  final int familyId;
  const EditPage({super.key, required this.familyId});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  String? _currentProfileUrl;
  String? _currentCoverUrl;
  final String _baseUrl = ApiHttp.baseUrl;

  final EditController _controller = EditController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context, widget.familyId, _loadData);
    });
  }

  void _loadData(Family? family) {
    if (family != null) {
      setState(() {
        _currentProfileUrl = family.fotoPerfilUrl;
        _currentCoverUrl = family.fotoPortadaUrl;
      });
    }
  }

  String _buildUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    // Corrige slashes dobles si existen
    return '$_baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        title: const Text('Editar Perfil'),
      ),
      body: ResponsiveContent(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Foto del perfil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _controller.selectProfileImage(),
                      child: const Text(
                        'Editar',
                        style: TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              ValueListenableBuilder<XFile?>(
                valueListenable: _controller.profileImage,
                builder: (context, newImage, child) {
                  return CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    child: ClipOval(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: _buildProfileImage(newImage),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Foto de portada',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _controller.selectCoverImage(),
                      child: const Text(
                        'Editar',
                        style: TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 200,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ValueListenableBuilder<XFile?>(
                      valueListenable: _controller.coverImage,
                      builder: (context, newImage, child) {
                        return _buildCoverImage(newImage);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Descripción',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller.descripcionCtrl,
                      maxLines: 5,
                      maxLength: 500,
                      onChanged: (value) =>
                          _controller.descripcionModificada.value = true,
                      decoration: InputDecoration(
                        hintText: 'Escribe una descripción para tu familia...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color.fromRGBO(245, 188, 6, 1),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _controller.isLoading,
                  builder: (context, loading, child) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: loading
                          ? null
                          : () => _controller.saveChanges(),
                      child: loading
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            )
                          : const Text(
                              'Guardar Cambios',
                              style: TextStyle(fontSize: 18),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(XFile? newImage) {
    if (newImage != null) {
      return Image.file(File(newImage.path), fit: BoxFit.cover);
    }

    final url = _buildUrl(_currentProfileUrl);
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/img/los-24-mandamientos-de-la-familia-feliz-lg.jpg',
            fit: BoxFit.cover,
          );
        },
      );
    }

    return Image.asset(
      'assets/img/los-24-mandamientos-de-la-familia-feliz-lg.jpg',
      fit: BoxFit.cover,
    );
  }

  Widget _buildCoverImage(XFile? newImage) {
    if (newImage != null) {
      return Image.file(
        File(newImage.path),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      );
    }

    final url = _buildUrl(_currentCoverUrl);
    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/img/familia-extensa-e1591818033557.jpg',
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          );
        },
      );
    }

    return Image.asset(
      'assets/img/familia-extensa-e1591818033557.jpg',
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
    );
  }
}
