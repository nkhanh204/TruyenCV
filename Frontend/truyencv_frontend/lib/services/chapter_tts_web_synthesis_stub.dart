/// Stub khi build Android/iOS/desktop (không có `dart:html`).
class ChapterTtsWebSynthesis {
  Future<void> waitForVoices() async {}

  bool hasVietnameseVoiceAvailable() => false;

  Future<bool> speakChunksSequentially(
    List<String> chunks, {
    required double rate,
  }) async =>
      false;

  void stop() {}
}
