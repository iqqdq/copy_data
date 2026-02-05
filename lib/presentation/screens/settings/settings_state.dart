import 'package:flutter/foundation.dart';

@immutable
class SettingsState {
  final List<String> titles;
  final List<String> assets;
  final bool isLoading;

  const SettingsState({
    this.titles = const [
      'Privacy Policy',
      'Terms of Use',
      'Share App',
      'Support',
    ],
    this.assets = const ['lock', 'document', 'share', 'headset'],
    required this.isLoading,
  });

  SettingsState copyWith({bool? isLoading}) {
    return SettingsState(
      titles: titles,
      assets: assets,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SettingsState && other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return Object.hash(titles, assets, isLoading);
  }
}
