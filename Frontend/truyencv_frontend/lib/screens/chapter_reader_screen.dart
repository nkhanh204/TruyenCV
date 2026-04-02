import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../services/chapter_service.dart';
import '../services/chapter_tts_service.dart';
import '../services/chapter_tts_fpt_service.dart';
import '../services/tts_web.dart';
import '../services/reading_history_service.dart';
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import '../services/reading_settings_service.dart';
import '../models/reading_history.dart';
import '../models/comment.dart';
import 'chapters_list_screen.dart';

class ChapterReaderScreen extends StatefulWidget {
  final int chapterId;
  final int storyId;
  final String storyTitle;

  const ChapterReaderScreen({
    super.key,
    required this.chapterId,
    required this.storyId,
    required this.storyTitle,
  });

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen>
    with TickerProviderStateMixin {
  final ChapterService _chapterService = ChapterService();
  final ReadingHistoryService _historyService = ReadingHistoryService();
  final CommentService _commentService = CommentService();
  final ReadingSettingsService _readingSettings = ReadingSettingsService();
  final ChapterTtsService _ttsService = ChapterTtsService();
  final ChapterTtsFptService _fptTtsService = ChapterTtsFptService();
  final TextEditingController _commentController = TextEditingController();
  Chapter? _chapter;
  bool _isLoading = true;
  String? _errorMessage;
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  int _commentPage = 1;
  final int _commentPageSize = 10;
  int _totalComments = 0;
  double _fontSize = 16.0;
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScrolling = false;
  Timer? _autoScrollTimer;
  double _scrollSpeed = 10.0; // Tốc độ cuộn mặc định (pixels mỗi giây)
  bool _isScrolling = false; // Flag để đảm bảo chỉ có một animation chạy
  double _ttsRate = 1.0;

  @override
  void initState() {
    super.initState();
    _ttsService.onStateChanged = _onTtsStateChanged;
    // Set token từ AuthService singleton
    final authService = AuthService();
    if (authService.token != null) {
      _historyService.setToken(authService.token);
      _commentService.setToken(authService.token);
    }
    _initializeSettings();
    _loadChapter();
    _loadComments();
  }

  void _onTtsStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeSettings() async {
    await _readingSettings.initialize();
    setState(() {
      _fontSize = _readingSettings.fontSize;
      _ttsRate = _readingSettings.ttsRate;
    });
  }

  void _showTtsRateDialog() {
    double temp = _ttsRate;
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Tốc độ đọc (nghe truyện)'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(temp * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn giữ nút tai nghe để mở lại',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: temp,
                      min: _readingSettings.minTtsRate,
                      max: _readingSettings.maxTtsRate,
                      divisions: 10,
                      label: '${(temp * 100).round()}%',
                      onChanged: (value) {
                        setDialogState(() {
                          temp = value;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _readingSettings.setTtsRate(temp);
                      if (mounted) {
                        setState(() {
                          _ttsRate = _readingSettings.ttsRate;
                        });
                      }
                      if (_ttsService.isSpeaking) {
                        await _ttsService.setSpeechRate(_ttsRate);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Áp dụng'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _toggleChapterTts() async {
    if (_chapter == null) return;

    // Web: dùng JS speechSynthesis trực tiếp
    if (kIsWeb) {
      if (TtsWeb.isSpeaking) {
        TtsWeb.stop();
      } else {
        final plain = ChapterTtsService.stripHtmlForSpeech(_chapter!.content);
        final title = _chapter!.title ?? '';
        final text = title.isNotEmpty ? '$title. $plain' : plain;
        TtsWeb.speak(text, _ttsRate); // gọi đồng bộ ngay trong gesture
      }
      setState(() {});
      return;
    }

    // Mobile: dùng flutter_tts
    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
      return;
    }

    final plain = ChapterTtsService.stripHtmlForSpeech(_chapter!.content);
    if (plain.isEmpty) return;

    if (_isAutoScrolling) {
      _stopAutoScroll();
      setState(() { _isAutoScrolling = false; });
    }

    await _ttsService.speakChapter(
      title: _chapter!.title,
      content: _chapter!.content,
      speechRate: _ttsRate,
    );
  }

  Future<void> _updateFontSize(double newSize) async {
    await _readingSettings.setFontSize(newSize);
    setState(() {
      _fontSize = _readingSettings.fontSize;
    });
  }

  void _showScrollSpeedDialog() {
    // Lưu giá trị ban đầu để có thể hủy
    double tempSpeed = _scrollSpeed;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Điều chỉnh tốc độ cuộn'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${tempSpeed.toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: tempSpeed,
                      min: 2.0,
                      max: 60.0,
                      divisions: 58,
                      label: tempSpeed.toInt().toString(),
                      onChanged: (value) {
                        setDialogState(() {
                          tempSpeed = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children:
                          [2, 4, 6, 8, 10, 12, 15, 20, 30, 40, 50, 60]
                              .map(
                                (speed) => _buildSpeedButton(
                                  speed.toString(),
                                  speed.toDouble(),
                                  tempSpeed,
                                  (newSpeed) {
                                    setDialogState(() {
                                      tempSpeed = newSpeed;
                                    });
                                  },
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () {
                      // Lưu trạng thái đang scroll
                      final wasScrolling = _isAutoScrolling;

                      // Đóng dialog trước
                      Navigator.pop(context);

                      // Dừng auto-scroll nếu đang chạy
                      if (wasScrolling) {
                        _stopAutoScroll();
                      }

                      // Cập nhật tốc độ mới
                      setState(() {
                        _scrollSpeed = tempSpeed;
                      });

                      // Nếu đang scroll, bật lại với tốc độ mới sau một chút delay
                      if (wasScrolling) {
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (mounted) {
                            setState(() {
                              _isAutoScrolling = true;
                            });
                            _startAutoScroll();
                          }
                        });
                      } else {
                        // Hiển thị thông báo tốc độ đã được cập nhật
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Tốc độ đã được đặt: ${tempSpeed.toInt()}',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    child: const Text('Áp dụng'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildSpeedButton(
    String label,
    double speed,
    double currentSpeed,
    Function(double) onSpeedChanged,
  ) {
    final isSelected = (currentSpeed - speed).abs() < 0.1;
    return TextButton(
      onPressed: () => onSpeedChanged(speed),
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? Colors.purple.withOpacity(0.2) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.purple : null,
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Điều chỉnh kích thước chữ'),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kích thước: ${_fontSize.toInt()}',
                      style: TextStyle(fontSize: _fontSize),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _fontSize,
                      min: _readingSettings.minFontSize,
                      max: _readingSettings.maxFontSize,
                      divisions: 6,
                      label: _fontSize.toInt().toString(),
                      onChanged: (value) {
                        setDialogState(() {
                          _fontSize = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setDialogState(() {
                              _fontSize = (_fontSize - 2).clamp(
                                _readingSettings.minFontSize,
                                _readingSettings.maxFontSize,
                              );
                            });
                          },
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              _fontSize = 16.0;
                            });
                          },
                          child: const Text('Mặc định'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setDialogState(() {
                              _fontSize = (_fontSize + 2).clamp(
                                _readingSettings.minFontSize,
                                _readingSettings.maxFontSize,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () {
                  _updateFontSize(_fontSize);
                  Navigator.pop(context);
                },
                child: const Text('Áp dụng'),
              ),
            ],
          ),
    );
  }

  Future<void> _loadChapter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _chapterService.getChapterById(widget.chapterId);

    setState(() {
      _isLoading = false;
      if (response.status && response.data != null) {
        _chapter = response.data!;
        _errorMessage = null;
        // Tạo hoặc cập nhật lịch sử đọc sau khi load chapter thành công
        _updateReadingHistory();
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _updateReadingHistory() async {
    // Chỉ tạo/cập nhật lịch sử đọc nếu user đã đăng nhập
    final authService = AuthService();
    if (authService.token == null) return;

    try {
      // Thử tạo lịch sử đọc mới (nếu đã có sẽ được xử lý ở backend)
      await _historyService.createReadingHistory(
        ReadingHistoryCreateDTO(
          storyId: widget.storyId,
          lastReadChapterId: widget.chapterId,
        ),
      );
      // Nếu tạo thành công hoặc đã tồn tại, không cần làm gì thêm
      // Backend sẽ tự động tạo mới hoặc cập nhật nếu đã có
    } catch (e) {
      // Lỗi không quan trọng, bỏ qua
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _chapter?.title ?? 'Chương ${_chapter?.chapterNumber ?? ""}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _showFontSizeDialog,
            tooltip: 'Điều chỉnh kích thước chữ',
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over_outlined),
            onPressed: _showTtsRateDialog,
            tooltip: 'Tốc độ đọc khi nghe truyện',
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            onPressed: _showScrollSpeedDialog,
            tooltip: 'Điều chỉnh tốc độ cuộn',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ChaptersListScreen(
                        storyId: widget.storyId,
                        storyTitle: widget.storyTitle,
                      ),
                ),
              );
            },
            tooltip: 'Danh sách chương',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadChapter,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
              : _chapter == null
              ? const Center(child: Text('Không tìm thấy chương'))
              : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_chapter!.title != null && _chapter!.title!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _chapter!.title!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      'Chương ${_chapter!.chapterNumber}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _chapter!.content,
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: 1.8,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lượt đọc: ${_chapter!.readCont}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Cập nhật: ${_formatDate(_chapter!.updatedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Comments Section
                    _buildCommentsSection(),
                  ],
                ),
              ),
      floatingActionButton:
          _chapter != null && !_isLoading && _errorMessage == null
              ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onLongPress: _showTtsRateDialog,
                      child: FloatingActionButton(
                        heroTag: 'tts',
                        mini: true,
                        backgroundColor:
                            _ttsService.isSpeaking
                                ? Colors.deepOrange
                                : Colors.teal,
                        onPressed: () => unawaited(_toggleChapterTts()),
                        tooltip:
                            _ttsService.isSpeaking
                                ? 'Dừng đọc'
                                : 'Nghe truyện (giữ: tốc độ)',
                        child: Icon(
                          _ttsService.isSpeaking
                              ? Icons.stop
                              : Icons.headphones,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (_isAutoScrolling)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: FloatingActionButton(
                        heroTag: "speed",
                        mini: true,
                        onPressed: _showScrollSpeedDialog,
                        backgroundColor: Colors.purple.shade300,
                        child: const Icon(Icons.speed, color: Colors.white),
                        tooltip: 'Điều chỉnh tốc độ',
                      ),
                    ),
                  FloatingActionButton(
                    heroTag: "autoscroll",
                    onPressed: _toggleAutoScroll,
                    backgroundColor:
                        _isAutoScrolling ? Colors.red : Colors.purple,
                    child: Icon(
                      _isAutoScrolling ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    tooltip:
                        _isAutoScrolling ? 'Dừng tự động cuộn' : 'Tự động cuộn',
                  ),
                ],
              )
              : null,
    );
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (refresh) {
      _commentPage = 1;
      _comments = [];
    }

    setState(() {
      _isLoadingComments = true;
    });

    final response = await _commentService.getCommentsByChapter(
      widget.chapterId,
      page: _commentPage,
      pageSize: _commentPageSize,
    );

    if (mounted) {
      setState(() {
        _isLoadingComments = false;
        if (response.status && response.data != null) {
          final data = response.data!;
          final commentsList = data['comments'] as List<dynamic>? ?? [];
          _totalComments = data['total'] as int? ?? 0;

          if (refresh) {
            _comments =
                commentsList
                    .map(
                      (item) => Comment.fromJson(item as Map<String, dynamic>),
                    )
                    .toList();
          } else {
            _comments.addAll(
              commentsList
                  .map((item) => Comment.fromJson(item as Map<String, dynamic>))
                  .toList(),
            );
          }
        }
      });
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final authService = AuthService();
    if (authService.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để bình luận'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final response = await _commentService.createCommentForChapter(
      widget.chapterId,
      CommentCreateDTO(content: _commentController.text.trim()),
    );

    if (mounted) {
      if (response.status) {
        _commentController.clear();
        _loadComments(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng bình luận thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bình luận',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_totalComments > 0)
              Text(
                '(${_totalComments})',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          decoration: InputDecoration(
            hintText: 'Viết bình luận...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submitComment,
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        if (_isLoadingComments && _comments.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_comments.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Chưa có bình luận nào',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    comment.userName ?? 'Người dùng',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(comment.content),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(comment.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (_comments.length < _totalComments)
          Center(
            child: TextButton(
              onPressed: () {
                _commentPage++;
                _loadComments();
              },
              child: const Text('Xem thêm bình luận'),
            ),
          ),
      ],
    );
  }

  void _toggleAutoScroll() {
    final willStart = !_isAutoScrolling;
    if (willStart) {
      unawaited(_ttsService.stop());
    }

    setState(() {
      _isAutoScrolling = willStart;
    });

    if (willStart) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _isScrolling = false;

    // Sử dụng interval cố định 16ms (~60fps) để cuộn mượt mà
    // Tính toán pixels mỗi frame dựa trên tốc độ (pixels/giây)
    const int frameInterval = 16; // 16ms = ~60fps
    final double pixelsPerFrame = _scrollSpeed / 60.0; // Chia cho 60 vì 60fps

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: frameInterval), (
      timer,
    ) {
      if (!_isAutoScrolling || !_scrollController.hasClients) {
        _stopAutoScroll();
        return;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      if (currentScroll >= maxScroll) {
        // Đã cuộn đến cuối, dừng auto-scroll
        _stopAutoScroll();
        setState(() {
          _isAutoScrolling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đến cuối chương'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Tính toán vị trí mới - cuộn từng chút một để mượt mà
      final newPosition = (currentScroll + pixelsPerFrame).clamp(
        0.0,
        maxScroll,
      );

      // Sử dụng jumpTo với số pixels rất nhỏ mỗi frame để tạo hiệu ứng mượt mà liên tục
      // jumpTo sẽ không có animation delay, tạo ra cuộn liên tục mượt mà như video
      _scrollController.jumpTo(newPosition);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _isScrolling = false;
  }

  @override
  void dispose() {
    _ttsService.onStateChanged = null;
    unawaited(_ttsService.stop());
    _stopAutoScroll();
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
