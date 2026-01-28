import 'package:flutter/material.dart';
import '../core.dart';

extension StringHighlighting on String {
  Widget toHighlightedText({
    required List<String> highlightedWords,
    required TextStyle style,
    Color highlightColor = AppColors.accent,
    TextAlign? textAlign,
  }) {
    return _buildRichText(
      text: this,
      highlightedWords: highlightedWords,
      style: style,
      highlightColor: highlightColor,
      textAlign: textAlign,
    );
  }

  Widget toMultiColoredText({
    required TextStyle style,
    required List<TextHighlight> highlights,
    TextAlign? textAlign,
  }) {
    final defaultstyle = style.copyWith(color: style.color ?? AppColors.black);
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
            TextSpan(text: text.substring(0, index), style: defaultstyle),
          );
        }

        spans.add(
          TextSpan(
            text: text.substring(index, index + highlight.text.length),
            style: defaultstyle.copyWith(color: highlight.color),
          ),
        );

        text = text.substring(index + highlight.text.length);
      }
    }

    if (text.isNotEmpty) {
      spans.add(TextSpan(text: text, style: defaultstyle));
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(style: defaultstyle, children: spans),
    );
  }

  RichText _buildRichText({
    required String text,
    required List<String> highlightedWords,
    required TextStyle style,
    required Color highlightColor,
    TextAlign? textAlign,
  }) {
    final defaultstyle = style.copyWith(color: style.color ?? AppColors.black);
    final highlightedStyle = defaultstyle.copyWith(color: highlightColor);
    final spans = <TextSpan>[];
    String remainingText = text;

    for (final word in highlightedWords) {
      final index = remainingText.toLowerCase().indexOf(word.toLowerCase());

      if (index != -1) {
        if (index > 0) {
          spans.add(
            TextSpan(
              text: remainingText.substring(0, index),
              style: defaultstyle,
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
      spans.add(TextSpan(text: remainingText, style: defaultstyle));
    }

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(style: defaultstyle, children: spans),
    );
  }
}

class TextHighlight {
  final String text;
  final Color color;

  TextHighlight({required this.text, required this.color});
}
