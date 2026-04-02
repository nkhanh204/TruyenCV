import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'chapter_tts_result.dart';
import 'chapter_tts_web_synthesis_stub.dart'
    if (dart.library.html) 'chapter_tts_web_synthesis_impl.dart';

/// Đọc nội dung chương bằng TTS: strip HTML, chia đoạn, xếp hàng nối tiếp.
/// Trên **web** dùng Web Speech API trực tiếp (ép `lang` + giọng Việt).
class ChapterTtsService {
  ChapterTtsService();

  final ChapterTtsWebSynthesis _webSynth = ChapterTtsWebSynthesis();
  FlutterTts? _tts;
  bool _initialized = false;
  List<String> _chunks = [];
  bool _speaking = false;

  VoidCallback? onStateChanged;

  bool get isSpeaking => _speaking;

  static final RegExp _viNameHint = RegExp(
    r'vietnamese|vietnam|viet nam|việt|tiếng việt|tieng viet',
    caseSensitive: false,
  );

  static String stripHtmlForSpeech(String raw) {
    var s = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    s = s.replaceAll('&nbsp;', ' ');
    s = s.replaceAll('&amp;', '&');
    s = s.replaceAll('&lt;', '<');
    s = s.replaceAll('&gt;', '>');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static List<String> chunkText(String text, {int maxLen = 3200}) {
    final clean = stripHtmlForSpeech(text);
    if (clean.isEmpty) return [];
    if (clean.length <= maxLen) return [clean];

    final out = <String>[];
    var remaining = clean;
    while (remaining.isNotEmpty) {
      if (remaining.length <= maxLen) {
        out.add(remaining);
        break;
      }
      var cut = remaining.lastIndexOf('\n', maxLen);
      if (cut < maxLen ~/ 2) {
        cut = remaining.lastIndexOf(RegExp(r'[.!?。！？]\s'), maxLen);
      }
      if (cut < maxLen ~/ 2) {
        cut = remaining.lastIndexOf(' ', maxLen);
      }
      if (cut <= 0) cut = maxLen;
      final part = remaining.substring(0, cut).trim();
      if (part.isNotEmpty) out.add(part);
      remaining = remaining.substring(cut).trim();
    }
    return out;
  }

  static bool _isVietnameseVoiceLocaleOrName(String locale, String name) {
    final l = locale.toLowerCase();
    final n = name.toLowerCase();
    if (l.startsWith('vi')) return true;
    if (_viNameHint.hasMatch(n)) return true;
    if (n.contains('hoài') || n.contains('hoai') || n.contains('nam minh')) {
      return true;
    }
    return false;
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;

    if (kIsWeb) {
      await _webSynth.waitForVoices();
      _initialized = true;
      return;
    }

    _tts = FlutterTts();
    await _tts!.awaitSpeakCompletion(true);
    _tts!.setErrorHandler((dynamic _) {
      _speaking = false;
      _chunks = [];
      onStateChanged?.call();
    });

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _tts!.setEngine('com.google.android.tts');
      } catch (_) {}
    }

    await _configureNativeVietnameseVoice();
    await _applyRate(1.0);

    _initialized = true;
  }

  Future<bool> _nativeMissingVietnameseVoice() async {
    final tts = _tts;
    if (tts == null) return true;

    try {
      final voices = await tts.getVoices;
      if (voices is List) {
        for (final raw in voices) {
          if (raw is! Map) continue;
          final name = '${raw['name'] ?? ''}';
          final locale = '${raw['locale'] ?? raw['lang'] ?? ''}';
          if (_isVietnameseVoiceLocaleOrName(locale, name)) {
            return false;
          }
        }
      }
    } catch (_) {}

    for (final code in ['vi-VN', 'vi_VN', 'vi', 'vie-VN', 'vie']) {
      try {
        if (await tts.isLanguageAvailable(code) == true) {
          return false;
        }
      } catch (_) {}
    }
    return true;
  }

  Future<void> _configureNativeVietnameseVoice() async {
    final tts = _tts;
    if (tts == null) return;

    try {
      final voices = await tts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        Map<String, String>? picked;
        var bestRank = -1;
        for (final raw in voices) {
          if (raw is! Map) continue;
          final name = '${raw['name'] ?? ''}';
          final locale = '${raw['locale'] ?? raw['lang'] ?? ''}';
          if (!_isVietnameseVoiceLocaleOrName(locale, name)) continue;
          final loc = locale.toLowerCase();
          var rank = 1;
          if (loc.contains('vn')) rank += 2;
          if (loc == 'vi' || loc.startsWith('vi-')) rank += 1;
          if (name.toLowerCase().contains('google')) rank += 1;
          if (rank > bestRank) {
            bestRank = rank;
            picked = {'name': name, 'locale': locale};
          }
        }
        if (picked != null &&
            picked['name']!.isNotEmpty &&
            picked['locale']!.isNotEmpty) {
          await tts.setVoice(picked);
        }
      }
    } catch (_) {}

    const candidates = [
      'vi-VN',
      'vi_VN',
      'vi-Vietnam',
      'vi',
      'vie-VN',
      'vie',
    ];
    for (final code in candidates) {
      try {
        final ok = await tts.isLanguageAvailable(code);
        if (ok == true) {
          await tts.setLanguage(code);
          return;
        }
      } catch (_) {}
    }
    await tts.setLanguage('vi-VN');
  }

  Future<void> _applyRate(double rate) async {
    if (kIsWeb) return;
    final tts = _tts;
    if (tts == null) return;

    final r = rate.clamp(0.35, 1.65);
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        await tts.setSpeechRate((r / 2).clamp(0.1, 1.0));
      default:
        await tts.setSpeechRate(r);
    }
  }

  Future<void> setSpeechRate(double rate) async {
    await _ensureInit();
    if (kIsWeb) return;
    await _applyRate(rate);
  }

  Future<ChapterTtsResult> speakChapter({
    required String? title,
    required String content,
    required double speechRate,
  }) async {
    await _ensureInit();
    await stop();

    final buffer = StringBuffer();
    if (title != null && title.trim().isNotEmpty) {
      buffer.write(title.trim());
      buffer.write('. ');
    }
    buffer.write(content);

    _chunks = chunkText(buffer.toString());
    if (_chunks.isEmpty) {
      return const ChapterTtsResult(missingVietnameseVoice: false);
    }

    _speaking = true;
    onStateChanged?.call();

    var missingVi = false;

    try {
      if (kIsWeb) {
        await _webSynth.waitForVoices();
        missingVi = !_webSynth.hasVietnameseVoiceAvailable();
        final usedVi = await _webSynth.speakChunksSequentially(
          _chunks,
          rate: speechRate,
        );
        missingVi = missingVi || !usedVi;
      } else {
        missingVi = await _nativeMissingVietnameseVoice();
        await _configureNativeVietnameseVoice();
        await _applyRate(speechRate);
        final tts = _tts!;
        for (var i = 0; i < _chunks.length; i++) {
          if (!_speaking) break;
          await tts.setLanguage('vi-VN');
          await tts.speak(_chunks[i]);
        }
      }
    } finally {
      _speaking = false;
      _chunks = [];
      onStateChanged?.call();
    }

    return ChapterTtsResult(missingVietnameseVoice: missingVi);
  }

  Future<void> stop() async {
    if (kIsWeb) {
      _webSynth.stop();
    } else {
      await _tts?.stop();
    }
    _speaking = false;
    _chunks = [];
    onStateChanged?.call();
  }
}
