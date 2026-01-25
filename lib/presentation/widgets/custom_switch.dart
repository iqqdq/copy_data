import 'package:flutter/material.dart';

import '../../core/core.dart';

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
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child:
            Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedContainer(
                  duration: widget.animationDuration,
                  child: const SizedBox.shrink().withDecoration(
                    color: widget.value
                        ? AppColors.accent
                        : AppColors.extraLightGray,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),

                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final double leftPosition =
                        (maxLeft - minLeft) * _animation.value;

                    return Positioned(
                      left: leftPosition,
                      top: padding,
                      bottom: padding,
                      child: SizedBox(
                        width: circleDiameter,
                        height: circleDiameter,
                        child: const SizedBox.shrink().withDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          borderWidth: widget.borderWidth,
                          borderColor: AppColors.black,
                          blurRadius: 1.0,
                          spreadRadius: 0,
                          offset: const Offset(0, 1),
                          shadowColor: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ).withDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              borderWidth: widget.borderWidth,
              borderColor: AppColors.black,
              color: Colors.transparent,
            ),
      ),
    );
  }
}
