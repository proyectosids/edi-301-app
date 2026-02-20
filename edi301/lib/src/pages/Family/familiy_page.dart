import 'dart:convert';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/src/pages/Chat/chat_page.dart';
import 'package:edi301/src/pages/Family/chat_family_page.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/src/pages/Family/family_controller.dart';
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:edi301/src/widgets/family_gallery.dart';

class FamiliyPage extends StatefulWidget {
  const FamiliyPage({super.key});

  @override
  State<FamiliyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamiliyPage> {
  final unescape = HtmlUnescape();
  bool mostrarHijos = true;
  final FamilyController _controller = FamilyController();
  final FamiliaApi _familiaApi = FamiliaApi();

  late Future<Family?> _familyFuture;
  late Future<List<dynamic>> _availableFamiliesFuture;

  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _familyFuture = _fetchFamilyData();
    _availableFamiliesFuture = _fetchAvailableFamilies();
  }

  String _absUrl(String raw) {
    if (raw.isEmpty || raw == 'null') return '';
    var s = raw.trim();

    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    s = s.replaceAll('\\', '/');

    final idxPublic = s.indexOf('public/uploads/');
    if (idxPublic != -1) {
      s = s.substring(idxPublic + 'public'.length);
    }

    final idxUploads = s.indexOf('/uploads/');
    if (idxUploads != -1) {
      s = s.substring(idxUploads);
    } else if (s.startsWith('uploads/')) {
      s = '/$s';
    } else if (!s.startsWith('/')) {
      s = '/$s';
    }

    return '${ApiHttp.baseUrl}$s';
  }

