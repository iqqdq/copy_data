import 'package:flutter/material.dart';
import 'package:local_file_transfer/presentation/widgets/widgets.dart';

import '../../../core/core.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Receive file'),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Image.asset(
                  'assets/images/complete_transfer.png',
                  width: 74.0,
                  height: 74.0,
                ),
              ),

              Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Scan the Sender’s QR Code',
                  style: AppTypography.title20Medium,
                ),
              ),

              Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child:
                    'Point your camera at the QR code on the sender’s device to receive the files'
                        .toHighlightedText(
                          highlightedWords: ['QR', 'code'],
                          style: AppTypography.body16Regular,
                        ),
              ),

              CustomButton.primary(
                title: 'Scan QR code',
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.scanner),
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
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }
}
