/// Stub cho non-web platforms — không làm gì cả.
class WebTtsHelper {
  static final WebTtsHelper _instance = WebTtsHelper._();
  static WebTtsHelper get instance => _instance;
  WebTtsHelper._();

  void preloadVoices() {}
  bool get isSpeaking => false;
  void speak(String text, double rate) {}
  void stop() {}
}
