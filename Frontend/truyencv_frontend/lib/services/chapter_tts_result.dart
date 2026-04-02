/// Kết quả sau khi đọc chương bằng TTS.
class ChapterTtsResult {
  /// `true` khi **không** phát hiện giọng/locale tiếng Việt — thường sẽ đọc sai (vd. tiếng Anh).
  final bool missingVietnameseVoice;

  const ChapterTtsResult({required this.missingVietnameseVoice});
}
