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
      curve: Curves.easeInOut,
      transform: Matrix4.translationValues(
        _isPressed ? 2 : 0,
        _isPressed ? 4 : 0,
        0,
      ),
      child: Row(children: [widget.child]).withDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32.0),
        borderWidth: hasBorder ? 3.0 : 0,
        borderColor: hasBorder ? AppColors.black : Colors.transparent,
        offset: hasShadow ? const Offset(0, 3) : const Offset(0, 0),
        shadowColor: hasShadow ? AppColors.black : Colors.transparent,
        blurRadius: 0,
        spreadRadius: 0,
        padding: EdgeInsets.all(24.0),
      ),
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
