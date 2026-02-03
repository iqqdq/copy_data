import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  late SendController _controller;

  @override
  void initState() {
    super.initState();

    _controller = SendController(
      showPremiumDialog: (title, message, onGetPremiumPressed) async {
        return PremiumRequiredDialog.show(
          context,
          title: title,
          message: message,
          onGetPermiumPressed: onGetPremiumPressed,
        );
      },
      showToast: (message) {
        CustomToast.showToast(context: context, message: message);
      },
      navigateTo: (route, {arguments}) async {
        if (mounted) {
          Navigator.pushReplacementNamed(context, route, arguments: arguments);
        }
      },
      fileTransferServiceCallback: () {
        return Provider.of<FileTransferService>(context, listen: false);
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.startServer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = Provider.of<FileTransferService>(context, listen: true);
    if (mounted) _controller.checkConnectionStatus(service);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return Stack(
          children: [
            Scaffold(
              appBar: CustomAppBar(title: 'Send file'),
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    CustomTabBar(
                      tabs: ['Transfer to IOS', 'Transfer to Android'],
                      selectedIndex: state.selectedIndex,
                      onTabSelected: _controller.onTabSelected,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: ListView(
                          key: ValueKey<int>(state.selectedIndex),
                          padding: EdgeInsets.symmetric(vertical: 24.0)
                              .copyWith(
                                bottom: MediaQuery.of(context).padding.bottom,
                              ),
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Image.asset(
                                    'assets/images/send_file.png',
                                    width: 74.0,
                                    height: 74.0,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    _controller.getTitleText(),
                                    style: AppTypography.title20Medium,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
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
                                      data: _controller.getQrData(),
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
            // При подключении клиента
            if (state.isConnecting)
              ConnectionStatusAlert(isConnecting: !state.isConnected),
          ],
        );
      },
    );
  }
}
