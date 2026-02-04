import 'package:flutter/material.dart';

import '../../core/core.dart';

class CustomSpinnerLoader extends StatefulWidget {
  const CustomSpinnerLoader({super.key});

  @override
  State<CustomSpinnerLoader> createState() => _CustomSpinnerLoaderState();
}

class _CustomSpinnerLoaderState extends State<CustomSpinnerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(
        painter: _SpinnerPainter(animation: _animationController),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final Animation<double> animation;

  _SpinnerPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 4, backgroundPaint);

    final spinnerPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    const sweepAngle = 3.14159 * 0.3;
    const startAngle = -3.14159 / 2;

    final rotationAngle = animation.value * 2 * 3.14159;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      startAngle + rotationAngle,
      sweepAngle,
      false,
      spinnerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}
