import 'package:flutter/material.dart';

import '../../core/core.dart';

class CustomSlider extends StatefulWidget {
  final int length;
  final int currentPage;
  final Duration animationDuration;

  const CustomSlider({
    super.key,
    required this.length,
    required this.currentPage,
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

        return Container(
          margin: EdgeInsets.only(right: index < widget.length - 1 ? 2 : 0),
          child: _buildSliderItem(index, isCurrent, wasCurrent),
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
    return SizedBox(
      width: 32.0,
      height: 10.0,
      child: const SizedBox.shrink().withDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(5.0),
        borderWidth: 2.0,
        borderColor: AppColors.black,
        offset: Offset(0, 0),
      ),
    );
  }
}

class _StaticCircle extends StatelessWidget {
  const _StaticCircle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10.0,
      height: 10.0,
      child: const SizedBox.shrink().withDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(5.0),
        borderWidth: 2.0,
        borderColor: AppColors.black,
        offset: Offset(0, 0),
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
      width = 10.0 + (32 - 10.0) * progress.value;
      color = Color.lerp(AppColors.white, AppColors.accent, progress.value)!;
    } else {
      width = 32 - (32 - 10.0) * progress.value;
      color = Color.lerp(AppColors.accent, AppColors.white, progress.value)!;
    }

    return SizedBox(
      width: width,
      height: 10.0,
      child: const SizedBox.shrink().withDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5.0),
        borderWidth: 2.0,
        borderColor: AppColors.black,
        offset: Offset(0, 0),
      ),
    );
  }
}
