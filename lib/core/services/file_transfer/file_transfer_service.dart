import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core.dart';

class FileTransferService extends ChangeNotifier {
  static const int CHUNK_SIZE = 32 * 1024; // 32KB
  static const int PORT = 8080;

  // Зависимости
  final WebSocketServerService _webSocketServer = WebSocketServerService();
  final WebSocketClientService _webSocketClient = WebSocketClientService();
  final VideoConverterService _videoConverter = VideoConverterService();
  final GallerySaverService _gallerySaver = GallerySaverService();
  final FileTransferManager _transferManager = FileTransferManager();

  late ClientFileReceiverService _clientFileReceiver;
  late ServerFileSenderService _serverFileSender;

  // UI состояние
  bool _shouldShowSubscriptionDialog = false;

  // MARK: - Колбэки для завершения передач

  VoidCallback? _onAllTransfersCompletedCallback;
  void Function(List<String> transferIds)? _onClearCompletedTransfersCallback;
  void Function(String transferId)? _onTransferCompletedCallback;

  // MARK: - Колбэки об отсутсвии подписки

  VoidCallback? _onSubscriptionRequired;
  void Function(String message)? _onRemoteCancellationCallback;

  // MARK: - ГЕТТЕРЫ

  // UI состояние
  bool get shouldShowSubscriptionDialog => _shouldShowSubscriptionDialog;

  // Сервер
  bool get isServerRunning => _webSocketServer.isServerRunning;
  String get localIp => _webSocketServer.localIp;
  List<WebSocket> get connectedClients => _webSocketServer.connectedClients;

  // Клиент
  String? get connectedServerIp => _webSocketClient.connectedServerIp;
  String? get connectedServerName => _webSocketClient.connectedServerName;
  bool get isConnected => _webSocketClient.isConnected;

  // Передачи
  Map<String, FileTransfer> get activeTransfers =>
      _transferManager.activeTransfers;

  // MARK: - УПРАВЛЕНИЕ КОЛБЭКАМИ

  void setOnSubscriptionRequiredCallback(VoidCallback callback) {
    _onSubscriptionRequired = callback;
  }

  void removeOnSubscriptionRequiredCallback() {
    _onSubscriptionRequired = null;
  }

  void setRemoteCancellationCallback(Function(String) callback) {
    _onRemoteCancellationCallback = callback;
    _transferManager.setRemoteCancellationCallback(callback);
  }

  // MARK: -  КОЛБЭКИ ДЛЯ ЗАВЕРШЕНИЯ ПЕРЕДАЧ

  void setAllTransfersCompletedCallback(VoidCallback callback) {
    _onAllTransfersCompletedCallback = callback;
  }

  void setTransferCompletedCallback(void Function(String transferId) callback) {
    _onTransferCompletedCallback = callback;
  }

  void setClearCompletedTransfersCallback(
    void Function(List<String> transferIds) callback,
  ) {
    _onClearCompletedTransfersCallback = callback;
  }

  void removeAllCallbacks() {
    _onAllTransfersCompletedCallback = null;
    _onTransferCompletedCallback = null;
    _onClearCompletedTransfersCallback = null;
    _onSubscriptionRequired = null;
    _onRemoteCancellationCallback = null;
  }

  // MARK: - МЕТОДЫ ДЛЯ УВЕДОМЛЕНИЯ О ЗАВЕРШЕНИИ

  void handleAllTransfersCompleted() {
    print('🎯 Сервис получил уведомление о завершении всех передач');

    // Вызываем колбэк, если он установлен
    if (_onAllTransfersCompletedCallback != null) {
      _onAllTransfersCompletedCallback!();
    }

    // Можно выполнить дополнительные действия:
    _performCleanupAfterAllTransfersCompleted();
  }

