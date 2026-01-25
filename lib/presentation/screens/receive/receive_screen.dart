import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/core.dart';
import '../../presentation.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  int _selectedIndex = 0;
  bool _isSending = false;
  bool _showProgress = false;
  bool _autoSendTriggered = false;
  bool _isQrLoading = true;
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
    if (service.connectedClients.isNotEmpty &&
        !_autoSendTriggered &&
        !_showProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoSend(service);
      });
    }
  }

  Future<void> _startServer() async {
    final service = Provider.of<FileTransferService>(context, listen: false);
    if (!service.isServerRunning) {
      await service.startServer();
    }
    if (mounted) {
      Future.delayed(Duration(milliseconds: 300), () {
        setState(() {
          _isQrLoading = false;
        });
      });
    }
  }

  Future<void> _triggerAutoSend(FileTransferService service) async {
    setState(() {
      _showProgress = true;
      _autoSendTriggered = true;
    });
    await Future.delayed(Duration(milliseconds: 500));
    await _pickAndSendMedia();
  }

  Future<void> _pickAndSendMedia() async {
    final service = Provider.of<FileTransferService>(context, listen: false);
    if (service.connectedClients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Нет подключенных клиентов')));
      }
      return;
    }
    setState(() => _isSending = true);
    try {
      final pickedFiles = await ImagePicker().pickMultipleMedia();
      final files = <File>[];
      for (final image in pickedFiles) {
        files.add(File(image.path));
      }
      if (files.isNotEmpty) {
        await service.sendFilesToConnectedClient(files);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${files.length} файл(ов) отправлено клиенту'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _showProgress = false;
          _autoSendTriggered = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _showProgress = false;
        _autoSendTriggered = false;
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: _showProgress ? 'Sending files' : 'Send file',
      ),
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
                    _isQrLoading = true;
                  });
                  Future.delayed(Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() {
                        _selectedIndex = index;
                        _isQrLoading = false;
                        _tabInitialized[index] = true;
                      });
                    }
                  });
                } else {
                  setState(() {
                    _selectedIndex = index;
                  });
                }
              },
            ),
            _showProgress
                ? ProgressScreen(isSending: true)
                : Expanded(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      child: _isQrLoading
                          ? Container(
                              padding: EdgeInsets.symmetric(vertical: 24.0)
                                  .copyWith(
                                    bottom: MediaQuery.of(
                                      context,
                                    ).padding.bottom,
                                  ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(32.0),
                                  border: Border.all(
                                    width: 3.0,
                                    color: AppColors.black,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 32.0,
                                ),
                                child: Center(child: CustomSpinnerLoader()),
                              ),
                            )
                          : ListView(
                              key: ValueKey<int>(_selectedIndex),
                              padding: EdgeInsets.symmetric(vertical: 24.0)
                                  .copyWith(
                                    bottom: MediaQuery.of(
                                      context,
                                    ).padding.bottom,
                                  ),
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
                                                baseStyle:
                                                    AppTypography.body16Light,
                                                highlightColor:
                                                    AppColors.accent,
                                              ),
                                    ),
                                    QrImageView(
                                      data: _selectedIndex == 0
                                          ? 'ios_${service.localIp}:${FileTransferService.PORT}'
                                          : 'android_${service.localIp}:${FileTransferService.PORT}',
                                      version: QrVersions.auto,
                                      backgroundColor: Colors.white,
                                    ),
                                  ],
                                ).withDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(32.0),
                                  borderWidth: 3.0,
                                  borderColor: AppColors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                    vertical: 32.0,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
