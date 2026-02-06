import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core.dart';

class FileTransferManager extends ChangeNotifier {
  final Map<String, FileTransfer> _activeTransfers = {};
  final Map<String, FileReceiver> _fileReceivers = {};

  // Getters
  Map<String, FileTransfer> get activeTransfers => Map.from(_activeTransfers);
  List<FileTransfer> get transfersList => _activeTransfers.values.toList();

  // Колбэк для уведомления UI об отмене с другой стороны
  void Function(String transferId)? _onRemoteCancellationCallback;

  void setRemoteCancellationCallback(Function(String) callback) {
    _onRemoteCancellationCallback = callback;
  }

  // Управление передачами
  void addTransfer(FileTransfer transfer) {
    _activeTransfers[transfer.transferId] = transfer;
    notifyListeners();
  }

  void removeTransfer(String transferId) {
    _activeTransfers.remove(transferId);
    notifyListeners();
  }

  void updateTransferProgress(String transferId, int receivedBytes) {
    final transfer = _activeTransfers[transferId];
    if (transfer != null) {
      transfer.updateProgress(receivedBytes);
      notifyListeners();
    }
  }

  FileTransfer? getTransfer(String transferId) {
    return _activeTransfers[transferId];
  }

  void clearAllTransfers() {
    _activeTransfers.clear();
    notifyListeners();
  }

  // Управление приемниками файлов
  void addFileReceiver(String transferId, FileReceiver receiver) {
    _fileReceivers[transferId] = receiver;
  }

  FileReceiver? getFileReceiver(String transferId) {
    return _fileReceivers[transferId];
  }

  Future<void> closeFileReceiver(String transferId) async {
    final receiver = _fileReceivers[transferId];
    if (receiver != null) {
      await receiver.close();
      _fileReceivers.remove(transferId);
    }
  }

  Future<void> closeAllFileReceivers() async {
    final receiversCopy = Map<String, FileReceiver>.from(_fileReceivers);
    for (final entry in receiversCopy.entries) {
      try {
        await entry.value.close();
      } catch (e) {
        print('❌ Ошибка закрытия приема ${entry.key}: $e');
      }
    }
    _fileReceivers.clear();
  }

  // Обработка отмены передач
  Future<void> cancelTransfer(
    String transferId, {
    required bool notifyRemote,
    required Function(WebSocket socket, Map<String, dynamic> message)
    sendToClient,
    required Future<void> Function(Map<String, dynamic> message)
    sendClientMessage,
    required List<WebSocket> connectedClients,
  }) async {
    try {
      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        print('❌ Передача не найдена: $transferId');
        return;
      }

      print('⚠️ Отменяем передачу: ${transfer.fileName} ($transferId)');

      // Отправляем сообщение об отмене другой стороне
      if (notifyRemote) {
        final cancelMessage = {
          'type': 'cancel_transfer',
          'transferId': transferId,
          'timestamp': DateTime.now().toIso8601String(),
        };

        if (connectedClients.isNotEmpty) {
          // Сервер отменяет - отправляем клиенту
          for (final client in connectedClients) {
            sendToClient(client, cancelMessage);
          }
        } else {
          // Клиент отменяет - отправляем серверу
          await sendClientMessage(cancelMessage);
        }
      }

      // Закрываем связанные приемники файлов
      final receiverKeys = List<String>.from(_fileReceivers.keys);
      for (final key in receiverKeys) {
        if (key.startsWith(transferId) || key == transferId) {
          print('⚠️ Закрываем приемник файла: $key');
          try {
            await _fileReceivers[key]?.close();
          } catch (e) {
            print('⚠️ Ошибка закрытия приемника $key: $e');
          }
          _fileReceivers.remove(key);
        }
      }

      // Удаляем передачу
      removeTransfer(transferId);

      // Вызываем callback ошибки для передачи
      transfer.onError('Передача отменена пользователем');

      print('✅ Передача успешно отменена: $transferId');
    } catch (e) {
      print('❌ Ошибка при отмене передачи: $e');
      rethrow;
    }
  }

  void handleRemoteCancellation(Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    if (transferId != null) {
      print('⚠️ Получена отмена передачи от другой стороны: $transferId');

      if (_onRemoteCancellationCallback != null) {
        _onRemoteCancellationCallback!(transferId);
      }

      // Закрываем связанные приемники файлов
      final receiverKeys = List<String>.from(_fileReceivers.keys);
      for (final key in receiverKeys) {
        if (key.startsWith(transferId) || key == transferId) {
          _fileReceivers.remove(key);
        }
      }

      // Удаляем передачу
      removeTransfer(transferId);
    }
  }

  @override
  void dispose() {
    closeAllFileReceivers();
    clearAllTransfers();
    super.dispose();
  }
}
