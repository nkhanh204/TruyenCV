import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ChapterTtsFptService {
  static const String apiKey =
      'BleAF6CrxHVv5fVXX8jV282PidyM6Z3L'; // Thay bằng API Key của bạn
  static const String apiUrl = 'https://api.fpt.ai/hmi/tts/v5';
  static const String voice = 'banmai'; // Hoặc lannhi, leminh, myan...

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      print('Nội dung đọc bị rỗng!');
      return;
    }
    // FPT.AI TTS giới hạn ~1000 ký tự, nên chia nhỏ đoạn dài
    final List<String> chunks = _splitText(text, 900);
    for (final chunk in chunks) {
      await _speakChunk(chunk);
    }
  }

  static List<String> _splitText(String text, int maxLen) {
    final List<String> result = [];
    int start = 0;
    while (start < text.length) {
      int end = start + maxLen;
      if (end > text.length) end = text.length;
      // Cắt ở dấu chấm hoặc xuống dòng nếu có
      int split = end;
      if (end < text.length) {
        final lastDot = text.lastIndexOf('.', end);
        final lastNewline = text.lastIndexOf('\n', end);
        split = [
          lastDot,
          lastNewline,
          start,
        ].where((i) => i >= start).fold(start, (a, b) => b > a ? b : a);
        if (split == start)
          split = end;
        else
          split += 1;
      }
      result.add(text.substring(start, split).trim());
      start = split;
    }
    return result.where((s) => s.isNotEmpty).toList();
  }

  static Future<void> _speakChunk(String text) async {
    print('[FPT TTS] Đọc đoạn: $text');
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'api-key': apiKey, 'speed': '', 'voice': voice},
      body: text,
    );
    if (response.statusCode != 200) {
      print('FPT.AI TTS lỗi: ${response.statusCode} - ${response.body}');
      return;
    }
    final data = jsonDecode(response.body);
    final asyncUrl = data['async'];
    if (asyncUrl == null) {
      print('Không nhận được link audio từ FPT.AI!');
      return;
    }
    // Poll asyncUrl cho đến khi có file audio thực sự (trường url)
    String? audioUrl;
    for (int i = 0; i < 20; i++) {
      // Tối đa 20 lần, mỗi lần cách nhau 1s
      final pollRes = await http.get(Uri.parse(asyncUrl));
      if (pollRes.statusCode == 200) {
        final pollData = jsonDecode(pollRes.body);
        if (pollData['url'] != null && pollData['url'].toString().isNotEmpty) {
          audioUrl = pollData['url'];
          break;
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    if (audioUrl == null) {
      print('Không lấy được file audio từ FPT.AI sau khi chờ!');
      return;
    }
    if (kIsWeb) {
      // Tải file audio về dạng blob, play bằng AudioElement để tránh CORS
      try {
        final audioRes = await http.get(Uri.parse(audioUrl));
        if (audioRes.statusCode == 200) {
          final bytes = audioRes.bodyBytes;
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final audio = html.AudioElement(url)..autoplay = true;
          audio.onEnded.first.then((_) {
            html.Url.revokeObjectUrl(url);
          });
          audio.play();
        } else {
          print('Không tải được file audio về: ${audioRes.statusCode}');
        }
      } catch (e) {
        print('Lỗi khi tải hoặc play audio trên web: $e');
      }
    } else {
      final player = AudioPlayer();
      await player.play(UrlSource(audioUrl));
      await player.onPlayerComplete.first;
    }
  }
}