  String _pickField(dynamic obj, List<String> keys) {
    if (obj == null) return '';
    for (final k in keys) {
      final v = obj[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
    }
    return '';
  }

  Future<List<dynamic>> _fetchAvailableFamilies() async {
    try {
      final res = await _familiaApi.getAvailable();
      final list = (res ?? []).toList();

      list.sort((a, b) {
        final na = (a['num_alumnos'] ?? 0) as int;
        final nb = (b['num_alumnos'] ?? 0) as int;
        return na.compareTo(nb);
      });

      return list;
    } catch (_) {
      return [];
    }
  }

  void _startChat(int idUsuario, String nombre) async {
    final idSala = await ChatApi().initPrivateChat(idUsuario);
    if (idSala != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(idSala: idSala, nombreChat: nombre),
        ),
      );
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      setState(() {
        _userRole = user['nombre_rol'] ?? user['rol'] ?? '';
      });
    }
  }

  Future<Family?> _fetchFamilyData() async {
    try {
      final int? familyId = await _controller.resolveFamilyId();
      if (familyId == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final String? authToken = prefs.getString('token');

      final data = await _familiaApi.getById(familyId, authToken: authToken);
      if (data != null) return Family.fromJson(data);
      return null;
    } catch (e) {
      print('Error al cargar familia: $e');
      return null;
    }
  }

  void _mostrarDetallesRapidos(BuildContext context, dynamic familia) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final int numAlumnos = familia['num_alumnos'] ?? 0;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (familia['nombre_familia'] ?? '').toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text(
                "Descripción:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                (familia['descripcion'] ??
                        "Esta familia aún no tiene una descripción pública.")
                    .toString(),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(Icons.people, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Capacidad actual: $numAlumnos de 10 alumnos"),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  ),
                  child: const Text(
                    "Cerrar",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFullScreen(BuildContext context, ImageProvider image, String tag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImagePage(imageProvider: image, heroTag: tag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        elevation: 0,
        title: const Text("Mi Familia", style: TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FutureBuilder<Family?>(
        future: _familyFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return FloatingActionButton(
              onPressed: () {
                final familyData = snapshot.data!;
                final id = familyData.id ?? 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatFamilyPage(
                      idFamilia: id,
                      nombreFamilia: familyData.familyName,
                    ),
                  ),
                );
              },
              backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
              child: const Icon(Icons.chat, color: Colors.black),
            );
          }
          return const SizedBox();
        },
      ),
      body: ResponsiveContent(
        child: FutureBuilder<Family?>(
          future: _familyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data == null) {
              return _buildNoFamilyState();
            }

            final family = snapshot.data!;

            final coverUrlRaw = (family.fotoPortadaUrl ?? '').toString();
            final profileUrlRaw = (family.fotoPerfilUrl ?? '').toString();

            final coverAbs = _absUrl(coverUrlRaw);
            final profileAbs = _absUrl(profileUrlRaw);

            final ImageProvider coverImage = coverAbs.isNotEmpty
                ? NetworkImage(coverAbs)
                : const AssetImage(
                    'assets/img/familia-extensa-e1591818033557.jpg',
                  );

            final ImageProvider profileImage = profileAbs.isNotEmpty
                ? NetworkImage(profileAbs)
                : const AssetImage(
                    'assets/img/los-24-mandamientos-de-la-familia-feliz-lg.jpg',
                  );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 200,
                    child: FamilyWidget(
                      backgroundImage: coverImage,
                      circleImage: profileImage,
                      canOpenCover: coverAbs.isNotEmpty,
                      canOpenProfile: profileAbs.isNotEmpty,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FamilyData(
                      familyName: family.familyName,
                      numChildres:
                          (family.householdChildren.length +
                                  family.assignedStudents.length)
                              .toString(),
                      text: 'Hijos EDI',
                      description:
                          family.descripcion ??
                          'Añade una descripción en "Editar Perfil".',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (![
                    'Hijo',
                    'HijoEDI',
                    'ALUMNO',
                    'Estudiante',
                  ].contains(_userRole))
                    _bottomEditProfile(),
                  const SizedBox(height: 10),
                  _buildToggleButtons(),
                  const SizedBox(height: 10),
                  mostrarHijos
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _buildHijosList([
                            ...family.householdChildren,
                            ...family.assignedStudents,
                          ]),
                        )
                      : FamilyGallery(idFamilia: family.id ?? 0),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoFamilyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            "Familias Disponibles",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Selecciona una familia para conocer a tus posibles padres y hermanos.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _availableFamiliesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final familias = snapshot.data ?? [];
              if (familias.isEmpty) {
                return const Center(
                  child: Text("No hay familias registradas."),
                );
              }

              return ListView.builder(
                itemCount: familias.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final f = familias[index];
                  final int numAlumnos = f['num_alumnos'] ?? 0;
                  final bool estaLleno = numAlumnos >= 10;

                  final portadaRaw = _pickField(f, [
                    'foto_portada_url',
                    'fotoPortadaUrl',
                    'portada',
                    'foto_portada',
                  ]);

                  final portadaAbs = _absUrl(portadaRaw);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: portadaAbs.isNotEmpty
                              ? () => _openFullScreen(
                                  context,
                                  NetworkImage(portadaAbs),
                                  'portada_${f['id_familia']}',
                                )
                              : null,
                          child: Stack(
                            children: [
                              Hero(
                                tag: 'portada_${f['id_familia']}',
                                child: portadaAbs.isNotEmpty
                                    ? Image.network(
                                        portadaAbs,
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          width: double.infinity,
                                          height: 150,
                                          color: Colors.grey[300],
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.image_not_supported,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: double.infinity,
                                        height: 150,
                                        color: Colors.grey[300],
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                        ),
                                      ),
                              ),
                              if (estaLleno)
                                Container(
                                  height: 150,
                                  color: Colors.black45,
                                  child: const Center(
                                    child: Icon(
                                      Icons.lock,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ListTile(
                          title: Text(
                            (f['nombre_familia'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Padres: ${unescape.convert((f['padres'] ?? '').toString())}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Integrantes: $numAlumnos / 10",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  (f['descripcion'] != null &&
                                          f['descripcion']
                                              .toString()
                                              .isNotEmpty)
                                      ? f['descripcion'].toString()
                                      : "Sin descripción disponible.",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: estaLleno
                              ? const Text(
                                  "LLENO",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    color: Color.fromRGBO(19, 67, 107, 1),
                                  ),
                                  onPressed: () =>
                                      _mostrarDetallesRapidos(context, f),
                                ),
                          onTap: estaLleno ? null : () {},
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bottomEditProfile() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ElevatedButton(
        onPressed: () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final rawUser = prefs.getString('user');
            if (rawUser == null) {
              _controller.goToEditPage(context);
              return;
            }

            final user = jsonDecode(rawUser);
            final dynamic idRaw =
                user['id_familia'] ?? user['idFamilia'] ?? user['FamiliaID'];

            if (idRaw != null &&
                idRaw.toString() != '0' &&
                idRaw.toString() != 'null') {
              final int? id = int.tryParse(idRaw.toString());
              if (id != null) {
                final result = await Navigator.pushNamed(
                  context,
                  'edit',
                  arguments: id,
                );
                if (result == true && mounted) {
                  setState(() {
                    _familyFuture = _fetchFamilyData();
                  });
                }
                return;
              }
            }
            _controller.goToEditPage(context);
          } catch (e) {
            debugPrint('Error crítico al navegar a edición: $e');
          }
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Editar Perfil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildToggleButton('Mis hijos EDI', mostrarHijos, () {
          setState(() => mostrarHijos = true);
        }),
        const SizedBox(width: 10),
        _buildToggleButton('Fotos', !mostrarHijos, () {
          setState(() => mostrarHijos = false);
        }),
      ],
    );
  }

  Widget _buildToggleButton(
    String text,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color.fromARGB(190, 245, 189, 6)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black)),
    );
  }

  Widget _buildHijosList(List<FamilyMember> hijos) {
    if (hijos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('No hay hijos EDI registrados en esta familia.'),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: hijos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final hijo = hijos[index];

        String imageUrl;
        final rawUrl = hijo.fotoPerfil ?? '';

        if (rawUrl.isNotEmpty) {
          final absUrl = _absUrl(rawUrl);
          if (absUrl.isNotEmpty) {
            imageUrl = absUrl;
          } else {
            imageUrl =
                'https://cdn-icons-png.flaticon.com/512/7141/7141724.png';
          }
        } else {
          imageUrl = 'https://cdn-icons-png.flaticon.com/512/7141/7141724.png';
        }

        return ProfileCard(
          imageUrl: imageUrl,
          name: hijo.fullName,
          school: hijo.carrera,
          fechaNacimiento: hijo.fechaNacimiento,
          phoneNumber: hijo.telefono,
          onTap: () {
            Navigator.pushNamed(
              context,
              'student_detail',
              arguments: hijo.idUsuario,
            );
          },
          onChat: () => _startChat(hijo.idUsuario, hijo.fullName),
        );
      },
    );
  }
}

class FamilyWidget extends StatelessWidget {
  final ImageProvider backgroundImage;
  final ImageProvider circleImage;
  final bool canOpenCover;
  final bool canOpenProfile;

  const FamilyWidget({
    super.key,
    required this.backgroundImage,
    required this.circleImage,
    required this.canOpenCover,
    required this.canOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: canOpenCover
              ? () => _openFullScreen(context, backgroundImage, 'coverTag')
              : null,
          child: Hero(
            tag: 'coverTag',
            child: Image(
              image: backgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: GestureDetector(
            onTap: canOpenProfile
                ? () => _openFullScreen(context, circleImage, 'profileTag')
                : null,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Image(
                  image: circleImage,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openFullScreen(BuildContext context, ImageProvider image, String tag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImagePage(imageProvider: image, heroTag: tag),
      ),
    );
  }
}

class FamilyData extends StatelessWidget {
  final String familyName;
  final String numChildres;
  final String text;
  final String description;

  const FamilyData({
    super.key,
    required this.familyName,
    required this.numChildres,
    required this.text,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          familyName,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            const SizedBox(height: 10),
            Text(
              numChildres,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.justify,
          style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
        ),
      ],
    );
  }
}

class ProfileCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String? school;
  final String? fechaNacimiento;
  final String? phoneNumber;
  final VoidCallback? onTap;
  final VoidCallback? onChat;

  const ProfileCard({
    super.key,
    required this.imageUrl,
    required this.name,
    this.school,
    this.fechaNacimiento,
    this.phoneNumber,
    this.onTap,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(245, 189, 6, 0.452),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            ClipOval(
              child: Image.network(
                imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    'https://cdn-icons-png.flaticon.com/512/7141/7141724.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    school ?? 'Escuela no registrada',
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                  if (phoneNumber != null)
                    Text(
                      'Tel: $phoneNumber',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                ],
              ),
            ),
            if (onChat != null)
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble,
                  color: Color.fromRGBO(19, 67, 107, 1),
                ),
                onPressed: onChat,
              ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final ImageProvider imageProvider;
  final String heroTag;

  const FullScreenImagePage({
    super.key,
    required this.imageProvider,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image(image: imageProvider, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
