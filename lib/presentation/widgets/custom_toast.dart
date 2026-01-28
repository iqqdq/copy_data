import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/core.dart';

class CustomToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void showToast({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismissCurrentToast();

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _ToastContent(
        duration: duration,
        message: message,
        onDismiss: _dismissCurrentToast,
      ),
    );

    _currentEntry = overlayEntry;
    overlay.insert(overlayEntry);

    _timer = Timer(
      duration + const Duration(milliseconds: 600),
      _dismissCurrentToast,
    );
  }

  static void _dismissCurrentToast() {
    _timer?.cancel();
    _timer = null;

    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }
  }
}

class _ToastContent extends StatefulWidget {
  const _ToastContent({
    required this.duration,
    required this.message,
    required this.onDismiss,
  });
  final Duration duration;
  final String message;
  final VoidCallback onDismiss;

  @override
  _ToastContentState createState() => _ToastContentState();
}

class _ToastContentState extends State<_ToastContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _positionAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _showToast();
  }

  Future<void> _showToast() async {
    _controller.forward().then((_) {
      Future.delayed(widget.duration, () {
        if (mounted) {
          _dismissAnimated();
        }
      });
    });
  }

  Future<void> _dismissAnimated() async {
    if (_controller.status == AnimationStatus.completed) {
      await _controller.reverse();
    }
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 4.0,
      left: 24.0,
      right: 24.0,
      child: SlideTransition(
        position: _positionAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: GestureDetector(
                  onTap: _dismissAnimated,
                  child:
                      SizedBox(
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Image.asset(
                                'assets/images/warning.png',
                                width: 24,
                                height: 24,
                              ),
                            ),

                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Text(
                                  widget.message,
                                  style: AppTypography.body16Regular,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).withDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(32.0),
                        borderWidth: 3.0,
                        borderColor: AppColors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 12.0,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
