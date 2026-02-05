import 'package:flutter/foundation.dart';

@immutable
class OnboardState {
  final List<String> images;
  final List<String> titles;
  final List<String> subtitles;
  final int index;
  final bool isLoading;

  const OnboardState({
    this.images = const [
      'fast_and_easy_file_transfer',
      'rate_your_experience',
      'connecting_devices',
    ],
    this.titles = const [
      'Fast & Easy File Transfer',
      'Rate Your Experience',
      'Fast Transfer via QR',
    ],
    this.subtitles = const [
      'Share photos and videos instantly, no cables needed',
      'Help us improve by leaving a quick review',
      'Connect devices instantly and share files in seconds',
    ],
    required this.index,
    required this.isLoading,
  });

  OnboardState copyWith({int? index, bool? isLoading}) {
    return OnboardState(
      index: index ?? this.index,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OnboardState &&
        other.index == index &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return Object.hash(index, isLoading);
  }
}
