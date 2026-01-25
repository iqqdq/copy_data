import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';

import 'custom_loader.dart';

class CustomButton extends StatefulWidget {
  final String title;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final Color borderColor;
  final Color shadowColor;

  const CustomButton._internal({
    super.key,
    required this.title,
    required this.color,
    required this.textColor,
    required this.borderColor,
    required this.shadowColor,
    this.isLoading = false,
    this.onPressed,
  });

  factory CustomButton.primary({
    Key? key,
    required String title,
    bool isLoading = false,
    VoidCallback? onPressed,
  }) {
    return CustomButton._internal(
      key: key,
      title: title,
      color: AppColors.white,
      textColor: AppColors.black,
      borderColor: AppColors.black,
      shadowColor: AppColors.black,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }

  factory CustomButton.secondary({
    Key? key,
    required String title,
    bool isLoading = false,
    VoidCallback? onPressed,
  }) {
    return CustomButton._internal(
      key: key,
      title: title,
      color: AppColors.lightBlue,
      textColor: AppColors.black,
      borderColor: AppColors.black,
      shadowColor: AppColors.black,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }

  factory CustomButton.transparent({
    Key? key,
    required String title,
    required VoidCallback onPressed,
  }) {
    return CustomButton._internal(
      key: key,
      title: title,
      color: Colors.transparent,
      textColor: AppColors.black,
      borderColor: Colors.transparent,
      shadowColor: Colors.transparent,
      isLoading: false,
      onPressed: onPressed,
    );
  }

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
    final isDisabled = widget.onPressed == null;
    final effectiveTextColor = isDisabled
        ? AppColors.lightGray
        : widget.textColor;
    final effectiveColor = isDisabled ? AppColors.extraLightGray : widget.color;

    final hasBorder = widget.borderColor != Colors.transparent;
    final hasShadow = widget.shadowColor != Colors.transparent && !_isPressed;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      height: 48.0,
      transform: Matrix4.translationValues(
        _isPressed ? 2 : 0,
        _isPressed ? 4 : 0,
        0,
      ),
      child:
          Center(
            child: widget.isLoading
                ? const CustomLoader()
                : Text(
                    widget.title,
                    style: AppTypography.link16Medium.copyWith(
                      color: effectiveTextColor,
                    ),
                  ),
          ).withDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(500),
            borderWidth: hasBorder ? 3.0 : 0,
            borderColor: hasBorder ? widget.borderColor : Colors.transparent,
            offset: hasShadow ? const Offset(2, 4) : const Offset(0, 0),
            shadowColor: hasShadow ? widget.shadowColor : Colors.transparent,
            blurRadius: 0,
            spreadRadius: 0,
          ),
    );

    return isDisabled || widget.isLoading
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
