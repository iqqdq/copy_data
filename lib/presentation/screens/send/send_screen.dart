import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/core.dart';
import '../../presentation.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  int _selectedIndex = 0;
  bool _autoSendTriggered = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  final Map<int, bool> _tabInitialized = {0: false, 1: false};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = Provider.of<FileTransferService>(context);

    // Проверяем подключение клиента
    if (service.connectedClients.isNotEmpty) {
      _handleClientConnected();
    } else {
      _handleClientDisconnected();
    }

    // Автоматическая отправка при первом подключении
    if (service.connectedClients.isNotEmpty && !_autoSendTriggered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoSend(service);
      });
    }
  }

  Future<void> _startServer() async {
    final service = Provider.of<FileTransferService>(context, listen: false);
    if (!service.isServerRunning) await service.startServer();
  }

  Future<void> _handleClientConnected() async {
    if (_isConnecting) return;

    if (mounted) {
      // Задержка 2 сек перед установкой флага подключения
      setState(() => _isConnecting = true);
      await Future.delayed(const Duration(seconds: 2));

      // Задержка для показа флага подключения
      setState(() => _isConnected = true);

      // Открытие галереи
      Future.delayed(const Duration(seconds: 2), () async {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
        });

        await _pickAndSendMedia();
      });
    }
  }

  void _handleClientDisconnected() {
    setState(() {
      _autoSendTriggered = false;
      _isConnecting = false;
    });
  }

  Future<void> _triggerAutoSend(FileTransferService service) async {
    if (_isConnecting) return;

    setState(() => _autoSendTriggered = true);
    await Future.delayed(Duration(milliseconds: 500));
    await _pickAndSendMedia();
  }

  Future<void> _pickAndSendMedia() async {
    final service = Provider.of<FileTransferService>(context, listen: false);
    if (service.connectedClients.isEmpty) {
      if (mounted) {
        CustomToast.showToast(
          context: context,
          message: 'The recipient was disconnected',
        );
      }
      return;
    }

    try {
      final pickedFiles = await ImagePicker().pickMultipleMedia();
      final files = <File>[];

      for (final image in pickedFiles) {
        files.add(File(image.path));
      }

      // TODO: SEND FILES TO PROGRESS ?
      if (files.isNotEmpty) {
        if (mounted) {
          final bool isSending = true;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.progress,
            arguments: isSending,
          );
        }

        await service.sendFilesToConnectedClient(files);
      } else {
        setState(() => _autoSendTriggered = false);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showToast(
          context: context,
          message: 'There was an error while sending files',
        );
      }

      setState(() => _autoSendTriggered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);

    return Stack(
      children: [
        Scaffold(
          appBar: CustomAppBar(title: 'Send file'),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                CustomTabBar(
                  tabs: ['Transfer to IOS', 'Transfer to Android'],
                  selectedIndex: _selectedIndex,
                  onTabSelected: (index) {
                    if (!_tabInitialized[index]!) {
                      setState(() {
                        _selectedIndex = index;
                        _tabInitialized[index] = true;
                      });
                    } else {
                      setState(() {
                        _selectedIndex = index;
                      });
                    }
                  },
                ),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: ListView(
                      key: ValueKey<int>(_selectedIndex),
                      padding: EdgeInsets.symmetric(
                        vertical: 24.0,
                      ).copyWith(bottom: MediaQuery.of(context).padding.bottom),
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child: Image.asset(
                                'assets/images/send_file.png',
                                width: 74.0,
                                height: 74.0,
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                _selectedIndex == 0
                                    ? 'Send file to IOS device'
                                    : 'Send file to Android device',
                                style: AppTypography.title20Medium,
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child:
                                  'Tap Receive and scan the QR code on the sending device to get the files'
                                      .toHighlightedText(
                                        highlightedWords: ['Receive'],
                                        style: AppTypography.body16Regular,
                                      ),
                            ),

                            Center(
                              child: Container(
                                height: 250,
                                width: 250,
                                alignment: Alignment.center,
                                child: QrImageView(
                                  data: _selectedIndex == 0
                                      ? 'ios_${service.localIp}:${FileTransferService.PORT}'
                                      : 'android_${service.localIp}:${FileTransferService.PORT}',
                                  version: QrVersions.auto,
                                  backgroundColor: Colors.white,
                                  size: 250,
                                ),
                              ),
                            ),
                          ],
                        ).withDecoration(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 32.0,
                          ),
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(32.0),
                          borderWidth: 3.0,
                          borderColor: AppColors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ConnectionStatusAlert при подключении клиента
        if (_isConnecting) ConnectionStatusAlert(isConnecting: !_isConnected),
      ],
    );
  }
}
