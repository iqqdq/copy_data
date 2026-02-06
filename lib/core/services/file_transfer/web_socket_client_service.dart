// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketClientService extends ChangeNotifier {
  static const int PORT = 8080;

  WebSocketChannel? _clientChannel;
  String? _connectedServerIp;
  String? _connectedServerName;

  // Getters
  WebSocketChannel? get clientChannel => _clientChannel;
  String? get connectedServerIp => _connectedServerIp;
  String? get connectedServerName => _connectedServerName;
  bool get isConnected => _clientChannel != null;

  // Колбэки для обработки сообщений
  Function(Map<String, dynamic>)? _onMessageReceived;
  VoidCallback? _onConnectionLost;
  Function(String)? _onConnectionError;

  void setMessageHandler(Function(Map<String, dynamic>) handler) {
    _onMessageReceived = handler;
  }

  void setConnectionLostHandler(VoidCallback handler) {
    _onConnectionLost = handler;
  }

  void setConnectionErrorHandler(Function(String) handler) {
    _onConnectionError = handler;
  }

  Future<void> connectToServer(
    String serverIp, {
    int port = PORT,
    required Map<String, dynamic> handshakeData,
  }) async {
    try {
      print('⚠️ Подключение к серверу: $serverIp:$port');

      await disconnect();

      notifyListeners();

      final uri = Uri.parse('ws://$serverIp:$port/ws');
      final channel = IOWebSocketChannel.connect(
        uri,
        connectTimeout: Duration(seconds: 10),
      );

      _clientChannel = channel;

      // Настраиваем слушатель сообщений
      channel.stream.listen(
        _handleIncomingMessage,
        onDone: () {
          _handleConnectionLost();
        },
        onError: (error) {
          _handleConnectionError(error.toString());
        },
      );

      // Отправляем handshake
      _sendMessage(handshakeData);

      _connectedServerIp = serverIp;
      _connectedServerName = 'Сервер $serverIp';

      await Future.delayed(Duration(seconds: 1));

      print('✅ Успешно подключено!');
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка подключения: $e');
      _handleConnectionError(e.toString());

      // Пробуем альтернативный порт
      if (port == PORT) {
        await Future.delayed(Duration(seconds: 1));
        try {
          await connectToServer(
            serverIp,
            port: 8081,
            handshakeData: handshakeData,
          );
        } catch (e2) {
          print('❌ Ошибка подключения к порту 8081: $e2');
          throw e;
        }
      }
    }
  }

  void _handleIncomingMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      if (_onMessageReceived != null) {
        _onMessageReceived!(data);
      }
    } catch (e) {
      print('❌ Ошибка обработки входящего сообщения: $e');
    }
  }

  void _handleConnectionLost() {
    print('❌ Соединение с сервером разорвано');
    _clientChannel = null;
    _connectedServerIp = null;

    if (_onConnectionLost != null) {
      _onConnectionLost!();
    }

    notifyListeners();
  }

  void _handleConnectionError(String error) {
    print('⚠️ Ошибка соединения: $error');
    _clientChannel = null;
    _connectedServerIp = null;

    if (_onConnectionError != null) {
      _onConnectionError!(error);
    }

    notifyListeners();
  }

  void _sendMessage(Map<String, dynamic> message) {
    try {
      if (_clientChannel != null) {
        _clientChannel!.sink.add(jsonEncode(message));
      }
    } catch (e) {
      print('❌ Ошибка отправки сообщения: $e');
    }
  }

  Future<void> sendMessage(Map<String, dynamic> message) async {
    _sendMessage(message);
  }

  Future<void> disconnect() async {
    try {
      if (_clientChannel != null) {
        await _clientChannel!.sink.close();
        _clientChannel = null;
      }

      _connectedServerIp = null;
      _connectedServerName = null;
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка отключения: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
