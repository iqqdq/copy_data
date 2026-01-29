import 'package:flutter/material.dart';

import '../../core/core.dart';

class CustomLoader extends StatefulWidget {
  final Duration animationDuration;
  final double circleSize;
  final double jumpHeight;

  const CustomLoader({
    super.key,
    this.animationDuration = const Duration(milliseconds: 500),
    this.circleSize = 10.0,
    this.jumpHeight = 10.0,
  });

  @override
  State<CustomLoader> createState() => _CustomLoaderState();
}

class _CustomLoaderState extends State<CustomLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _jumpAnimations;
  late List<Animation<int>> _colorStates;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(
        milliseconds: widget.animationDuration.inMilliseconds * 3,
      ),
      vsync: this,
    )..repeat();

    _createAnimations();
  }

  void _createAnimations() {
    _jumpAnimations = List.generate(3, (index) {
      return TweenSequence<double>([
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 0.0,
            end: -widget.jumpHeight,
          ).chain(CurveTween(curve: Curves.easeOutQuad)),
          weight: 0.33,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: -widget.jumpHeight,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeInQuad)),
          weight: 0.33,
        ),
        TweenSequenceItem<double>(
          tween: ConstantTween<double>(0.0),
          weight: 0.33,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(index / 3, (index + 1) / 3, curve: Curves.linear),
        ),
      );
    });

    _colorStates = List.generate(3, (index) {
      return IntTween(begin: 0, end: 2).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(index / 3, (index + 1) / 3, curve: _ColorStepCurve()),
        ),
      );
    });
  }

  @override
  void didUpdateWidget(CustomLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circleSize != widget.circleSize ||
        oldWidget.jumpHeight != widget.jumpHeight ||
        oldWidget.animationDuration != widget.animationDuration) {
      _controller.duration = Duration(
        milliseconds: widget.animationDuration.inMilliseconds * 3,
      );
      _controller.stop();
      _createAnimations();
      _controller.repeat();
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
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.only(right: index < 2 ? 2.0 : 0.0),
          child: _LoaderCircle(
            jumpAnimation: _jumpAnimations[index],
            colorState: _colorStates[index],
            size: widget.circleSize,
          ),
        );
      }),
    );
  }
}

class _ColorStepCurve extends Curve {
  @override
  double transform(double t) {
    if (t < 0.33) return 0.5;
    if (t < 0.66) return 0.5;
    return 1.0;
  }
}

class _LoaderCircle extends AnimatedWidget {
  final Animation<double> jumpAnimation;
  final Animation<int> colorState;
  final double size;

  _LoaderCircle({
    required this.jumpAnimation,
    required this.colorState,
    required this.size,
  }) : super(listenable: Listenable.merge([jumpAnimation, colorState]));

  Color get _currentColor =>
      colorState.value == 1 ? AppColors.accent : AppColors.lightBlue;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0.0, jumpAnimation.value),
      child: SizedBox(width: size, height: size).withDecoration(
        color: _currentColor,
        borderRadius: BorderRadius.circular(size),
        borderWidth: 2.0,
        offset: Offset(0, 0),
        borderColor: AppColors.black,
      ),
    );
  }
}
