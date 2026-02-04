import 'package:flutter/material.dart';

import '../../../../core/core.dart';

class RoundedLinearProgressIndicator extends StatelessWidget {
  final double value;
  final double height;
  final Color backgroundColor;
  final Color valueColor;
  final BorderRadius borderRadius;

  const RoundedLinearProgressIndicator({
    super.key,
    required this.value,
    this.height = 8.0,
    this.backgroundColor = AppColors.extraLightGray,
    this.valueColor = AppColors.accent,
    this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _RoundedLinearProgressPainter(
        value: value,
        backgroundColor: backgroundColor,
        valueColor: valueColor,
        borderRadius: borderRadius,
      ),
    );
  }
}

class _RoundedLinearProgressPainter extends CustomPainter {
  final double value;
  final Color backgroundColor;
  final Color valueColor;
  final BorderRadius borderRadius;

  _RoundedLinearProgressPainter({
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Рисуем фон
    paint.color = backgroundColor;
    final backgroundRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderRadius.resolve(TextDirection.ltr).topLeft,
    );
    canvas.drawRRect(backgroundRRect, paint);

    // Рисуем прогресс
    if (value > 0) {
      paint.color = valueColor;
      final progressWidth = size.width * value.clamp(0, 1);
      final progressRect = Rect.fromLTWH(0, 0, progressWidth, size.height);

      final progressRRect = RRect.fromRectAndRadius(
        progressRect,
        borderRadius.resolve(TextDirection.ltr).topLeft,
      );
      canvas.drawRRect(progressRRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
