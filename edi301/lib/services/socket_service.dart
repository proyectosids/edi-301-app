import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:edi301/core/api_client_http.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  Completer<void>? _connectedCompleter;
  final Map<String, int> _roomReferences = <String, int>{};

  IO.Socket get socket {
    if (_socket == null) {
      throw StateError('Socket no inicializado. Llama initSocket() primero.');
    }
    return _socket!;
  }

  bool get isReady => _socket != null;
  bool get isConnected => _socket?.connected == true;

  void initSocket() {
    if (_socket != null) return;

    final url = ApiHttp.baseUrl;
    print('🌐 Socket init -> $url');

    _connectedCompleter = Completer<void>();

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setPath('/socket.io') // ✅ importante
          .setTransports(['polling']) // ✅ forzar polling (estable en LAN)
          .disableAutoConnect() // ✅ conectamos manualmente
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(2000)
          .setTimeout(8000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ Socket conectado (id=${_socket!.id})');
      for (final roomId in _roomReferences.keys) {
        _socket!.emit('join_room', roomId);
      }
      if (_connectedCompleter != null && !_connectedCompleter!.isCompleted) {
        _connectedCompleter!.complete();
      }
    });

    _socket!.onDisconnect((_) {
      print('⚠️ Socket desconectado');
      // Prepara otro completer para próximos ensureConnected()
      _connectedCompleter = Completer<void>();
    });

    _socket!.onConnectError((e) => print('❌ Socket connect_error: $e'));
    _socket!.onError((e) => print('❌ Socket error: $e'));

    _socket!.connect();
  }

  Future<void> ensureConnected({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    initSocket();

    if (isConnected) return;

    try {
      await (_connectedCompleter?.future ?? Future.value()).timeout(timeout);
    } catch (_) {
      print('⚠️ ensureConnected timeout. connected=$isConnected');
    }
  }

  Future<void> joinFamilyRoom(int familyId) async {
    await _joinRoom('familia_$familyId');
  }

  Future<void> joinChatRoom(int salaId) async {
    await _joinRoom('sala_$salaId');
  }

  Future<void> joinInstitucionalRoom() async {
    await _joinRoom('institucional');
  }

  Future<void> joinUserRoom(int userId) async {
    await _joinRoom('user_$userId');
  }

  Future<void> _joinRoom(String roomId) async {
    final previousReferences = _roomReferences[roomId] ?? 0;
    _roomReferences[roomId] = previousReferences + 1;
    final wasConnected = isConnected;
    await ensureConnected();
    if (!isConnected) {
      print('⚠️ No conectado; la sala $roomId se recuperará al reconectar');
      return;
    }
    if (wasConnected && previousReferences == 0) {
      _socket!.emit('join_room', roomId);
    }
    print('➡️ join_room $roomId');
  }

  void leaveRoom(String roomId) {
    final references = _roomReferences[roomId] ?? 0;
    if (references > 1) {
      _roomReferences[roomId] = references - 1;
      return;
    }
    _roomReferences.remove(roomId);
    if (_socket == null) return;
    if (!isConnected) {
      print('⚠️ No conectado, NO leave $roomId');
      return;
    }
    _socket!.emit('leave_room', roomId);
    print('⬅️ leave_room $roomId');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedCompleter = null;
    _roomReferences.clear();
    print('🧹 Socket disposed');
  }
}
