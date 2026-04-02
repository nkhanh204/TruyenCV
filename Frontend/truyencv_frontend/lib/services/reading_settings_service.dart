import 'package:shared_preferences/shared_preferences.dart';

class ReadingSettingsService {
  static final ReadingSettingsService _instance =
      ReadingSettingsService._internal();
  factory ReadingSettingsService() => _instance;
  ReadingSettingsService._internal();

  static const String _fontSizeKey = 'reading_font_size';
  static const String _ttsRateKey = 'reading_tts_rate';
  static const double _defaultFontSize = 16.0;
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 24.0;
  static const double _defaultTtsRate = 1.0;
  static const double _minTtsRate = 0.5;
  static const double _maxTtsRate = 1.5;

  double _fontSize = _defaultFontSize;
  double _ttsRate = _defaultTtsRate;
  bool _isInitialized = false;

  double get fontSize => _fontSize;
  double get minFontSize => _minFontSize;
  double get maxFontSize => _maxFontSize;
  double get ttsRate => _ttsRate;
  double get minTtsRate => _minTtsRate;
  double get maxTtsRate => _maxTtsRate;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
    _ttsRate = prefs.getDouble(_ttsRateKey) ?? _defaultTtsRate;
    _ttsRate = _ttsRate.clamp(_minTtsRate, _maxTtsRate);
    _isInitialized = true;
  }

  Future<void> setFontSize(double size) async {
    if (size < _minFontSize || size > _maxFontSize) return;

    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
  }

  Future<void> setTtsRate(double rate) async {
    final r = rate.clamp(_minTtsRate, _maxTtsRate);
    _ttsRate = r;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ttsRateKey, r);
  }

  Future<void> increaseFontSize() async {
    final newSize = (_fontSize + 2).clamp(_minFontSize, _maxFontSize);
    await setFontSize(newSize);
  }

  Future<void> decreaseFontSize() async {
    final newSize = (_fontSize - 2).clamp(_minFontSize, _maxFontSize);
    await setFontSize(newSize);
  }

  Future<void> resetFontSize() async {
    await setFontSize(_defaultFontSize);
  }
}

