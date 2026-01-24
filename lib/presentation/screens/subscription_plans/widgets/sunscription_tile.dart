import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/core.dart';

class SubscriptionTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const SubscriptionTile({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<SubscriptionTile> createState() => _SubscriptionTileState();
}

class _SubscriptionTileState extends State<SubscriptionTile> {
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
    _pressTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _isPressed = false);
      }
    });
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasBorder = AppColors.black != Colors.transparent;
    final hasShadow = AppColors.black != Colors.transparent && !_isPressed;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.all(24.0),
      curve: Curves.easeInOut,
      transform: Matrix4.translationValues(
        _isPressed ? 2 : 0,
        _isPressed ? 4 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32.0),
        border: hasBorder
            ? Border.all(color: AppColors.black, width: 3.0)
            : null,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: AppColors.black,
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Row(children: [widget.child]),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: child,
    );
  }
}
