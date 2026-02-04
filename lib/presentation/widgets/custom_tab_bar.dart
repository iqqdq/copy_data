import 'package:flutter/material.dart';

import '../../core/core.dart';

class CustomTabBar extends StatefulWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double tabHeight;
  final double indicatorHeight;
  final Duration animationDuration;

  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.tabHeight = 51.0,
    this.indicatorHeight = 3.0,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _previousIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(CustomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;

      if (_controller.status == AnimationStatus.forward) {
        _controller.stop();
      }

      _controller.value = 0;
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
    return SizedBox(
      height: widget.tabHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Расчет ширины индикатора на основе фактических размеров
          final tabWidth = constraints.maxWidth / widget.tabs.length;

          return Stack(
            children: [
              // Tab's
              Row(
                children: List.generate(widget.tabs.length, (index) {
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onTabSelected(index),
                      child: Container(
                        height: widget.tabHeight,
                        alignment: Alignment.center,
                        child: Text(
                          widget.tabs[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: index == widget.selectedIndex
                                ? AppColors.accent
                                : AppColors.lightGray,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Indicator
              Positioned(
                bottom: 0,
                left: 0,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final startPosition = _previousIndex * tabWidth;
                    final endPosition = widget.selectedIndex * tabWidth;
                    final position =
                        startPosition +
                        (endPosition - startPosition) * _controller.value;

                    return Transform.translate(
                      offset: Offset(position, 0),
                      child: Container(
                        width: tabWidth,
                        height: widget.indicatorHeight,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(3.0),
                            bottomRight: Radius.circular(3.0),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