  void handleTransferCompleted(String transferId) {
    print('✅ Сервис получил уведомление о завершении передачи: $transferId');

    // Вызываем колбэк, если он установлен
    if (_onTransferCompletedCallback != null) {
      _onTransferCompletedCallback!(transferId);
    }

    // Проверяем, все ли передачи завершены
    _checkIfAllTransfersCompleted();
  }

  void clearCompletedTransfers(List<String> transferIds) {
    // Удаляем передачи из активных
    for (final transferId in transferIds) {
      _transferManager.removeTransfer(transferId);
    }

    notifyListeners();

    if (_onClearCompletedTransfersCallback != null) {
      _onClearCompletedTransfersCallback!(transferIds);
    }
  }

  void _checkIfAllTransfersCompleted() {
    final activeTransfers = _transferManager.activeTransfers;

    if (activeTransfers.isEmpty) return;

    bool allCompleted = true;
    bool hasAtLeastOneSuccess = false;

    for (final transfer in activeTransfers.values) {
      final isCompleted = transfer.progress >= 100.0;

      if (!isCompleted) {
        allCompleted = false;
        break;
      } else {
        hasAtLeastOneSuccess = true;
      }
    }

    if (allCompleted && hasAtLeastOneSuccess) {
      print('🎉 Все активные передачи завершены!');
      handleAllTransfersCompleted();
    }
  }

  void _performCleanupAfterAllTransfersCompleted() {
    // 1. Закрываем все file receivers
    _transferManager.closeAllFileReceivers();

    // 2. Очищаем конвертер видео
    _videoConverter.dispose();

    // 3. Оповещаем UI
    notifyListeners();
  }

  // MARK: - ИНИЦИАЛИЗАЦИЯ

  FileTransferService() {
    _initialize();
  }

  Future<void> _initialize() async {
    _serverFileSender = ServerFileSenderService(
      videoConverter: _videoConverter,
      transferManager: _transferManager,
      onProgressUpdated: () {
        // Уведомляем UI
        notifyListeners();
        // Проверяем завершение передач
        _checkIfAllTransfersCompleted();
      },
    );

    _clientFileReceiver = ClientFileReceiverService(
      gallerySaver: _gallerySaver,
      transferManager: _transferManager,
      sendClientMessage: _sendClientMessage,
    );

    _webSocketClient.setMessageHandler(_handleClientMessage);
    _webSocketClient.setConnectionLostHandler(() => notifyListeners());
    _webSocketClient.setConnectionErrorHandler((error) => notifyListeners());

    _transferManager.setRemoteCancellationCallback((message) {
      if (_onRemoteCancellationCallback != null) {
        _onRemoteCancellationCallback!(message);
      }
    });

    // Мониторинг завершения передач в transferManager
    _setupTransferCompletionMonitoring();
  }

  void _setupTransferCompletionMonitoring() {
    // Добавляем слушатель изменений в transferManager
    _transferManager.addListener(() {
      // При любом изменении в transferManager проверяем завершение передач
      _checkIfAllTransfersCompleted();
    });
  }

  // MARK: - СЕРВЕРНЫЕ МЕТОДЫ

