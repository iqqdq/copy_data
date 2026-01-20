import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_file_transfer/presentation/presentation.dart';

import '../../core/core.dart';

class CustomButton extends StatefulWidget {
  final String title;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback? onPressed;

  const CustomButton({
    super.key,
    required this.title,
    this.isPrimary = true,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
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
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      height: 48.0,
      transform: Matrix4.translationValues(
        _isPressed ? 2 : 0,
        _isPressed ? 4 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: widget.onPressed == null
            ? AppColors.extraLightGray
            : widget.isPrimary
            ? AppColors.white
            : AppColors.lightBlue,
        borderRadius: BorderRadius.circular(500),
        border: Border.all(color: AppColors.black, width: 3),
        boxShadow: _isPressed
            ? []
            : [
                BoxShadow(
                  color: AppColors.black,
                  offset: const Offset(2, 4),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Center(
        child: widget.isLoading
            ? const CustomLoader()
            : Text(
                widget.title,
                style: AppTypography.link16Medium.copyWith(
                  color: widget.onPressed == null
                      ? AppColors.lightGray
                      : AppColors.black,
                ),
              ),
      ),
    );

    return widget.onPressed == null || widget.isLoading
        ? child
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onPressed,
            child: child,
          );
  }
}
