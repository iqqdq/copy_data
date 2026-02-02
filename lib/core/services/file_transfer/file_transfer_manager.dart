import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core.dart';

class FileTransferManager extends ChangeNotifier {
  final Map<String, FileTransfer> _activeTransfers = {};
  final Map<String, FileReceiver> _fileReceivers = {};

  // Добавляем Set для хранения ID отмененных передач
  final Set<String> _cancelledTransferIds = {};

  // Колбэк для уведомления UI об отмене с другой стороны
  void Function(String message)? _onRemoteCancellationCallback;

  // Колбэк для уведомления о прогрессе
  void Function(String transferId, double progress)? _onProgressCallback;

  // Getters
  Map<String, FileTransfer> get activeTransfers => Map.from(_activeTransfers);
  List<FileTransfer> get transfersList => _activeTransfers.values.toList();

  // Проверка, отменена ли передача
  bool isTransferCancelled(String transferId) {
    return _cancelledTransferIds.contains(transferId);
  }

  // Получение всех отмененных ID
  Set<String> get cancelledTransferIds => Set.from(_cancelledTransferIds);

  // Проверка, все ли передачи завершены или отменены
  bool get areAllTransfersCompleteOrCancelled {
    if (_activeTransfers.isEmpty) return false;

    return _activeTransfers.values.every((transfer) {
      final isCancelled = isTransferCancelled(transfer.transferId);
      final isCompleted = transfer.progress >= 100;
      return isCancelled || isCompleted;
    });
  }

  // Проверка, есть ли активные (незавершенные и неотмененные) передачи
  bool get hasActiveTransfers {
    if (_activeTransfers.isEmpty) return false;

    return _activeTransfers.values.any((transfer) {
      final isCancelled = isTransferCancelled(transfer.transferId);
      final isCompleted = transfer.progress >= 100;
      return !isCancelled && !isCompleted;
    });
  }

  // Установка callback-ов
  void setRemoteCancellationCallback(Function(String) callback) {
    _onRemoteCancellationCallback = callback;
  }

  void setProgressCallback(Function(String, double) callback) {
    _onProgressCallback = callback;
  }

  // Управление передачами
  void addTransfer(FileTransfer transfer) {
    _activeTransfers[transfer.transferId] = transfer;
    notifyListeners();
  }

  void removeTransfer(String transferId) {
    _activeTransfers.remove(transferId);
    _cancelledTransferIds.remove(transferId); // Удаляем из отмененных
    notifyListeners();
  }

  void updateTransferProgress(String transferId, int receivedBytes) {
    final transfer = _activeTransfers[transferId];
    if (transfer != null) {
      transfer.updateProgress(receivedBytes);

      // Уведомляем о прогрессе если callback установлен
      if (_onProgressCallback != null) {
        _onProgressCallback!(transferId, transfer.progress);
      }

      notifyListeners();
    }
  }

  void updateProgressPercent(String transferId, double progressPercent) {
    final transfer = _activeTransfers[transferId];
    if (transfer != null) {
      final bytes = (progressPercent / 100.0 * transfer.fileSize).toInt();
      updateTransferProgress(transferId, bytes);
    }
  }

  FileTransfer? getTransfer(String transferId) {
    return _activeTransfers[transferId];
  }

  void clearAllTransfers() {
    _activeTransfers.clear();
    _cancelledTransferIds.clear();
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
        print('⚠️ Ошибка закрытия приемника ${entry.key}: $e');
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
        print('⚠️ Передача не найдена: $transferId');
        return;
      }

      print('🛑 Отменяем передачу: ${transfer.fileName} ($transferId)');

      // Добавляем в список отмененных
      _cancelledTransferIds.add(transferId);

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
          print('📤 Отправлена отмена серверу: $transferId');
        }
      }

      // Закрываем связанные приемники файлов
      final receiverKeys = List<String>.from(_fileReceivers.keys);
      for (final key in receiverKeys) {
        if (key.startsWith(transferId) || key == transferId) {
          print('🛑 Закрываем приемник файла: $key');
          try {
            await _fileReceivers[key]?.close();
          } catch (e) {
            print('⚠️ Ошибка закрытия приемника $key: $e');
          }
          _fileReceivers.remove(key);
        }
      }

      // Вызываем callback ошибки для передачи
      transfer.onError('Передача отменена пользователем');

      // Удаляем передачу из активных (но сохраняем в cancelledTransferIds)
      // Можно не удалять сразу, чтобы UI мог отобразить отмененную передачу
      // _activeTransfers.remove(transferId);

      notifyListeners();

      print('✅ Передача успешно отменена: $transferId');
    } catch (e) {
      print('❌ Ошибка при отмене передачи: $e');
      rethrow;
    }
  }

  // Обработка удаленных отмен
  void handleRemoteCancellation(Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    if (transferId != null) {
      print('🛑 Получена отмена передачи от другой стороны: $transferId');

      if (_onRemoteCancellationCallback != null) {
        // Передаем transferId в callback
        _onRemoteCancellationCallback!(transferId);
      }

      // Закрываем связанные приемники файлов ТОЛЬКО для этой передачи
      final receiverKeys = List<String>.from(_fileReceivers.keys);
      for (final key in receiverKeys) {
        if (key.startsWith(transferId) || key == transferId) {
          print('🛑 Закрываем приемник файла: $key');
          _fileReceivers.remove(key);
        }
      }

      // Удаляем только ЭТУ передачу
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
