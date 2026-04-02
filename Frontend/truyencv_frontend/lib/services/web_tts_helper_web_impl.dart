import 'dart:js_interop';
import 'package:web/web.dart';

/// Helper gọi Web Speech API trực tiếp — phải được gọi trong user-gesture context.
class WebTtsHelper {
  static final WebTtsHelper _instance = WebTtsHelper._();
  static WebTtsHelper get instance => _instance;
  WebTtsHelper._();

  final SpeechSynthesis _synth = window.speechSynthesis;
  bool _voicesLoaded = false;

  /// Gọi sớm khi màn hình load để Chrome cache danh sách voices.
  void preloadVoices() {
    if (_voicesLoaded) return;
    _synth.getVoices();
    _synth.onvoiceschanged = ((Event _) {
      _voicesLoaded = _synth.getVoices().length > 0;
    }).toJS;
    _voicesLoaded = _synth.getVoices().length > 0;
  }

  bool get isSpeaking => _synth.speaking;

  /// Gọi NGAY trong onPressed (không await trước đó) để tránh Chrome autoplay policy.
  void speak(String text, double rate) {
    _synth.cancel();
    if (text.trim().isEmpty) return;

    final voice = _pickVietnameseVoice();
    final langTag = (voice != null && voice.lang.trim().isNotEmpty)
        ? voice.lang.trim()
        : 'vi-VN';
    final r = rate.clamp(0.35, 1.65);

    // Chia đoạn ngắn để tránh Chrome cắt giữa chừng
    final chunks = _splitText(text, 200);
    for (final chunk in chunks) {
      final u = SpeechSynthesisUtterance(chunk);
      u.lang = langTag;
      if (voice != null) u.voice = voice;
      u.rate = r;
      u.volume = 1.0;
      u.pitch = 1.0;
      _synth.speak(u);
    }
  }

  void stop() => _synth.cancel();

  SpeechSynthesisVoice? _pickVietnameseVoice() {
    final arr = _synth.getVoices();
    SpeechSynthesisVoice? best;
    var bestScore = 0;
    for (var i = 0; i < arr.length; i++) {
      final v = arr[i];
      final score = _viScore(v);
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return bestScore >= 40 ? best : null;
  }

  static int _viScore(SpeechSynthesisVoice v) {
    final lang = v.lang.toLowerCase();
    final name = v.name.toLowerCase();
    var s = 0;
    if (lang.startsWith('vi')) s += 500;
    if (lang.contains('viet')) s += 200;
    if (name.contains('viet') || name.contains('việt')) s += 400;
    if (name.contains('hoai') || name.contains('hoài')) s += 350;
    if (v.voiceURI.toLowerCase().contains('vi')) s += 100;
    return s;
  }

  static List<String> _splitText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final out = <String>[];
    var s = text;
    while (s.length > maxLen) {
      var cut = s.lastIndexOf(' ', maxLen);
      if (cut <= 0) cut = maxLen;
      out.add(s.substring(0, cut).trim());
      s = s.substring(cut).trim();
    }
    if (s.isNotEmpty) out.add(s);
    return out;
  }
}
