// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../app.dart';
import '../../core.dart';

class FileTransferService extends ChangeNotifier {
  static const int CHUNK_SIZE = 32 * 1024; // 32KB
  static const int PORT = 8080;

  final WebSocketServerService _webSocketServer = WebSocketServerService();
  final WebSocketClientService _webSocketClient = WebSocketClientService();

  final MediaManagerService _mediaManager = MediaManagerService();
  final VideoConverterService _videoConverter = VideoConverterService();
  final GallerySaverService _gallerySaver = GallerySaverService();

  final FileTransferManager _transferManager = FileTransferManager();

  late ClientFileReceiverService _clientFileReceiver;
  late ServerFileSenderService _serverFileSender;

  String _status = 'Готов';
  bool _shouldShowSubscriptionDialog = false;

  // State
  bool get shouldShowSubscriptionDialog => _shouldShowSubscriptionDialog;

  // Server
  bool get isServerRunning => _webSocketServer.isServerRunning;
  String get localIp => _webSocketServer.localIp;
  List<WebSocket> get connectedClients => _webSocketServer.connectedClients;
  String get status => _status; // TODO: DELETE?

  // Client
  String? get connectedServerIp => _webSocketClient.connectedServerIp;
  String? get connectedServerName => _webSocketClient.connectedServerName;
  bool get isConnected => _webSocketClient.isConnected;

  // Transfer
  Map<String, FileTransfer> get activeTransfers =>
      _transferManager.activeTransfers;

  // Media
  List<ReceivedMedia> get receivedMedia => _mediaManager.receivedMedia;

  // Колбэк для уведомления UI об отсутствии подписки
  VoidCallback? _onSubscriptionRequired;

  void setOnSubscriptionRequiredCallback(VoidCallback callback) {
    _onSubscriptionRequired = callback;
  }

  void removeOnSubscriptionRequiredCallback() {
    _onSubscriptionRequired = null;
  }

  // Колбэк для уведомления UI об отмене с другой стороны
  void Function(String message)? _onRemoteCancellationCallback;

  void setRemoteCancellationCallback(Function(String) callback) {
    _onRemoteCancellationCallback = callback;
    _transferManager.setRemoteCancellationCallback(callback);
  }

  FileTransferService() {
    _initialize();
  }

  Future<void> _initialize() async {
    _serverFileSender = ServerFileSenderService(
      videoConverter: _videoConverter,
      transferManager: _transferManager,
    );

    _clientFileReceiver = ClientFileReceiverService(
      mediaManager: _mediaManager,
      gallerySaver: _gallerySaver,
      transferManager: _transferManager,
      sendClientMessage: _sendClientMessage,
    );

    _webSocketClient.setMessageHandler(_handleClientMessage);

    _webSocketClient.setConnectionLostHandler(() {
      _status = 'Отключено от сервера';
      notifyListeners();
    });

    _webSocketClient.setConnectionErrorHandler((error) {
      _status = 'Ошибка: $error';
      notifyListeners();
    });

    _transferManager.setRemoteCancellationCallback((message) {
      if (_onRemoteCancellationCallback != null) {
        _onRemoteCancellationCallback!(message);
      }
    });
  }

  @override
  void dispose() {
    // Освобождаем ресурсы сервисов
    _transferManager.dispose();
    _webSocketServer.dispose();
    _videoConverter.dispose();
    _mediaManager.dispose();

    stopServer();
    disconnect();
    super.dispose();
  }

  // MARK: - СЕРВЕРНЫЕ МЕТОДЫ

  Future<void> startServer() async {
    try {
      _status = 'Запуск сервера...';
      notifyListeners();

      // Настраиваем обработчики сообщений
      _webSocketServer.setMessageHandler(_handleServerMessage);
      _webSocketServer.setClientConnectedHandler((client) {
        notifyListeners();
      });
      _webSocketServer.setClientDisconnectedHandler((client) {
        notifyListeners();
      });

      await _webSocketServer.startServer();

      _status = 'Сервер запущен ✅\nIP: ${_webSocketServer.localIp}';
      notifyListeners();
    } catch (e, stackTrace) {
      print('💥 ОШИБКА ЗАПУСКА СЕРВЕРА: $e');
      print('Stack: $stackTrace');

      _status = 'Ошибка: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _handleServerMessage(WebSocket socket, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'handshake':
        _handleClientHandshake(socket, data);
        break;
      case 'metadata_ack':
        print('✅ Клиент готов принимать файл');
        break;
      case 'chunk_ack':
        _handleChunkAckFromClient(socket, data);
        break;
      case 'file_received':
        _handleFileReceivedFromClient(socket, data);
        break;
      case 'progress_update':
        _handleProgressUpdateFromClient(socket, data);
        break;
      case 'cancel_transfer':
        _handleCancelTransferFromClient(socket, data);
        break;
    }
  }

