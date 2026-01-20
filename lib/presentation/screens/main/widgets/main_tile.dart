import 'package:flutter/material.dart';

import '../../../../core/core.dart';
import '../../../widgets/widgets.dart';

class MainTile extends StatelessWidget {
  final VoidCallback onPressed;
  final bool _isSend;

  const MainTile.send({super.key, required this.onPressed}) : _isSend = true;

  const MainTile.receive({super.key, required this.onPressed})
    : _isSend = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32.0),
        border: Border.all(color: AppColors.black, width: 3.0),
        color: AppColors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Image.asset(
              'assets/images/${_isSend ? 'send_file' : 'receive_file'}.png',
              width: 74.0,
              height: 74.0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '${_isSend ? 'Send' : 'Receive'} file',
              style: AppTypography.title20Medium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _isSend
                  ? 'Choose files and share them instantly with nearby devices'
                  : 'Receive files fast and safely from other devices',
              style: AppTypography.body16Light.copyWith(color: AppColors.grey),
            ),
          ),
          CustomButton.primary(
            title: _isSend ? 'Send' : 'Receive',
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
