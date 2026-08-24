import 'dart:async'; // ✅ Necesario para el Timer
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/mensajes_api.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/services/socket_service.dart';

class ChatFamilyPage extends StatefulWidget {
  final int idFamilia;
  final String nombreFamilia;

  const ChatFamilyPage({
    Key? key,
    required this.idFamilia,
    required this.nombreFamilia,
  }) : super(key: key);

  /// Notifier global: cantidad de mensajes de familia no leídos.
  /// home_page.dart lo escucha para mostrar el badge en la pestaña Familia.
  static final ValueNotifier<int> familyUnread = ValueNotifier<int>(0);

  @override
  _ChatFamilyPageState createState() => _ChatFamilyPageState();
}

class _ChatFamilyPageState extends State<ChatFamilyPage> {
  final MensajesApi _api = MensajesApi();
  final SocketService _socketService = SocketService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _mensajes = [];
  int _miIdUsuario = 0;
  bool _loading = true; // ✅ Control de carga inicial
  bool _loadingOlder = false;
  bool _hasOlder = false;
  bool _sending = false;

  static const int _pageSize = 100;

  Timer? _pollingTimer; // ✅ Referencia para el temporizador

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Marcar chat familiar como leído al abrir
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'familia_leido_${widget.idFamilia}',
      DateTime.now().toIso8601String(),
    );
    ChatFamilyPage.familyUnread.value = 0;

    await _loadUser();
    await _cargarMensajes(); // Carga inicial de mensajes
    await _socketService.joinFamilyRoom(widget.idFamilia);
    if (!mounted) return;
    _socketService.socket.off('nuevo_mensaje_familia');
    _socketService.socket.on('nuevo_mensaje_familia', (_) {
      if (mounted) _cargarMensajes(quiet: true);
    });
    _startPolling(); // ✅ Inicia el refresco automático
  }

  // Respaldo por si el socket pierde conectividad temporalmente.
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarMensajes(quiet: true); // Carga silenciosa en segundo plano
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // ✅ Obligatorio: detener el timer al salir
    if (_socketService.isReady) {
      _socketService.socket.off('nuevo_mensaje_familia');
    }
    _socketService.leaveRoom('familia_${widget.idFamilia}');
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      if (mounted) {
        setState(() {
          _miIdUsuario = user['id_usuario'] ?? user['id'] ?? 0;
        });
      }
    }
  }

  // ✅ Ajustado para manejar refrescos sin interrumpir la UI
  Future<void> _cargarMensajes({bool quiet = false}) async {
    if (!quiet && _mensajes.isEmpty) {
      setState(() => _loading = true);
    }

    final nuevos = await _api.getMensajesFamilia(
      widget.idFamilia,
      limit: _pageSize,
    );

    if (mounted) {
      final initialLoad = _mensajes.isEmpty;
      final merged = _mergeMessages(_mensajes, nuevos);
      if (merged.length != _mensajes.length) {
        setState(() {
          _mensajes = merged;
          if (initialLoad) _hasOlder = nuevos.length == _pageSize;
          _loading = false;
        });
        _scrollToBottom();
      } else {
        if (_loading) setState(() => _loading = false);
      }
    }
  }

  List<dynamic> _mergeMessages(List<dynamic> current, List<dynamic> incoming) {
    final byId = <int, dynamic>{};
    for (final raw in [...current, ...incoming]) {
      if (raw is! Map) continue;
      final id = int.tryParse('${raw['id_mensaje']}');
      if (id != null) byId[id] = raw;
    }
    final ids = byId.keys.toList()..sort();
    return ids.map((id) => byId[id]).toList();
  }

  Future<void> _cargarAnteriores() async {
    if (_loadingOlder || !_hasOlder || _mensajes.isEmpty) return;
    final firstId = int.tryParse('${_mensajes.first['id_mensaje']}');
    if (firstId == null) return;

    setState(() => _loadingOlder = true);
    final previousExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    try {
      final anteriores = await _api.getMensajesFamilia(
        widget.idFamilia,
        limit: _pageSize,
        beforeId: firstId,
      );
      if (!mounted) return;
      setState(() {
        _mensajes = _mergeMessages(anteriores, _mensajes);
        _hasOlder = anteriores.length == _pageSize;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final delta =
              _scrollController.position.maxScrollExtent - previousExtent;
          _scrollController.jumpTo(
            delta.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _enviar() async {
    final texto = _textController.text.trim();
    if (texto.isEmpty || _sending) return;

    _textController.clear();
    setState(() => _sending = true);
    try {
      final exito = await _api.enviarMensaje(widget.idFamilia, texto);
      if (exito) {
        _cargarMensajes(quiet: true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar mensaje')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar mensaje')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Color _getColorForName(String name) {
    final List<Color> colors = [
      Colors.red[700]!,
      Colors.pink[700]!,
      Colors.purple[700]!,
      Colors.deepPurple[700]!,
      Colors.indigo[700]!,
      Colors.blue[700]!,
      Colors.teal[700]!,
      Colors.green[700]!,
      Colors.orange[800]!,
      Colors.brown[700]!,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreFamilia),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    ) // ✅ Loader inicial
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 20,
                      ),
                      itemCount: _mensajes.length + (_hasOlder ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_hasOlder && index == 0) {
                          return Center(
                            child: TextButton.icon(
                              onPressed: _loadingOlder
                                  ? null
                                  : _cargarAnteriores,
                              icon: _loadingOlder
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.history),
                              label: const Text('Cargar mensajes anteriores'),
                            ),
                          );
                        }
                        final messageIndex = _hasOlder ? index - 1 : index;
                        final msg = _mensajes[messageIndex];
                        final esMio = msg['id_usuario'] == _miIdUsuario;
                        return _buildMessageBubble(msg, esMio);
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(
                      255,
                      255,
                      255,
                      255,
                    ).withOpacity(0.1),
                    offset: const Offset(0, -2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!_sending) _enviar();
                      },
                      decoration: InputDecoration(
                        hintText: "Escribe un mensaje...",
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                    radius: 24,
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                      onPressed: _sending ? null : _enviar,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Convierte el timestamp del servidor a fecha y hora local.
  String _formatMsgTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final str =
        (raw.endsWith('Z') || raw.contains('+') || raw.contains('-', 11))
        ? raw
        : '${raw}Z';
    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool esMio) {
    final baseUrl = ApiHttp.baseUrl;
    final hora = _formatMsgTime(msg['created_at']?.toString());

    final colorFondo = esMio
        ? const Color.fromRGBO(19, 67, 107, 1)
        : Color.fromRGBO(245, 188, 6, 1);

    final colorTexto = esMio ? Colors.white : Colors.black87;
    final colorHora = esMio ? Colors.white70 : Colors.grey[600];
    final nombreUsuario = msg['nombre'] ?? 'Desconocido';
    final colorNombre = _getColorForName(nombreUsuario);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: esMio
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esMio) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[300],
              backgroundImage: (msg['foto_perfil'] != null)
                  ? NetworkImage('$baseUrl${msg['foto_perfil']}')
                  : null,
              child: (msg['foto_perfil'] == null)
                  ? Text(
                      nombreUsuario.isNotEmpty ? nombreUsuario[0] : '?',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],

          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorFondo,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: esMio
                      ? const Radius.circular(18)
                      : const Radius.circular(2),
                  bottomRight: esMio
                      ? const Radius.circular(2)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!esMio)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        nombreUsuario,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorNombre,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  Text(
                    msg['mensaje'] ?? '',
                    style: TextStyle(fontSize: 15, color: colorTexto),
                  ),

                  const SizedBox(height: 4),

                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      hora,
                      style: TextStyle(fontSize: 10, color: colorHora),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
