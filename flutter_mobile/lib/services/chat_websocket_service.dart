import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ChatWebSocketService {
  WebSocket? _socket;
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  String? _currentWsUrl;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String wsUrl) async {
    _currentWsUrl = wsUrl;
    try {
      _socket = await WebSocket.connect(wsUrl);
      _isConnected = true;
      _connectionController.add(true);

      _socket!.listen(
        (data) {
          try {
            final decoded = jsonDecode(data.toString()) as Map<String, dynamic>;
            _messageController.add(decoded);
          } catch (e) {
            debugPrint('[ChatWS] JSON decode error: $e');
          }
        },
        onError: (err) {
          debugPrint('[ChatWS] Error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[ChatWS] Connection closed by server.');
          _handleDisconnect();
        },
      );

      _startHeartbeat();
    } catch (e) {
      debugPrint('[ChatWS] Connection error: $e');
      _handleDisconnect();
    }
  }

  void sendMessage(Map<String, dynamic> payload) {
    if (_socket != null && _isConnected) {
      _socket!.add(jsonEncode(payload));
    }
  }

  void sendTypingStatus(bool isTyping) {
    sendMessage({
      'action': 'typing',
      'is_typing': isTyping,
    });
  }

  void sendReadReceipt(int lastMessageId) {
    sendMessage({
      'action': 'read_receipt',
      'last_message_id': lastMessageId,
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected) {
        sendMessage({'action': 'ping'});
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _connectionController.add(false);
    _heartbeatTimer?.cancel();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _currentWsUrl != null) {
        debugPrint('[ChatWS] Attempting auto reconnect...');
        connect(_currentWsUrl!);
      }
    });
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.close();
    _isConnected = false;
    _connectionController.add(false);
  }
}
