import 'dart:js_interop';

@JS('flutterTtsSpeak')
external void _jsSpeak(String text, double rate);

@JS('flutterTtsStop')
external void _jsStop();

@JS('flutterTtsIsSpeaking')
external bool _jsIsSpeaking();

class TtsWeb {
  static void speak(String text, double rate) => _jsSpeak(text, rate);
  static void stop() => _jsStop();
  static bool get isSpeaking => _jsIsSpeaking();
}
