import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

/// Đọc trên web bằng Web Speech API — chọn giọng Việt theo điểm số (Chrome hay trả
/// `lang` rỗng hoặc tên có dấu tiếng Việt).
class ChapterTtsWebSynthesis {
  final SpeechSynthesis _synth = window.speechSynthesis;

  Completer<void>? _partDone;
  bool _halt = false;

  int _voiceCount() => _synth.getVoices().length;

  /// Điểm > 0 nếu có dấu hiệu giọng Việt (tránh nhầm chuỗi kiểu "Victoria").
  static int _vietnameseVoiceScore(SpeechSynthesisVoice v) {
    final lang = v.lang.trim().toLowerCase();
    final name = v.name.toLowerCase();
    final uri = v.voiceURI.toLowerCase();

    var score = 0;
    if (lang.startsWith('vi')) score += 500;
    if (lang.contains('viet')) score += 200;
    if (RegExp(
      r'vietnamese|vietnam|viet nam|việt|tiếng việt|tieng viet|\bvi\b',
    ).hasMatch(name)) {
      score += 400;
    }
    if (name.contains('hoài') ||
        name.contains('hoai') ||
        name.contains('nam minh')) {
      score += 350;
    }
    if (uri.contains('vi_vn') ||
        uri.contains('vi-vn') ||
        uri.contains('_vi_') ||
        uri.contains('vietnamese')) {
      score += 200;
    }
    if (lang.isEmpty &&
        (name.contains('google') || name.contains('microsoft')) &&
        (name.contains('vn') || name.contains('viet'))) {
      score += 300;
    }
    return score;
  }

  static SpeechSynthesisVoice? _pickBestVietnameseVoice(SpeechSynthesis synth) {
    final arr = synth.getVoices();
    final n = arr.length;
    SpeechSynthesisVoice? best;
    var bestScore = 0;
    for (var i = 0; i < n; i++) {
      final v = arr[i];
      final s = _vietnameseVoiceScore(v);
      if (s > bestScore) {
        bestScore = s;
        best = v;
      }
    }
    if (bestScore < 40) return null;
    return best;
  }

  bool hasVietnameseVoiceAvailable() {
    return _pickBestVietnameseVoice(_synth) != null;
  }

  Future<void> waitForVoices() async {
    _synth.getVoices();
    if (_voiceCount() > 0) return;

    final ready = Completer<void>();
    void tryComplete() {
      if (_voiceCount() > 0 && !ready.isCompleted) {
        ready.complete();
      }
    }

    _synth.addEventListener(
      'voiceschanged',
      ((Event _) => tryComplete()).toJS,
    );
    _synth.onvoiceschanged = ((Event _) => tryComplete()).toJS;

    for (var i = 0; i < 100; i++) {
      _synth.getVoices();
      if (_voiceCount() > 0) {
        if (!ready.isCompleted) ready.complete();
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    await ready.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  /// Trả về `true` nếu đã chọn được giọng Việt (điểm đủ cao).
  Future<bool> speakChunksSequentially(
    List<String> chunks, {
    required double rate,
  }) async {
    _halt = false;
    await waitForVoices();

    _synth.getVoices();
    final voice = _pickBestVietnameseVoice(_synth);
    final usedVietnamese = voice != null;

    var langTag = 'vi-VN';
    if (voice != null && voice.lang.trim().isNotEmpty) {
      langTag = voice.lang.trim();
    }

    final r = rate.clamp(0.35, 1.65);

    for (final text in chunks) {
      if (_halt) break;
      final t = text.trim();
      if (t.isEmpty) continue;

      final u = SpeechSynthesisUtterance(t);
      u.lang = langTag;
      if (voice != null) {
        u.voice = voice;
      }
      u.rate = r;
      u.volume = 1.0;
      u.pitch = 1.0;

      _partDone = Completer<void>();
      u.onend = ((Event _) {
        if (!(_partDone?.isCompleted ?? true)) {
          _partDone!.complete();
        }
      }).toJS;
      u.onerror = ((Event _) {
        if (!(_partDone?.isCompleted ?? true)) {
          _partDone!.complete();
        }
      }).toJS;

      _synth.speak(u);
      await _partDone!.future;
      _partDone = null;
    }

    return usedVietnamese;
  }

  void stop() {
    _halt = true;
    _synth.cancel();
    if (!(_partDone?.isCompleted ?? true)) {
      _partDone!.complete();
    }
    _partDone = null;
  }
}
