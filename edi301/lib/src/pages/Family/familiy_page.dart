import 'dart:async';
import 'dart:convert';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/services/mensajes_api.dart';
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
import 'package:edi301/tools/fullscreen_image_viewer.dart';

class FamiliyPage extends StatefulWidget {
  const FamiliyPage({super.key});

  @override
  State<FamiliyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamiliyPage> {
  final unescape = HtmlUnescape();
  int _tab = 0; // 0 = Mi familia, 1 = Fotos, 2 = Cumpleaños
  final FamilyController _controller = FamilyController();
  final FamiliaApi _familiaApi = FamiliaApi();

  late Future<Family?> _familyFuture;
  late Future<List<dynamic>> _availableFamiliesFuture;

  String _userRole = '';
  int? _userId;

  Offset _chatFabOffset = const Offset(
    300,
    560,
  ); // posición inicial (ajusta si quieres)
  bool _chatFabReady = false;

  Timer? _unreadTimer;

  int _asInt(dynamic value, {int fallback = 7}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  Offset _clampOffset(Offset o, Size size) {
    // tamaño aprox del botón (FAB 56 + margen)
    const double fabSize = 56;
    const double padding = 12;

    final double maxX = size.width - fabSize - padding;
    final double maxY = size.height - fabSize - padding;

    final dx = o.dx.clamp(padding, maxX);
    final dy = o.dy.clamp(padding, maxY);

    return Offset(dx.toDouble(), dy.toDouble());
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _familyFuture = _fetchFamilyData().then((family) {
      if (family != null && family.id != null) {
        _startUnreadPolling(family.id!);
      }
      return family;
    });
    _availableFamiliesFuture = _fetchAvailableFamilies();
    String _userRole = '';
    int? _userId;
  }

  void _startUnreadPolling(int idFamilia) {
    _checkFamilyUnread(idFamilia);
    _unreadTimer?.cancel();
    _unreadTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _checkFamilyUnread(idFamilia);
    });
  }

