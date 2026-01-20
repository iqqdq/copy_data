import 'package:flutter/material.dart';

import '../../core/core.dart';

class CustomSlider extends StatefulWidget {
  final int length;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final Duration animationDuration;

  const CustomSlider({
    super.key,
    required this.length,
    required this.currentPage,
    required this.onPageChanged,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : assert(currentPage >= 0 && currentPage < length);

  @override
  State<CustomSlider> createState() => _CustomSliderState();
}

class _CustomSliderState extends State<CustomSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _previousPage;

  @override
  void initState() {
    super.initState();
    _previousPage = widget.currentPage;
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CustomSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage) {
      _controller.reset();
      _previousPage = oldWidget.currentPage;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.length, (index) {
        final isCurrent = index == widget.currentPage;
        final wasCurrent = index == _previousPage;

        return GestureDetector(
          onTap: () => widget.onPageChanged(index),
          child: Container(
            margin: EdgeInsets.only(right: index < widget.length - 1 ? 2 : 0),
            child: _buildSliderItem(index, isCurrent, wasCurrent),
          ),
        );
      }),
    );
  }

  Widget _buildSliderItem(int index, bool isCurrent, bool isPrevious) {
    if (isCurrent && !isPrevious) {
      return _CircleToRectangleTransition(
        controller: _controller,
        isCurrent: true,
      );
    } else if (!isCurrent && isPrevious) {
      return _CircleToRectangleTransition(
        controller: _controller,
        isCurrent: false,
      );
    } else {
      return isCurrent ? const _StaticRectangle() : const _StaticCircle();
    }
  }
}

class _StaticRectangle extends StatelessWidget {
  const _StaticRectangle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.black, width: 2),
      ),
    );
  }
}

class _StaticCircle extends StatelessWidget {
  const _StaticCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.black, width: 2),
      ),
    );
  }
}

class _CircleToRectangleTransition extends AnimatedWidget {
  final bool isCurrent;

  const _CircleToRectangleTransition({
    required AnimationController controller,
    required this.isCurrent,
  }) : super(listenable: controller);

  Animation<double> get progress => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final double width;
    final Color color;

    if (isCurrent) {
      width = 8 + (32 - 8) * progress.value;
      color = Color.lerp(AppColors.white, AppColors.accent, progress.value)!;
    } else {
      width = 32 - (32 - 8) * progress.value;
      color = Color.lerp(AppColors.accent, AppColors.white, progress.value)!;
    }

    return Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.black, width: 2),
      ),
    );
  }
}
