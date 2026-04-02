// File: lib/services/import_service.dart
// Description: Service để tích hợp tải chapters từ backend API

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ImportService {
  final String baseUrl;
  final String authToken;

  ImportService({required this.baseUrl, required this.authToken});

  /// Bắt đầu quá trình import chapters từ URL
  Future<String?> startImport({
    required String storyUrl,
    required int authorId,
    required int numberOfChapters,
    int delaySeconds = 2,
    int? storyId, // Optional: để cập nhật story có sẵn
    int? primaryGenreId,
    List<int>? genreIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/stories/import'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (storyId != null) 'storyId': storyId,
          'storyUrl': storyUrl,
          'authorId': authorId,
          'numberOfChapters': numberOfChapters,
          'delaySeconds': delaySeconds,
          if (primaryGenreId != null) 'primaryGenreId': primaryGenreId,
          if (genreIds != null) 'genreIds': genreIds,
        }),
      );

      if (response.statusCode == 202) {
        final data = jsonDecode(response.body);
        return data['data']['importId'];
      } else {
        throw Exception('Failed to start import: ${response.body}');
      }
    } catch (e) {
      print('Error starting import: $e');
      return null;
    }
  }

  /// Kiểm tra trạng thái import
  Future<ImportProgress?> getImportStatus(String importId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/stories/import/status/$importId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ImportProgress.fromJson(data['data']);
      } else {
        throw Exception('Failed to get import status: ${response.body}');
      }
    } catch (e) {
      print('Error getting import status: $e');
      return null;
    }
  }

  /// Stream trạng thái import (auto-polling mỗi 2 giây)
  Stream<ImportProgress> watchImportProgress(String importId) async* {
    while (true) {
      final progress = await getImportStatus(importId);
      if (progress != null) {
        yield progress;

        // Dừng nếu hoàn thành hoặc thất bại
        if (progress.status == 'completed' || progress.status == 'failed') {
          break;
        }
      }

      // Chờ 2 giây trước khi polling lại
      await Future.delayed(Duration(seconds: 2));
    }
  }
}

/// Model đại diện cho ImportProgress
class ImportProgress {
  final String importId;
  final String status; // 'processing', 'completed', 'failed'
  final int chaptersImported;
  final int totalChapters;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  ImportProgress({
    required this.importId,
    required this.status,
    required this.chaptersImported,
    required this.totalChapters,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  /// Tính phần trăm progress
  double get progressPercentage {
    if (totalChapters == 0) return 0;
    return chaptersImported / totalChapters;
  }

  /// Helper: Kiểm tra đang xử lý
  bool get isProcessing => status == 'processing';

  /// Helper: Kiểm tra hoàn thành
  bool get isCompleted => status == 'completed';

  /// Helper: Kiểm tra thất bại
  bool get isFailed => status == 'failed';

  /// Parse từ JSON
  factory ImportProgress.fromJson(Map<String, dynamic> json) {
    return ImportProgress(
      importId: json['importId'] ?? '',
      status: json['status'] ?? 'unknown',
      chaptersImported: json['chaptersImported'] ?? 0,
      totalChapters: json['totalChapters'] ?? 0,
      errorMessage: json['errorMessage'],
      startedAt: DateTime.parse(
        json['startedAt'] ?? DateTime.now().toIso8601String(),
      ),
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'])
              : null,
    );
  }
}
