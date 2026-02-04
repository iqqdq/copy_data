import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _keyisOnboardSkipped = 'is_onboard_skipped';
  static const String _keyisTutorialSkipped = 'is_tutorial_skipped';
  static const String _keyIsAppLiked = 'is_app_liked';
  static const String _keyIsAppRated = 'is_app_rated';
  static const String _keyTransferFilesCount = 'transfer_files_count';
  static const String _keyTransferFilesWeekStart = 'transfer_files_week_start';
  static const int _maxTransfersPerWeek = 10;

  static final AppSettingsService _instance = AppSettingsService._internal();

  AppSettingsService._internal();

  factory AppSettingsService() => _instance;
  static AppSettingsService get instance => _instance;

  late final SharedPreferences _prefs;

  bool get isOnboardSkipped => _prefs.getBool(_keyisOnboardSkipped) ?? false;
  bool get isTutorialSkipped => _prefs.getBool(_keyisTutorialSkipped) ?? false;
  bool get isAppLiked => _prefs.getBool(_keyIsAppLiked) ?? false;
  bool get isAppRated => _prefs.getBool(_keyIsAppRated) ?? false;

  bool get isFileTransferLimitReached {
    final count = _prefs.getInt(_keyTransferFilesCount) ?? 0;
    return count >= _maxTransfersPerWeek && !_isWeekPassed();
  }

  int get remainingFileTransfers {
    if (_isWeekPassed()) return _maxTransfersPerWeek;
    final count = _prefs.getInt(_keyTransferFilesCount) ?? 0;
    final remaining = _maxTransfersPerWeek - count;
    return remaining > 0 ? remaining : 0;
  }

  Future init() async => _prefs = await SharedPreferences.getInstance();

  Future<void> skipOnboard() async =>
      await _prefs.setBool(_keyisOnboardSkipped, true);

  Future<void> skipTutorial() async =>
      await _prefs.setBool(_keyisTutorialSkipped, true);

  Future<void> likeApp() async => await _prefs.setBool(_keyIsAppLiked, true);

  Future<void> rateApp() async => await _prefs.setBool(_keyIsAppRated, true);

  Future<void> decreaseTransferFiles(int length) async {
    final now = DateTime.now();

    // Получаем дату начала текущей недели
    final weekStartMillis = _prefs.getInt(_keyTransferFilesWeekStart);

    // Проверяем, прошла ли неделя или это первая запись
    if (weekStartMillis == null || _isWeekPassed()) {
      // Неделя прошла или это первая запись - начинаем новую неделю
      await _prefs.setInt(
        _keyTransferFilesWeekStart,
        now.millisecondsSinceEpoch,
      );
      // Устанавливаем счетчик на количество текущих файлов
      await _prefs.setInt(_keyTransferFilesCount, _maxTransfersPerWeek);
    } else {
      // Неделя еще не прошла - уменьшаем кол-во допустное кол-во файлов для отправки
      final currentCount = _prefs.getInt(_keyTransferFilesCount) ?? 0;
      await _prefs.setInt(_keyTransferFilesCount, currentCount - length);
    }
  }

  bool _isWeekPassed() {
    final weekStartMillis = _prefs.getInt(_keyTransferFilesWeekStart);
    if (weekStartMillis == null) return true;

    final weekStart = DateTime.fromMillisecondsSinceEpoch(weekStartMillis);
    final now = DateTime.now();
    final difference = now.difference(weekStart);

    return difference.inDays >= 7;
  }
}