  Future<void> _checkFamilyUnread(int idFamilia) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRead =
          prefs.getString('familia_leido_$idFamilia') ??
          '1900-01-01T00:00:00.000Z';
      final count = await MensajesApi().getUnreadCount(idFamilia, lastRead);
      ChatFamilyPage.familyUnread.value = count;
    } catch (_) {}
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  String _absUrl(String raw) {
    if (raw.isEmpty || raw == 'null') return '';
    final s = raw.trim();
    if (s.isEmpty || s == 'null') return '';

    // URL completa (Cloudinary, S3, etc.) — se devuelve tal cual
    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    // Ruta relativa del servidor propio
    var path = s.replaceAll('\\', '/');

    final idxPublic = path.indexOf('public/uploads/');
    if (idxPublic != -1) {
      path = path.substring(idxPublic + 'public'.length);
    }

    final idxUploads = path.indexOf('/uploads/');
    if (idxUploads != -1) {
      path = path.substring(idxUploads);
    } else if (path.startsWith('uploads/')) {
      path = '/$path';
    } else if (!path.startsWith('/')) {
      path = '/$path';
    }

    return '${ApiHttp.baseUrl}$path';
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

      final dynamic rawId =
          user['id_usuario'] ?? user['id'] ?? user['IdUsuario'];
      int? parsedId;
      if (rawId is int) {
        parsedId = rawId;
      } else if (rawId != null) {
        parsedId = int.tryParse(rawId.toString());
      }

      if (!mounted) return;
      setState(() {
        _userRole = user['nombre_rol'] ?? user['rol'] ?? '';
        _userId =
            (user['id_usuario'] ?? user['id'] ?? user['IdUsuario']) as int?;
      });
    }
  }

  bool get _isChildRole {
    final r = _userRole.trim().toUpperCase();
    return ['HIJO', 'HIJOEDI', 'ALUMNO', 'ESTUDIANTE'].contains(r);
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
      // ignore: avoid_print
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
        final numAlumnos = _asInt(familia['num_alumnos'], fallback: 0);
        final limiteHijosEdi = _asInt(familia['limite_hijos_edi']);

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
                  Text(
                    'Capacidad actual: $numAlumnos de $limiteHijosEdi alumnos',
                  ),
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

  bool get _canEditFamilyProfile {
    final r = _userRole.trim().toUpperCase();
    // si NO es hijo/alumno, puede editar
    return !['HIJO', 'HIJOEDI', 'ALUMNO', 'ESTUDIANTE'].contains(r);
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;

            // inicializa posición solo una vez (para no resetear al rebuild)
            if (!_chatFabReady) {
              _chatFabOffset = _clampOffset(
                Offset(size.width - 56 - 12, size.height - 56 - 24),
                size,
              );
              _chatFabReady = true;
            }

            return Stack(
              children: [
                // CONTENIDO NORMAL
                ResponsiveContent(
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

                      final coverUrlRaw = (family.fotoPortadaUrl ?? '')
                          .toString();
                      final profileUrlRaw = (family.fotoPerfilUrl ?? '')
                          .toString();

                      final coverAbs = _absUrl(coverUrlRaw);
                      final profileAbs = _absUrl(profileUrlRaw);

                      final ImageProvider? coverImage = coverAbs.isNotEmpty
                          ? NetworkImage(coverAbs)
                          : null;

                      final ImageProvider? profileImage = profileAbs.isNotEmpty
                          ? NetworkImage(profileAbs)
                          : null;

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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: FamilyData(
                                familyName: family.familyName,
                                numChildres:
                                    (family.assignedStudents.length +
                                            family.hogarChildren.length +
                                            ((family.fatherEmployeeId != null &&
                                                    family.fatherEmployeeId !=
                                                        0)
                                                ? 1
                                                : 0) +
                                            ((family.motherEmployeeId != null &&
                                                    family.motherEmployeeId !=
                                                        0)
                                                ? 1
                                                : 0))
                                        .toString(),
                                text: 'Integrantes',
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
                            if (_tab == 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: _buildIntegrantesCards(family: family),
                              )
                            else if (_tab == 1)
                              FamilyGallery(idFamilia: family.id ?? 0)
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _buildCumpleanosSection(family: family),
                              ),
                            const SizedBox(
                              height: 90,
                            ), // espacio para que no tape contenido
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // BOTÓN DRAGGABLE DEL CHAT FAMILIAR
                FutureBuilder<Family?>(
                  future: _familyFuture,
                  builder: (context, snapshot) {
                    if (!(snapshot.hasData && snapshot.data != null)) {
                      return const SizedBox();
                    }

                    final familyData = snapshot.data!;
                    final id = familyData.id ?? 0;

                    return Positioned(
                      left: _chatFabOffset.dx,
                      top: _chatFabOffset.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _chatFabOffset = _clampOffset(
                              _chatFabOffset + details.delta,
                              size,
                            );
                          });
                        },
                        child: FloatingActionButton(
                          heroTag: 'family_chat_draggable_fab',
                          onPressed: () {
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
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // =========================
  //  LISTA INTEGRANTES (PADRES + HIJOS) + RESTRICCIÓN
  // =========================
  Widget _buildIntegrantesCards({required Family family}) {
    final widgets = <Widget>[];

    final bool isChild = _isChildRole;
    final int? myId = _userId;

    // ---- Padres ----
    final papaId = family.fatherEmployeeId;
    final mamaId = family.motherEmployeeId;

    if (papaId != null && papaId != 0) {
      final papaNombre = (family.fatherName ?? '').trim();
      final papaFotoAbs = _absUrl((family.papaFotoPerfilUrl ?? '').toString());

      final bool isMe = (myId != null && papaId == myId);

      widgets.add(
        ProfileCard(
          imageUrl: papaFotoAbs,
          name: papaNombre.isNotEmpty ? papaNombre : 'Padre',
          school: 'Padre',
          phoneNumber: family.papaTelefono,
          onTap: () =>
              Navigator.pushNamed(context, 'student_detail', arguments: papaId),
          onChat: isMe
              ? null
              : () => _startChat(
                  papaId,
                  papaNombre.isNotEmpty ? papaNombre : 'Padre',
                ),
        ),
      );
    }

    if (mamaId != null && mamaId != 0) {
      final mamaNombre = (family.motherName ?? '').trim();
      final mamaFotoAbs = _absUrl((family.mamaFotoPerfilUrl ?? '').toString());

      final bool isMe = (myId != null && mamaId == myId);

      widgets.add(
        ProfileCard(
          imageUrl: mamaFotoAbs,
          name: mamaNombre.isNotEmpty ? mamaNombre : 'Madre',
          school: 'Madre',
          phoneNumber: family.mamaTelefono,
          onTap: () =>
              Navigator.pushNamed(context, 'student_detail', arguments: mamaId),
          onChat: isMe
              ? null
              : () => _startChat(
                  mamaId,
                  mamaNombre.isNotEmpty ? mamaNombre : 'Madre',
                ),
        ),
      );
    }

    // ---- Hijos / hermanos (con cuenta) ----
    final hijos = <FamilyMember>[
      ...family.householdChildren,
      ...family.assignedStudents,
    ];

    for (final h in hijos) {
      final bool isMe = (myId != null && h.idUsuario == myId);

      // Restricción: si soy hijo/alumno, solo puedo abrir detalle de mí mismo
      final bool canOpenDetail = !isChild || isMe;

      final fotoAbs = _absUrl((h.fotoPerfil ?? '').toString());

      widgets.add(
        ProfileCard(
          imageUrl: fotoAbs,
          name: h.fullName,
          school: h.carrera,
          phoneNumber: h.telefono,
          onTap: canOpenDetail
              ? () => Navigator.pushNamed(
                  context,
                  'student_detail',
                  arguments: h.idUsuario,
                )
              : null,
          onChat: isMe ? null : () => _startChat(h.idUsuario, h.fullName),
        ),
      );
    }

    // ---- Niños del hogar sin cuenta (mostrados como hijos sanguíneos) ----
    for (final h in family.hogarChildren) {
      widgets.add(
        ProfileCard(
          imageUrl: '',
          name: h.fullName,
          school: 'Niño del hogar',
          phoneNumber: h.fechaNacimiento != null
              ? 'Nac: ${h.fechaNacimiento}'
              : null,
          onTap: null,
          onChat: null,
        ),
      );
    }

    if (widgets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('No hay integrantes registrados.'),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: widgets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => widgets[i],
    );
  }

  // =========================
  //  SIN FAMILIA (LISTA DISPONIBLES)
  // =========================
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
                  final numAlumnos = _asInt(f['num_alumnos'], fallback: 0);
                  final limiteHijosEdi = _asInt(f['limite_hijos_edi']);
                  final bool estaLleno = numAlumnos >= limiteHijosEdi;

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
                                'Integrantes: $numAlumnos / $limiteHijosEdi',
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

  // =========================
  //  BOTÓN EDITAR PERFIL
  // =========================
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

  // =========================
  //  TOGGLE
  // =========================
  Widget _buildToggleButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildToggleButton('Mi familia', _tab == 0, () {
            setState(() => _tab = 0);
          }),
          const SizedBox(width: 8),
          _buildToggleButton('Fotos', _tab == 1, () {
            setState(() => _tab = 1);
          }),
          const SizedBox(width: 8),
          _buildToggleButton('Cumpleaños 🎂', _tab == 2, () {
            setState(() => _tab = 2);
          }),
        ],
      ),
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
        elevation: isSelected ? 2 : 0,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // =========================
  //  CUMPLEAÑOS
  // =========================

  static DateTime? _parseFechaDDMMYYYY(String? fecha) {
    if (fecha == null || fecha.isEmpty) return null;
    try {
      final p = fecha.split('/');
      if (p.length == 3) {
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      return DateTime.parse(fecha);
    } catch (_) {
      return null;
    }
  }

  static int _daysUntil(DateTime birth) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var next = DateTime(today.year, birth.month, birth.day);
    if (next.isBefore(today))
      next = DateTime(today.year + 1, birth.month, birth.day);
    return next.difference(today).inDays;
  }

  static int _nextAge(DateTime birth) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final thisBirthday = DateTime(today.year, birth.month, birth.day);
    return thisBirthday.isBefore(today)
        ? today.year + 1 - birth.year
        : today.year - birth.year;
  }

  static String _formatBirthDate(DateTime d) {
    const meses = [
      '',
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${d.day} de ${meses[d.month]}';
  }

  Widget _buildCumpleanosSection({required Family family}) {
    // ── Reunir todos los miembros con cumpleaños ─────────────────────────────
    final entries = <_BirthdayEntry>[];

    void add(
      String name,
      String? fecha,
      String? photoUrl,
      String tipo,
      int? userId,
    ) {
      final dt = _parseFechaDDMMYYYY(fecha);
      if (dt == null) return;
      entries.add(
        _BirthdayEntry(
          name: name,
          birthDate: dt,
          photoUrl: photoUrl,
          tipo: tipo,
          userId: userId,
          daysUntil: _daysUntil(dt),
          nextAge: _nextAge(dt),
        ),
      );
    }

    // Padres
    if ((family.fatherName ?? '').isNotEmpty &&
        family.papaFechaNacimiento != null) {
      add(
        family.fatherName!,
        family.papaFechaNacimiento,
        _absUrl(family.papaFotoPerfilUrl ?? ''),
        'Padre',
        family.fatherEmployeeId,
      );
    }
    if ((family.motherName ?? '').isNotEmpty &&
        family.mamaFechaNacimiento != null) {
      add(
        family.motherName!,
        family.mamaFechaNacimiento,
        _absUrl(family.mamaFotoPerfilUrl ?? ''),
        'Madre',
        family.motherEmployeeId,
      );
    }

    // Hijos y alumnos (con cuenta)
    for (final m in [...family.householdChildren, ...family.assignedStudents]) {
      if (m.fechaNacimiento != null) {
        add(
          m.fullName,
          m.fechaNacimiento,
          m.fotoPerfil != null ? _absUrl(m.fotoPerfil!) : null,
          'Hijo',
          m.idUsuario,
        );
      }
    }

    // Niños del hogar sin cuenta
    for (final h in family.hogarChildren) {
      if (h.fechaNacimiento != null) {
        add(h.fullName, h.fechaNacimiento, null, 'Niño', null);
      }
    }

    // ── Ordenar por días que faltan ──────────────────────────────────────────
    entries.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.cake_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Sin fechas de cumpleaños',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega las fechas de nacimiento\nen los perfiles de cada integrante.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    // ── Banner de cumpleaños de hoy ─────────────────────────────────────────
    final hoy = entries.where((e) => e.daysUntil == 0).toList();

    // ── Grupos ───────────────────────────────────────────────────────────────
    final estaS = entries
        .where((e) => e.daysUntil > 0 && e.daysUntil <= 7)
        .toList();
    final esteMes = entries
        .where((e) => e.daysUntil > 7 && e.daysUntil <= 30)
        .toList();
    final masAdelante = entries.where((e) => e.daysUntil > 30).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner hoy
        ...hoy.map((e) => _buildHoyBanner(e)),
        if (hoy.isNotEmpty) const SizedBox(height: 16),

        // Próximos 7 días
        if (estaS.isNotEmpty) ...[
          _buildGroupLabel('📅  Esta semana', Colors.green.shade700),
          ...estaS.map((e) => _buildBirthdayCard(e)),
          const SizedBox(height: 8),
        ],

        // Este mes
        if (esteMes.isNotEmpty) ...[
          _buildGroupLabel('🗓️  Este mes', Colors.blue.shade700),
          ...esteMes.map((e) => _buildBirthdayCard(e)),
          const SizedBox(height: 8),
        ],

        // Más adelante
        if (masAdelante.isNotEmpty) ...[
          _buildGroupLabel('✨  Próximamente', Colors.grey.shade600),
          ...masAdelante.map((e) => _buildBirthdayCard(e)),
        ],

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildHoyBanner(_BirthdayEntry e) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5BC06), Color(0xFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5BC06).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hoy cumple años!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade700,
                  ),
                ),
                Text(
                  e.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Cumple ${e.nextAge} años hoy 🥳',
                  style: TextStyle(fontSize: 13, color: Colors.brown.shade600),
                ),
              ],
            ),
          ),
          _buildAvatar(e, 48, const Color(0xFFE65100)),
        ],
      ),
    );
  }

  Widget _buildGroupLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBirthdayCard(_BirthdayEntry e) {
    // Colores por proximidad
    final Color bgColor;
    final Color accentColor;
    final String badge;

    if (e.daysUntil <= 7) {
      bgColor = const Color(0xFFE8F5E9);
      accentColor = Colors.green.shade700;
      badge = e.daysUntil == 1 ? 'Mañana' : 'En ${e.daysUntil} días';
    } else if (e.daysUntil <= 30) {
      bgColor = const Color(0xFFE3F2FD);
      accentColor = Colors.blue.shade700;
      badge = 'En ${e.daysUntil} días';
    } else {
      bgColor = Colors.grey.shade50;
      accentColor = const Color.fromRGBO(19, 67, 107, 1);
      // Mostrar fecha corta del próximo cumpleaños
      final next = DateTime(
        DateTime.now().year + (e.daysUntil > 365 ? 1 : 0),
        e.birthDate.month,
        e.birthDate.day,
      );
      badge = _formatBirthDate(next);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildAvatar(e, 46, accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🎂  ${_formatBirthDate(e.birthDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    'Cumple ${e.nextAge} años',
                    style: TextStyle(
                      fontSize: 11,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(_BirthdayEntry e, double size, Color fallbackColor) {
    final url = e.photoUrl ?? '';
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(url),
        backgroundColor: fallbackColor.withOpacity(0.2),
        onBackgroundImageError: (_, __) {},
      );
    }
    final initial = e.name.isNotEmpty ? e.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: fallbackColor.withOpacity(0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: fallbackColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

// =========================
//  BIRTHDAY ENTRY MODEL
// =========================
class _BirthdayEntry {
  final String name;
  final DateTime birthDate;
  final String? photoUrl;
  final String tipo;
  final int? userId;
  final int daysUntil;
  final int nextAge;

  const _BirthdayEntry({
    required this.name,
    required this.birthDate,
    required this.tipo,
    required this.daysUntil,
    required this.nextAge,
    this.photoUrl,
    this.userId,
  });
}

// =========================
//  FAMILY HEADER WIDGET
// =========================
class FamilyWidget extends StatelessWidget {
  final ImageProvider? backgroundImage;
  final ImageProvider? circleImage;
  final bool canOpenCover;
  final bool canOpenProfile;

  const FamilyWidget({
    super.key,
    required this.backgroundImage,
    required this.circleImage,
    required this.canOpenCover,
    required this.canOpenProfile,
  });

  static const _primary = Color.fromRGBO(19, 67, 107, 1);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Portada ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: canOpenCover && backgroundImage != null
              ? () => _openFullScreen(context, backgroundImage!, 'coverTag')
              : null,
          child: Hero(
            tag: 'coverTag',
            child: backgroundImage != null
                ? Image(
                    image: backgroundImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        _coverPlaceholder(),
                  )
                : _coverPlaceholder(),
          ),
        ),
        // ── Foto de perfil ────────────────────────────────────────────────
        Positioned(
          bottom: 10,
          left: 10,
          child: GestureDetector(
            onTap: canOpenProfile && circleImage != null
                ? () => _openFullScreen(context, circleImage!, 'profileTag')
                : null,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: circleImage != null
                  ? ClipOval(
                      child: _SafeImage(
                        image: circleImage,
                        width: 92,
                        height: 92,
                      ),
                    )
                  : Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.fromRGBO(19, 67, 107, 0.08),
                      ),
                      child: const Icon(
                        Icons.family_restroom,
                        size: 40,
                        color: _primary,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromRGBO(19, 67, 107, 0.15),
            Color.fromRGBO(19, 67, 107, 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.home_outlined,
        size: 64,
        color: Color.fromRGBO(19, 67, 107, 0.25),
      ),
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

// =========================
//  FAMILY DATA
// =========================
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

// =========================
//  PROFILE CARD
// =========================
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

  Widget _avatarPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color.fromRGBO(19, 67, 107, 0.08),
      ),
      child: const Icon(
        Icons.person,
        size: 30,
        color: Color.fromRGBO(19, 67, 107, 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = 'member_${name.hashCode}_${imageUrl.hashCode}';

    final bool hasValidImage =
        imageUrl.isNotEmpty && !imageUrl.contains('null');

    final ImageProvider? imgProvider = hasValidImage
        ? NetworkImage(imageUrl)
        : null;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: hasValidImage && imgProvider != null
                    ? () {
                        FullScreenImageViewer.open(
                          context,
                          imageProvider: imgProvider,
                          heroTag: heroTag,
                        );
                      }
                    : null,
                child: Hero(
                  tag: heroTag,
                  child: hasValidImage && imgProvider != null
                      ? ClipOval(
                          child: Image(
                            image: imgProvider,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _avatarPlaceholder(),
                          ),
                        )
                      : _avatarPlaceholder(),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      school ?? 'Escuela no registrada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    ),
                    if (phoneNumber != null)
                      Text(
                        'Tel: $phoneNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

// =========================
//  FULLSCREEN IMAGE PAGE
// =========================
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
            child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.broken_image, color: Colors.white54, size: 60),
                  SizedBox(height: 12),
                  Text(
                    'No se pudo cargar la imagen',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================
//  SAFE IMAGE — carga segura con fallback al asset local
// =========================
class _SafeImage extends StatelessWidget {
  final ImageProvider? image;
  final double width;
  final double height;

  const _SafeImage({
    required this.image,
    required this.width,
    required this.height,
  });

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: const Color.fromRGBO(19, 67, 107, 0.08),
      child: const Icon(
        Icons.family_restroom,
        size: 40,
        color: Color.fromRGBO(19, 67, 107, 0.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (image == null) return _placeholder();
    return Image(
      image: image!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        // Mientras carga, mostrar placeholder
        return Stack(
          alignment: Alignment.center,
          children: [_placeholder(), child],
        );
      },
    );
  }
}