  Future<void> startServer() async {
    try {
      _webSocketServer.setMessageHandler(_handleServerMessage);
      _webSocketServer.setClientConnectedHandler((_) => notifyListeners());
      _webSocketServer.setClientDisconnectedHandler((_) => notifyListeners());

      await _webSocketServer.startServer();
      notifyListeners();
    } catch (e, _) {
      print('💥 Ошибка запуска сервера: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopServer() async {
    try {
      print('🛑 Остановка сервера...');

      // 1. Отключаем всех подключенных клиентов
      print('🔌 Отключение подключенных клиентов...');
      final clientsToDisconnect = List<WebSocket>.from(
        _webSocketServer.connectedClients,
      );

      for (final client in clientsToDisconnect) {
        try {
          // Отправляем уведомление об отключении
          await _webSocketServer.sendToClient(client, {
            'type': 'server_stopping',
            'message': 'Сервер останавливается',
            'timestamp': DateTime.now().toIso8601String(),
          });

          // Закрываем соединение
          await client.close();
        } catch (e) {
          print('⚠️ Ошибка при отключении клиента: $e');
        }
      }

      // 2. Закрываем все file receivers
      await _transferManager.closeAllFileReceivers();

      // 3. Очищаем все передачи
      _transferManager.clearAllTransfers();

      // 4. Останавливаем сервер
      await _webSocketServer.stopServer();

      notifyListeners();
      print('✅ Сервер остановлен, все клиенты отключены, передачи очищены');
    } catch (e) {
      print('❌ Ошибка остановки сервера: $e');
    }
  }

  // MARK: - ОТПРАВКА ФАЙЛОВ С СЕРВЕРА

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

  Future<void> sendFilesToConnectedClient(List<File> files) async {
    if (_webSocketServer.connectedClients.isEmpty) {
      throw Exception('Нет подключенных клиентов');
    }
    await sendFilesToClient(files, _webSocketServer.connectedClients.first);
  }

  Future<void> sendFilesToSpecificClient(
    List<File> files,
    WebSocket client,
  ) async {
    await sendFilesToClient(files, client);
  }

  // MARK: - КЛИЕНТСКИЕ МЕТОДЫ

  Future<void> connectToServer(String serverIp, {int port = PORT}) async {
    try {
      final handshakeData = {
        'type': 'handshake',
        'clientInfo': {
          'name': await DeviceUtils.getDeviceName(),
          'platform': Platform.operatingSystem,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _webSocketClient.connectToServer(
        serverIp,
        port: port,
        handshakeData: handshakeData,
      );
      notifyListeners();
    } catch (e) {
      print('💥 ОШИБКА ПОДКЛЮЧЕНИЯ: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _webSocketClient.disconnect();
    notifyListeners();
  }

  Future<void> clearClientTransfers() async {
    print('🧹 Очищаю клиентские передачи...');

    if (_webSocketClient.isConnected) {
      await disconnect();
    }

    await _transferManager.closeAllFileReceivers();
    _transferManager.clearAllTransfers();

    notifyListeners();
    print('✅ Клиентские передачи очищены');
  }

  // MARK: - УПРАВЛЕНИЕ ПЕРЕДАЧАМИ

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

  // MARK: - ОБРАБОТКА СООБЩЕНИЙ СЕРВЕРА

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
        _handleChunkAckFromClient(data);
        break;
      case 'file_received':
        _handleFileReceivedFromClient(data);
        // Уведомляем о завершении передачи файла
        final transferId = data['transferId'] as String?;
        if (transferId != null) {
          handleTransferCompleted(transferId);
        }
        break;
      case 'progress_update':
        _handleProgressUpdateFromClient(data);
        break;
      case 'cancel_transfer':
        _transferManager.handleRemoteCancellation(data);
        break;
      case 'transfer_completed':
        // Новый тип сообщения - уведомление о завершении передачи
        final transferId = data['transferId'] as String?;
        if (transferId != null) {
          handleTransferCompleted(transferId);
        }
        break;
      case 'file_saved': // ДОБАВЛЯЕМ ОБРАБОТКУ ПОДТВЕРЖДЕНИЯ СОХРАНЕНИЯ
        _handleFileSavedFromClient(data);
        break;
    }
  }

  void _handleFileSavedFromClient(Map<String, dynamic> data) {
    try {
      print('✅ Получено подтверждение сохранения файла от клиента');
      _serverFileSender.handleFileSavedConfirmation(data);
    } catch (e) {
      print('❌ Ошибка обработки подтверждения сохранения: $e');
    }
  }

  Future<void> _handleClientHandshake(
    WebSocket socket,
    Map<String, dynamic> data,
  ) async {
    print('🤝 Handshake от клиента: ${data['clientInfo']}');

    if (!isSubscribed.value) {
      print('⚠️ У сервера нет подписки, отправляю уведомление клиенту');

      await _webSocketServer.sendToClient(socket, {
        'type': 'subscription_required',
        'timestamp': DateTime.now().toIso8601String(),
      });

      await Future.delayed(Duration(milliseconds: 500));
      try {
        await socket.close();
      } catch (e) {
        print('⚠️ Ошибка закрытия сокета: $e');
      }

      notifyListeners();
      return;
    }

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

  void _handleProgressUpdateFromClient(Map<String, dynamic> data) {
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

        final transfer = _transferManager.getTransfer(transferId);
        if (transfer != null) {
          transfer.updateProgress(receivedBytes);
          notifyListeners();

          // Проверяем, завершена ли передача
          if (progress >= 100.0) {
            handleTransferCompleted(transferId);
          }
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки прогресса от клиента: $e');
    }
  }

  void _handleChunkAckFromClient(Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    final receivedBytes = data['receivedBytes'] as int?;

    if (transferId != null && receivedBytes != null) {
      print(
        '✅ Подтверждение чанка от клиента: $transferId - ${FileUtils.formatBytes(receivedBytes)}',
      );
    }
  }

  void _handleFileReceivedFromClient(Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    final fileName = data['fileName'] as String?;

    if (transferId != null && fileName != null) {
      print('🎉 Клиент подтвердил получение файла: $fileName');

      // Можно отправить подтверждение о завершении передачи
      try {
        final client = _webSocketServer.connectedClients.firstOrNull;
        if (client != null) {
          _webSocketServer.sendToClient(client, {
            'type': 'transfer_completed',
            'transferId': transferId,
            'fileName': fileName,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        print('⚠️ Ошибка отправки подтверждения завершения: $e');
      }
    }
  }

  // MARK: - ОБРАБОТКА СООБЩЕНИЙ КЛИЕНТА

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
      case 'transfer_completed':
        final transferId = data['transferId'] as String?;
        if (transferId != null) {
          handleTransferCompleted(transferId);
        }
        break;
    }
  }

  void _handleSubscriptionRequired(Map<String, dynamic> data) {
    print('⚠️ Получено сообщение: требуется подписка на сервере');

    disconnect();
    _shouldShowSubscriptionDialog = true;
    notifyListeners();

    if (_onSubscriptionRequired != null) {
      _onSubscriptionRequired!();
    }
  }

  void resetSubscriptionDialogFlag() {
    _shouldShowSubscriptionDialog = false;
    notifyListeners();
  }

  Future<void> _sendClientMessage(Map<String, dynamic> message) async {
    await _webSocketClient.sendMessage(message);
  }

  // MARK: - УПРАВЛЕНИЕ МЕДИА

  Future<void> openMediaInGallery(ReceivedMedia media) async {
    try {
      print('📱 Открытие медиа: ${media.file.path}');
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка открытия медиа: $e');
    }
  }

  // MARK: - ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ

  bool areAllTransfersCompleted() {
    final activeTransfers = _transferManager.activeTransfers;

    if (activeTransfers.isEmpty) return false;

    for (final transfer in activeTransfers.values) {
      if (transfer.progress < 100.0) {
        return false;
      }
    }

    return true;
  }

  List<FileTransfer> getCompletedTransfers() {
    return _transferManager.activeTransfers.values
        .where((transfer) => transfer.progress >= 100.0)
        .toList();
  }

  List<FileTransfer> getInProgressTransfers() {
    return _transferManager.activeTransfers.values
        .where((transfer) => transfer.progress < 100.0 && transfer.progress > 0)
        .toList();
  }

  @override
  void dispose() {
    removeAllCallbacks();
    _transferManager.dispose();
    _webSocketServer.dispose();
    _videoConverter.dispose();

    stopServer();
    disconnect();
    super.dispose();
  }
}
