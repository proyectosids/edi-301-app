import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/services/socket_service.dart';

class ChatPage extends StatefulWidget {
  final int idSala;
  final String nombreChat;

  const ChatPage({super.key, required this.idSala, required this.nombreChat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatApi _api = ChatApi();
  final SocketService _socketService = SocketService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<dynamic> _mensajes = [];
  bool _loading = true;

  int? _myId; // ✅ necesario para calcular es_mio
  bool _socketReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _socketService.initSocket();
    await _loadMyId(); // si tienes este método
    await _setupSocketListeners();
    await _loadMessages();
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr == null) return;

    final user = jsonDecode(userStr);

    final dynamic raw =
        user['id_usuario'] ?? user['id'] ?? user['ID'] ?? user['Id'];

    int? parsed;
    if (raw is int) {
      parsed = raw;
    } else {
      parsed = int.tryParse(raw?.toString() ?? '');
    }

    _myId = parsed;
  }

  @override
  void dispose() {
    if (_socketService.isReady) {
      _socketService.socket.off('nuevo_mensaje');
      _socketService.leaveRoom('sala_${widget.idSala}');
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _setupSocketListeners() async {
    await _socketService.ensureConnected();

    _socketService.joinChatRoom(widget.idSala);
    _socketReady = true;

    // (Opcional pero útil) confirmar join por logs/ack si lo implementaste en backend
    _socketService.socket.off('joined_room');
    _socketService.socket.on('joined_room', (data) {
      print('✅ joined_room: $data');
    });

    // Limpia listener previo por si se re-entra a la pantalla
    _socketService.socket.off('nuevo_mensaje');

    _socketService.socket.on('nuevo_mensaje', (data) {
      if (!mounted) return;

      final incoming = Map<String, dynamic>.from(data as Map);

      // ✅ Calcular es_mio en el cliente
      final int? senderId = incoming['id_usuario'] is int
          ? incoming['id_usuario']
          : int.tryParse((incoming['id_usuario'] ?? '').toString());

      incoming['es_mio'] = (_myId != null && senderId == _myId) ? 1 : 0;

      final dynamic incomingId = incoming['id_mensaje'];

      // ✅ Evitar duplicados por id_mensaje si existe
      final yaExiste = _mensajes.any((m) {
        if (m is Map && m['id_mensaje'] != null && incomingId != null) {
          return m['id_mensaje'].toString() == incomingId.toString();
        }
        return false;
      });

      if (yaExiste) return;

      setState(() {
        // ✅ Reemplazar temporal si coincide por texto + sala + sender
        final idxTemp = _mensajes.indexWhere((m) {
          if (m is! Map) return false;
          final isTemp = m['_temp'] == true;
          final sameText =
              (m['mensaje'] ?? '').toString() ==
              (incoming['mensaje'] ?? '').toString();
          final sameSala =
              (m['id_sala'] ?? '').toString() ==
              (incoming['id_sala'] ?? '').toString();
          final sameSender =
              (m['id_usuario'] ?? '').toString() ==
              (incoming['id_usuario'] ?? '').toString();
          return isTemp && sameText && sameSala && sameSender;
        });

        if (idxTemp != -1) {
          _mensajes[idxTemp] = incoming;
        } else {
          _mensajes.add(incoming);
        }
      });

      _scrollToBottom();
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);

    final msgs = await _api.getMessages(widget.idSala);

    // ✅ Normalizar es_mio también para los mensajes cargados por API
    final normalized = msgs.map((m) {
      if (m is! Map) return m;

      final msg = Map<String, dynamic>.from(m);
      final int? senderId = msg['id_usuario'] is int
          ? msg['id_usuario']
          : int.tryParse((msg['id_usuario'] ?? '').toString());

      msg['es_mio'] = (_myId != null && senderId == _myId) ? 1 : 0;
      return msg;
    }).toList();

    if (mounted) {
      setState(() {
        _mensajes = normalized;
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();

    // ✅ Optimistic UI (pero ahora incluye id_usuario)
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    final tempMsg = <String, dynamic>{
      'id_mensaje': tempId,
      'id_sala': widget.idSala,
      'id_usuario': _myId, // ✅ clave para reemplazar temporal
      'mensaje': text,
      'es_mio': 1,
      'created_at': DateTime.now().toIso8601String(),
      '_temp': true,
    };

    if (mounted) {
      setState(() => _mensajes.add(tempMsg));
      _scrollToBottom();
    }

    final success = await _api.sendMessage(widget.idSala, text);

    if (!success && mounted) {
      setState(() {
        _mensajes.removeWhere((m) => m is Map && m['id_mensaje'] == tempId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error al enviar mensaje")));
    } else {
      // Si socket está caído, el otro no lo verá hasta recargar.
      // Opcional: refrescar mensajes para "confirmar" en caso de socket no conectado.
      // (no lo hago automático para no spamear al server)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreChat),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _mensajes.isEmpty
                ? const Center(child: Text("Inicia la conversación..."))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(10),
                    itemCount: _mensajes.length,
                    itemBuilder: (ctx, i) {
                      final msg = _mensajes[i];
                      if (msg is! Map) return const SizedBox.shrink();

                      final esMio = msg['es_mio'] == 1 || msg['es_mio'] == true;

                      return Align(
                        alignment: esMio
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: esMio
                                ? const Color.fromRGBO(245, 188, 6, 1)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: esMio
                                  ? const Radius.circular(15)
                                  : Radius.zero,
                              bottomRight: esMio
                                  ? Radius.zero
                                  : const Radius.circular(15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!esMio)
                                Text(
                                  (msg['nombre_remitente'] ?? 'Usuario')
                                      .toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              Text(
                                (msg['mensaje'] ?? '').toString(),
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (msg['_temp'] == true)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Enviando...',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
