import 'dart:async'; // ✅ Importante para el Timer
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
  bool _loadingOlder = false;
  bool _hasOlder = false;
  bool _sending = false;
  int? _myId;

  static const int _pageSize = 100;

  Timer? _pollingTimer; // ✅ Referencia para el temporizador

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadMyId();
    await _loadMessages(); // Carga inicial
    await _socketService.joinChatRoom(widget.idSala);
    if (!mounted) return;
    _socketService.socket.off('nuevo_mensaje');
    _socketService.socket.on('nuevo_mensaje', (_) {
      if (mounted) _loadMessages(isPolling: true);
    });
    _api.markAsRead(
      widget.idSala,
    ); // Marcar sala como leída al entrar (fire & forget)
    _startPolling(); // ✅ Inicia el refresco automático
  }

  // Respaldo por si el socket pierde conectividad temporalmente.
  void _startPolling() {
    _pollingTimer?.cancel(); // Limpia cualquier timer previo
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadMessages(isPolling: true);
      }
    });
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr == null) return;
    final user = jsonDecode(userStr);
    final dynamic raw =
        user['id_usuario'] ?? user['id'] ?? user['ID'] ?? user['Id'];
    _myId = (raw is int) ? raw : int.tryParse(raw?.toString() ?? '');
  }

  @override
  void dispose() {
    _pollingTimer
        ?.cancel(); // ✅ Obligatorio: detener el timer al salir de la página
    if (_socketService.isReady) {
      _socketService.socket.off('nuevo_mensaje');
    }
    _socketService.leaveRoom('sala_${widget.idSala}');
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ✅ Maneja tanto la carga inicial como refrescos silenciosos con try-catch
  Future<void> _loadMessages({bool isPolling = false}) async {
    // Solo mostramos el loader principal si es la primera carga y no hay mensajes
    if (!isPolling && _mensajes.isEmpty) {
      setState(() => _loading = true);
    }

    try {
      final msgs = await _api.getMessages(widget.idSala, limit: _pageSize);

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
        final initialLoad = _mensajes.isEmpty;
        final merged = _mergeMessages(_mensajes, normalized);
        if (merged.length != _mensajes.length) {
          setState(() {
            _mensajes = merged;
            if (initialLoad) _hasOlder = normalized.length == _pageSize;
            _loading = false;
          });
          _scrollToBottom();
        } else {
          // Si no hay cambios, simplemente quitamos el loading si estaba activo
          if (_loading) setState(() => _loading = false);
        }
      }
    } catch (e) {
      // Error transitorio (ej. servidor reiniciando) → ignorar en polling,
      // solo quitar spinner en primera carga
      if (mounted && _loading) setState(() => _loading = false);
      if (!isPolling) print('❌ Error cargando mensajes: $e');
    }
  }

  List<dynamic> _mergeMessages(List<dynamic> current, List<dynamic> incoming) {
    final byId = <int, dynamic>{};
    final pending = <dynamic>[];
    for (final raw in [...current, ...incoming]) {
      if (raw is! Map) continue;
      if (raw['_temp'] == true) {
        pending.add(raw);
        continue;
      }
      final id = int.tryParse('${raw['id_mensaje']}');
      if (id != null) byId[id] = raw;
    }
    final ids = byId.keys.toList()..sort();
    return [...ids.map((id) => byId[id]), ...pending];
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasOlder || _mensajes.isEmpty) return;
    final firstId = int.tryParse('${_mensajes.first['id_mensaje']}');
    if (firstId == null) return;

    setState(() => _loadingOlder = true);
    final previousExtent = _scrollCtrl.hasClients
        ? _scrollCtrl.position.maxScrollExtent
        : 0.0;
    try {
      final older = await _api.getMessages(
        widget.idSala,
        limit: _pageSize,
        beforeId: firstId,
      );
      final normalized = older.map((m) {
        if (m is! Map) return m;
        final msg = Map<String, dynamic>.from(m);
        final senderId = int.tryParse('${msg['id_usuario']}');
        msg['es_mio'] = (_myId != null && senderId == _myId) ? 1 : 0;
        return msg;
      }).toList();
      if (!mounted) return;
      setState(() {
        _mensajes = _mergeMessages(normalized, _mensajes);
        _hasOlder = normalized.length == _pageSize;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          final delta = _scrollCtrl.position.maxScrollExtent - previousExtent;
          _scrollCtrl.jumpTo(
            delta.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
          );
        }
      });
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    _msgCtrl.clear();
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    final tempMsg = <String, dynamic>{
      'id_mensaje': tempId,
      'mensaje': text,
      'es_mio': 1,
      '_temp': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    setState(() {
      _sending = true;
      _mensajes.add(tempMsg);
      _scrollToBottom();
    });

    try {
      final success = await _api.sendMessage(widget.idSala, text);
      _api.markAsRead(widget.idSala);

      if (success) {
        if (mounted) {
          setState(
            () => _mensajes.removeWhere((m) => m['id_mensaje'] == tempId),
          );
        }
        _loadMessages(isPolling: true);
      } else {
        _showSendError(tempId);
      }
    } catch (_) {
      _showSendError(tempId);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSendError(int tempId) {
    if (!mounted) return;
    setState(() => _mensajes.removeWhere((m) => m['id_mensaje'] == tempId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Error al enviar mensaje')));
  }

  String _formatMessageDateTime(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return '';
    final value = raw.toString();
    final normalized =
        (value.endsWith('Z') || value.contains('+') || value.contains('-', 11))
        ? value
        : '${value}Z';
    final date = DateTime.tryParse(normalized)?.toLocal();
    if (date == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreChat),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _mensajes.isEmpty
                  ? const Center(child: Text("Inicia la conversación..."))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(10),
                      itemCount: _mensajes.length + (_hasOlder ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (_hasOlder && i == 0) {
                          return Center(
                            child: TextButton.icon(
                              onPressed: _loadingOlder
                                  ? null
                                  : _loadOlderMessages,
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
                        final index = _hasOlder ? i - 1 : i;
                        final msg = _mensajes[index];
                        if (msg is! Map) return const SizedBox.shrink();

                        final esMio =
                            msg['es_mio'] == 1 || msg['es_mio'] == true;

                        return Align(
                          alignment: esMio
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: IntrinsicWidth(
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
                                  mainAxisSize: MainAxisSize.min,
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
                                    const SizedBox(height: 3),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        [
                                              _formatMessageDateTime(
                                                msg['created_at'] ??
                                                    msg['fecha_envio'],
                                              ),
                                              if (msg['_temp'] == true)
                                                'Enviando...',
                                            ]
                                            .where((value) => value.isNotEmpty)
                                            .join(' · '),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                      enabled: !_sending,
                      onSubmitted: (_) {
                        if (!_sending) _sendMessage();
                      },
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
                      onPressed: _sending ? null : _sendMessage,
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
}
