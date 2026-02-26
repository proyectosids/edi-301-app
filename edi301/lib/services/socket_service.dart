import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:edi301/core/api_client_http.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  Completer<void>? _connectedCompleter;

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
    await ensureConnected();
    if (!isConnected) {
      print('⚠️ No conectado, NO join familia_$familyId');
      return;
    }
    _socket!.emit('join_room', 'familia_$familyId');
    print('➡️ join_room familia_$familyId');
  }

  Future<void> joinChatRoom(int salaId) async {
    await ensureConnected();
    if (!isConnected) {
      print('⚠️ No conectado, NO join sala_$salaId');
      return;
    }
    _socket!.emit('join_room', 'sala_$salaId');
    print('➡️ join_room sala_$salaId');
  }

  Future<void> joinInstitucionalRoom() async {
    await ensureConnected();
    if (!isConnected) {
      print('⚠️ No conectado, NO join institucional');
      return;
    }
    _socket!.emit('join_room', 'institucional');
    print('➡️ join_room institucional');
  }

  Future<void> joinUserRoom(int userId) async {
    await ensureConnected();
    if (!isConnected) {
      print('⚠️ No conectado, NO join user_$userId');
      return;
    }
    _socket!.emit('join_room', 'user_$userId');
    print('➡️ join_room user_$userId');
  }

  void leaveRoom(String roomId) {
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
    print('🧹 Socket disposed');
  }
}
