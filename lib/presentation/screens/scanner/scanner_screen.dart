import 'package:flutter/material.dart';

import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  late ScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScannerController(
      showOkDialog: (title, message) async {
        return OkDialog.show(context, title: title, message: message);
      },
      navigateTo: (route, {arguments}) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, route, arguments: arguments);
        }
      },
      fileTransferServiceCallback: () {
        return Provider.of<FileTransferService>(context, listen: false);
      },
    );
    _controller.setupSubscriptionCallback();
  }

  @override
  void reassemble() {
    super.reassemble();
    _controller.pauseCamera();
    _controller.resumeCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _controller.onQrViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: const Color.fromRGBO(255, 220, 19, 1),
              borderRadius: 32.0,
              borderLength: 44.0,
              borderWidth: 12.0,
              cutOutSize: 250,
            ),
          ),

          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final state = _controller.state;
              if (state.isConnecting) {
                return ConnectionStatusAlert(isConnecting: !state.isConnected);
              }
              return const SizedBox.shrink();
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Transform.scale(
                    scale: 1.5,
                    child: CustomIconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: SvgPicture.asset(
                        'assets/icons/cross.svg',
                        width: 20.0,
                        height: 20.0,
                      ),
                    ),
                  ),
                  CustomIconButton(
                    onPressed: _controller.toggleFlash,
                    icon: SvgPicture.asset('assets/icons/flash.svg'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
