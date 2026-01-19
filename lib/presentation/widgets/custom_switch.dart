import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';

class CustomSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;
  final Duration animationDuration;
  final double borderWidth;

  const CustomSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.width = 51.0,
    this.height = 31.0,
    this.animationDuration = const Duration(milliseconds: 200),
    this.borderWidth = 2.0,
  });

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: widget.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(CustomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double circleDiameter = 27.0;
    const double padding = 2.0;
    final double totalPadding = padding * 2;
    final double availableWidth = widget.width - circleDiameter - totalPadding;
    final double minLeft = -2.0;
    final double maxLeft = minLeft + availableWidth;

    return GestureDetector(
      onTap: () {
        if (widget.onChanged != null) {
          widget.onChanged!(!widget.value);
        }
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.height / 2),
          border: Border.all(color: AppColors.black, width: widget.borderWidth),
          color: Colors.transparent,
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Backgorund
            AnimatedContainer(
              duration: widget.animationDuration,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2),
                color: widget.value
                    ? AppColors.accent
                    : AppColors.extraLightGray,
              ),
            ),

            // Circle
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final double leftPosition =
                    (maxLeft - minLeft) * _animation.value;

                return Positioned(
                  left: leftPosition,
                  top: padding,
                  bottom: padding,
                  child: Container(
                    width: circleDiameter,
                    height: circleDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      border: Border.all(
                        color: AppColors.black,
                        width: widget.borderWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 1.0,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
