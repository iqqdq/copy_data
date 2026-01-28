import 'package:flutter/material.dart';

import '../../../../core/core.dart';

class TutorialHint extends StatelessWidget {
  final String title;
  final String highlighted;

  const TutorialHint({
    super.key,
    required this.title,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Image.asset(
              'assets/images/warning.png',
              width: 24.0,
              height: 24.0,
            ),
          ),
          Expanded(
            child:
                'If Wi‑Fi isn’t available, enable hotspot mode on one device and connect the other to it'
                    .toMultiColoredText(
                      baseStyle: AppTypography.body16Regular,
                      highlights: [
                        TextHighlight(
                          text: 'Wi‑Fi isn’t available',
                          color: AppColors.orange,
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
