// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WebSocketServerService extends ChangeNotifier {
  static const int PORT = 8080;

  bool _isServerRunning = false;
  String _localIp = '';
  HttpServer? _httpServer;
  final List<WebSocket> _connectedClients = [];
  final Map<String, ClientInfo> _clientInfo = {};

  bool get isServerRunning => _isServerRunning;
  String get localIp => _localIp;
  List<WebSocket> get connectedClients => List.from(_connectedClients);

  // Callbacks для обработки сообщений
  Function(WebSocket, Map<String, dynamic>)? _onMessage;
  Function(WebSocket)? _onClientConnected;
  Function(WebSocket)? _onClientDisconnected;

  void setMessageHandler(Function(WebSocket, Map<String, dynamic>) handler) {
    _onMessage = handler;
  }

  void setClientConnectedHandler(Function(WebSocket) handler) {
    _onClientConnected = handler;
  }

  void setClientDisconnectedHandler(Function(WebSocket) handler) {
    _onClientDisconnected = handler;
  }

  Future<void> startServer() async {
    try {
      _localIp = await _getLocalIp();
      print('✅ IP адрес сервера: $_localIp');

      bool serverStarted = false;

      for (var port in [PORT, 8081, 8082, 8083, 8084]) {
        try {
          print('⚠️ Пробую запустить на порту $port...');

          _httpServer = await HttpServer.bind(
            InternetAddress.anyIPv4,
            port,
            shared: true,
          );

          print('✅ HTTP сервер запущен на порту $port');

          _httpServer!.listen(_handleWebSocket);

          serverStarted = true;

          _isServerRunning = true;
          print('✅ WEB SOCKET сервер запущен! ws://$_localIp:$port');

          notifyListeners();
          break;
        } catch (e) {
          print('❌ Порт $port занят: $e');

          if (_httpServer != null) {
            await _httpServer!.close();
            _httpServer = null;
          }

          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      if (!serverStarted) {
        throw Exception('Не удалось запустить сервер ни на одном порту');
      }
    } catch (e, _) {
      print('❌ Ошибка запуска сервера: $e');

      _isServerRunning = false;
      notifyListeners();
      rethrow;
    }
  }

  void _handleWebSocket(HttpRequest request) async {
    try {
      print('✅ Входящее подключение: ${request.uri}');

      if (request.uri.path == '/ws') {
        final webSocket = await WebSocketTransformer.upgrade(request);
        print('✅ WebSocket клиент подключен');

        _connectedClients.add(webSocket);

        final clientName =
            request.headers.value('client-name') ?? 'Неизвестный';
        _clientInfo[webSocket.hashCode.toString()] = ClientInfo(
          name: clientName,
          connectedAt: DateTime.now(),
        );

        if (_onClientConnected != null) {
          _onClientConnected!(webSocket);
        }

        notifyListeners();

        webSocket.listen(
          (message) => _handleClientMessage(webSocket, message),
          onDone: () => _handleClientDisconnect(webSocket),
          onError: (error) => _handleClientDisconnect(webSocket, error: error),
        );
      } else {
        request.response.statusCode = 404;
        request.response.write('WebSocket endpoint: /ws');
        await request.response.close();
      }
    } catch (e) {
      print('❌ Ошибка обработки подключения: $e');
    }
  }

  void _handleClientMessage(WebSocket socket, dynamic message) {
    try {
      final data = jsonDecode(message.toString());

      if (_onMessage != null) {
        _onMessage!(socket, data);
      }
    } catch (e) {
      print('❌ Ошибка обработки сообщения от клиента: $e');
    }
  }

  void _handleClientDisconnect(WebSocket socket, {Object? error}) {
    if (error != null) {
      print('⚠️ Ошибка от клиента: $error');
    } else {
      print('❌ Клиент отключился');
    }

    _connectedClients.remove(socket);
    _clientInfo.remove(socket.hashCode.toString());

    if (_onClientDisconnected != null) {
      _onClientDisconnected!(socket);
    }

    notifyListeners();
  }

  Future<void> sendToClient(
    WebSocket client,
    Map<String, dynamic> message,
  ) async {
    try {
      client.add(jsonEncode(message));
    } catch (e) {
      print('❌ Ошибка отправки сообщения клиенту: $e');
      _handleClientDisconnect(client);
    }
  }

  Future<void> disconnectClient(WebSocket client) async {
    try {
      await client.close();
      _handleClientDisconnect(
        client,
      ); // Вызовет стандартную обработку отключения
    } catch (e) {
      print('⚠️ Ошибка принудительного отключения клиента: $e');
    }
  }

  Future<void> broadcast(Map<String, dynamic> message) async {
    final messageJson = jsonEncode(message);
    final disconnectedClients = <WebSocket>[];

    for (final client in _connectedClients) {
      try {
        client.add(messageJson);
      } catch (e) {
        print('❌ Ошибка отправки сообщения клиенту: $e');
        disconnectedClients.add(client);
      }
    }

    // Удаляем отключенных клиентов
    for (final client in disconnectedClients) {
      _handleClientDisconnect(client);
    }
  }

  Future<void> stopServer() async {
    try {
      print('🛑 Остановка сервера...');

      // Создаем копию для безопасной итерации
      final clientsCopy = List<WebSocket>.from(_connectedClients);

      // Закрываем все подключения клиентов
      for (final client in clientsCopy) {
        try {
          await client.close();
        } catch (e) {
          print('⚠️ Ошибка закрытия клиента: $e');
        }
      }
      _connectedClients.clear();
      _clientInfo.clear();

      // Закрываем HTTP сервер
      if (_httpServer != null) {
        await _httpServer!.close();
        _httpServer = null;
      }

      // Сбрасываем состояние
      _isServerRunning = false;

      notifyListeners();

      print('✅ Сервер остановлен');
    } catch (e) {
      print('❌ Ошибка остановки сервера: $e');
      rethrow;
    }
  }

  Future<String> _getLocalIp() async {
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;
            if (ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                ip.startsWith('172.16.')) {
              return ip;
            }
          }
        }
      }

      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('⚠️ Ошибка получения IP: $e');
    }

    return '127.0.0.1';
  }

  ClientInfo? getClientInfo(WebSocket client) {
    return _clientInfo[client.hashCode.toString()];
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}

class ClientInfo {
  final String name;
  final DateTime connectedAt;

  ClientInfo({required this.name, required this.connectedAt});
}
