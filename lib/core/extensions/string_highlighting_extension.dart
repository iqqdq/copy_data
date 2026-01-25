import 'package:flutter/material.dart';
import '../core.dart';

extension StringHighlighting on String {
  Widget toHighlightedText({
    required List<String> highlightedWords,
    required TextStyle baseStyle,
    Color highlightColor = AppColors.accent,
    TextAlign? textAlign,
  }) {
    return _buildRichText(
      text: this,
      highlightedWords: highlightedWords,
      baseStyle: baseStyle,
      highlightColor: highlightColor,
      textAlign: textAlign,
    );
  }

  Widget toMultiColoredText({
    required TextStyle baseStyle,
    required List<TextHighlight> highlights,
    TextAlign? textAlign,
  }) {
    final defaultBaseStyle = baseStyle.copyWith(
      color: baseStyle.color ?? AppColors.black,
    );
    final spans = <TextSpan>[];
    String text = this;

    final sortedHighlights =
        highlights
            .where((h) => text.toLowerCase().contains(h.text.toLowerCase()))
            .toList()
          ..sort((a, b) {
            final indexA = text.toLowerCase().indexOf(a.text.toLowerCase());
            final indexB = text.toLowerCase().indexOf(b.text.toLowerCase());
            return indexA.compareTo(indexB);
          });

    for (final highlight in sortedHighlights) {
      final index = text.toLowerCase().indexOf(highlight.text.toLowerCase());

      if (index != -1) {
        if (index > 0) {
          spans.add(
            TextSpan(text: text.substring(0, index), style: defaultBaseStyle),
          );
        }

        spans.add(
          TextSpan(
            text: text.substring(index, index + highlight.text.length),
            style: defaultBaseStyle.copyWith(color: highlight.color),
          ),
        );

        text = text.substring(index + highlight.text.length);
      }
    }

    if (text.isNotEmpty) {
      spans.add(TextSpan(text: text, style: defaultBaseStyle));
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(style: defaultBaseStyle, children: spans),
    );
  }

  RichText _buildRichText({
    required String text,
    required List<String> highlightedWords,
    required TextStyle baseStyle,
    required Color highlightColor,
    TextAlign? textAlign,
  }) {
    final defaultBaseStyle = baseStyle.copyWith(
      color: baseStyle.color ?? AppColors.black,
    );
    final highlightedStyle = defaultBaseStyle.copyWith(color: highlightColor);
    final spans = <TextSpan>[];
    String remainingText = text;

    for (final word in highlightedWords) {
      final index = remainingText.toLowerCase().indexOf(word.toLowerCase());

      if (index != -1) {
        if (index > 0) {
          spans.add(
            TextSpan(
              text: remainingText.substring(0, index),
              style: defaultBaseStyle,
            ),
          );
        }

        spans.add(
          TextSpan(
            text: remainingText.substring(index, index + word.length),
            style: highlightedStyle,
          ),
        );

        remainingText = remainingText.substring(index + word.length);
      }
    }

    if (remainingText.isNotEmpty) {
      spans.add(TextSpan(text: remainingText, style: defaultBaseStyle));
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(style: defaultBaseStyle, children: spans),
    );
  }
}

class TextHighlight {
  final String text;
  final Color color;

  TextHighlight({required this.text, required this.color});
}