  void _handleCancelTransferFromClient(
    WebSocket socket,
    Map<String, dynamic> data,
  ) {
    try {
      _transferManager.handleRemoteCancellation(data);
    } catch (e) {
      print('❌ Ошибка обработки отмены от клиента: $e');
    }
  }

  void _handleProgressUpdateFromClient(
    WebSocket socket,
    Map<String, dynamic> data,
  ) {
    try {
      final transferId = data['transferId'] as String?;
      final progress = data['progress'] as double?;
      final receivedBytes = data['receivedBytes'] as int?;
      final totalBytes = data['totalBytes'] as int?;

      if (transferId != null &&
          progress != null &&
          receivedBytes != null &&
          totalBytes != null) {
        print(
          '📈 Прогресс от клиента (прием): $transferId - ${progress.toStringAsFixed(1)}% '
          '(${FileUtils.formatBytes(receivedBytes)} / ${FileUtils.formatBytes(totalBytes)})',
        );

        // Обновляем прогресс на сервере для отображения прогресса на клиенте
        final transfer = _transferManager.getTransfer(transferId);
        if (transfer != null) {
          // Обновляем прогресс на стороне клиента (для отображения на сервере)
          transfer.updateProgress(receivedBytes);
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки прогресса от клиента: $e');
    }
  }

  Future<void> _handleClientHandshake(
    WebSocket socket,
    Map<String, dynamic> data,
  ) async {
    print('🤝 Handshake от клиента: ${data['clientInfo']}');

    // Проверяем наличие подписки
    if (!isSubscribed.value) {
      print('⚠️ У сервера нет подписки, отправляю уведомление клиенту');

      await _webSocketServer.sendToClient(socket, {
        'type': 'subscription_required',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Закрываем соединение - сервис сам удалит клиента
      await Future.delayed(Duration(milliseconds: 500));
      try {
        await socket.close();
      } catch (e) {
        print('⚠️ Ошибка закрытия сокета: $e');
      }

      notifyListeners();
      return;
    }

    // Если подписка есть - продолжаем обычный handshake
    await _webSocketServer.sendToClient(socket, {
      'type': 'handshake_ack',
      'message': 'Добро пожаловать',
      'serverInfo': {
        'name': await DeviceUtils.getDeviceName(),
        'platform': Platform.operatingSystem,
        'ip': _webSocketServer.localIp,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }

  void _handleChunkAckFromClient(WebSocket socket, Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    final receivedBytes = data['receivedBytes'] as int?;

    if (transferId != null && receivedBytes != null) {
      print(
        '✅ Подтверждение чанка от клиента: $transferId - ${FileUtils.formatBytes(receivedBytes)}',
      );
    }
  }

  void _handleFileReceivedFromClient(
    WebSocket socket,
    Map<String, dynamic> data,
  ) {
    final transferId = data['transferId'] as String?;
    final fileName = data['fileName'] as String?;

    if (transferId != null && fileName != null) {
      print('🎉 Клиент подтвердил получение файла: $fileName');
    }
  }

  // Метод для очистки передач на клиенте
  Future<void> clearClientTransfers() async {
    print('🧹 Очищаю клиентские передачи...');

    // Отключаем от сервера
    if (_webSocketClient.isConnected) {
      await disconnect();
    }

    // Закрываем все активные файловые потоки
    await _transferManager.closeAllFileReceivers();
    _transferManager.clearAllTransfers();

    // Сбрасываем состояния
    _status = 'Готов';

    notifyListeners();
    print('✅ Клиентские передачи очищены');
  }

  Future<void> stopServer() async {
    try {
      print('🛑 Остановка сервера...');

      // Очищаем все активные передачи
      await _transferManager.closeAllFileReceivers();
      _transferManager.clearAllTransfers();

      // Останавливаем WebSocket сервер
      await _webSocketServer.stopServer();

      // Сбрасываем состояния
      _status = 'Сервер остановлен';

      notifyListeners();

      print('✅ Сервер остановлен, все передачи очищены');
    } catch (e) {
      print('❌ Ошибка остановки сервера: $e');
    }
  }

  // MARK: - ОТПРАВКА ФАЙЛОВ С СЕРВЕРА НА КЛИЕНТ

  Future<void> sendFilesToClient(
    List<File> files,
    WebSocket? targetClient,
  ) async {
    if (_webSocketServer.connectedClients.isEmpty) {
      throw Exception('Нет подключенных клиентов');
    }

    final client = targetClient ?? _webSocketServer.connectedClients.first;

    await _serverFileSender.sendFilesToClient(
      files,
      client,
      _webSocketServer.sendToClient,
    );

    notifyListeners();
  }

  Future<void> cancelTransfer(String transferId) async {
    try {
      print('🛑 Инициация отмены передачи: $transferId');
      await _transferManager.cancelTransfer(
        transferId,
        notifyRemote: true,
        sendToClient: _webSocketServer.sendToClient,
        sendClientMessage: _webSocketClient.sendMessage,
        connectedClients: _webSocketServer.connectedClients,
      );
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка при отмене передачи: $e');
    }
  }
  // MARK: - КЛИЕНТСКИЕ МЕТОДЫ (ПРИЕМ ФАЙЛОВ)

  void resetSubscriptionDialogFlag() {
    _shouldShowSubscriptionDialog = false;
    notifyListeners();
  }

  Future<void> connectToServer(String serverIp, {int port = PORT}) async {
    try {
      final handshakeData = {
        'type': 'handshake',
        'clientInfo': {
          'name': await DeviceUtils.getDeviceName(),
          'platform': Platform.operatingSystem,
          'version': '1.0.0',
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _webSocketClient.connectToServer(
        serverIp,
        port: port,
        handshakeData: handshakeData,
      );

      _status = 'Подключено к серверу';
      notifyListeners();
    } catch (e) {
      print('💥 ОШИБКА ПОДКЛЮЧЕНИЯ: $e');
      _status = 'Ошибка: ${e.toString().split('\n').first}';
      notifyListeners();
      rethrow;
    }
  }

  void _handleClientMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'handshake_ack':
        notifyListeners();
        break;
      case 'subscription_required':
        _handleSubscriptionRequired(data);
        break;
      case 'group_metadata':
        _clientFileReceiver.handleGroupMetadata(data);
        notifyListeners();
        break;
      case 'file_metadata':
        _clientFileReceiver.handleFileMetadata(data);
        notifyListeners();
        break;
      case 'file_chunk':
        _clientFileReceiver.handleFileChunk(data);
        break;
      case 'progress_update':
        _clientFileReceiver.handleProgressUpdate(data);
        notifyListeners();
        break;
      case 'cancel_transfer':
        _transferManager.handleRemoteCancellation(data);
        break;
    }
  }

  void _handleSubscriptionRequired(Map<String, dynamic> data) {
    print('⚠️ Получено сообщение: требуется подписка на сервере');

    disconnect();

    _shouldShowSubscriptionDialog = true;
    notifyListeners();

    // Вызываем callback если он установлен
    if (_onSubscriptionRequired != null) {
      _onSubscriptionRequired!();
    }
  }

  void _sendClientMessage(Map<String, dynamic> message) {
    _webSocketClient.sendMessage(message);
  }

  Future<void> disconnect() async {
    await _webSocketClient.disconnect();
    _status = 'Отключено';
    notifyListeners();
  }

  // MARK: - УПРАВЛЕНИЕ ПОЛУЧЕННЫМИ МЕДИА

  Future<void> openMediaInGallery(ReceivedMedia media) async {
    try {
      print('📱 Открытие медиа: ${media.file.path}');
      _status = 'Открытие: ${media.fileName}';
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка открытия медиа: $e');
    }
  }

  Future<bool> deleteMedia(ReceivedMedia media) async {
    return await _mediaManager.deleteMedia(media);
  }

  Future<void> refreshReceivedMedia() async {
    await _mediaManager.refreshMedia();
  }

  // MARK: - ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ UI

  // Метод для сервера: отправить файлы клиенту
  Future<void> sendFilesToConnectedClient(List<File> files) async {
    if (_webSocketServer.connectedClients.isEmpty) {
      throw Exception('Нет подключенных клиентов');
    }

    // Отправляем файлы первому подключенному клиенту
    await sendFilesToClient(files, _webSocketServer.connectedClients.first);
  }

  // Метод для сервера: отправить файлы конкретному клиенту
  Future<void> sendFilesToSpecificClient(
    List<File> files,
    WebSocket client,
  ) async {
    await sendFilesToClient(files, client);
  }

  // Получить список подключенных клиентов (для UI сервера)

  // Получить информацию о клиенте
  String getClientInfo(WebSocket client) {
    final index = _webSocketServer.connectedClients.indexOf(client);
    return 'Клиент ${index + 1}';
  }
}
