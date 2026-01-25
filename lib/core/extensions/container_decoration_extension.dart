import 'package:flutter/material.dart';
import '../core.dart';

extension ContainerDecorationExtension on Widget {
  Widget withDecoration({
    Color? color,
    BorderRadiusGeometry? borderRadius,
    double borderWidth = 1.0,
    Color borderColor = AppColors.black,
    BoxBorder? border,
    Offset offset = const Offset(0, 0),
    Color shadowColor = AppColors.black,
    double blurRadius = 0,
    double spreadRadius = 0,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BoxShape shape = BoxShape.rectangle,
    BlendMode? backgroundBlendMode,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: shape == BoxShape.circle ? null : borderRadius,
        border: border ?? Border.all(color: borderColor, width: borderWidth),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: shadowColor,
                offset: offset,
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
            ],
        gradient: gradient,
        shape: shape,
        backgroundBlendMode: backgroundBlendMode,
      ),
      child: this,
    );
  }
}
