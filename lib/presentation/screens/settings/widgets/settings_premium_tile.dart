import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_file_transfer/core/core.dart';

class SettingsPremiumTile extends StatefulWidget {
  final VoidCallback onPressed;

  const SettingsPremiumTile({super.key, required this.onPressed});

  @override
  State<SettingsPremiumTile> createState() => _SettingsPremiumTileState();
}

class _SettingsPremiumTileState extends State<SettingsPremiumTile> {
  bool _isPressed = false;
  Timer? _pressTimer;

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _pressTimer?.cancel();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    _pressTimer?.cancel();
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        transform: Matrix4.translationValues(
          _isPressed ? 0 : 0,
          _isPressed ? 3 : 0,
          0,
        ),
        child:
            SizedBox(
              child: Stack(
                children: [
                  Image.asset(
                    'assets/images/premium_bg.png',
                    fit: BoxFit.cover,
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Image.asset(
                                  'assets/images/diamond.png',
                                  width: 28.0,
                                  height: 28.0,
                                ),
                              ),

                              Expanded(
                                child: 'Upgrade to Premium'.toHighlightedText(
                                  highlightedWords: ['Premium'],
                                  style: AppTypography.title20Medium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        'Unlock full access to unlimited file transfers on all your devices'
                            .toHighlightedText(
                              highlightedWords: ['full', 'access'],
                              style: AppTypography.body16Regular,
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ).withDecoration(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              color: AppColors.white,
              borderRadius: BorderRadius.circular(32.0),
              borderWidth: 3.0,
              borderColor: AppColors.accent,
              shadowColor: _isPressed ? Colors.transparent : AppColors.accent,
              offset: _isPressed ? const Offset(0, 0) : const Offset(0, 3),
            ),
      ),
    );
  }
}
