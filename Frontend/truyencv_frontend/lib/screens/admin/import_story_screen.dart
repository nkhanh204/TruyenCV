// File: lib/screens/admin/import_story_screen.dart
// Description: Screen để import/update chapters từ truyenchu.app

import 'package:flutter/material.dart';
import '../../services/import_service.dart';
import '../../services/auth_service.dart';
import '../../services/author_service.dart';
import '../../services/story_service.dart';
import '../../services/chapter_service.dart';
import '../../models/author.dart';
import '../../models/story.dart';

class ImportStoryScreen extends StatefulWidget {
  final ImportService importService;

  const ImportStoryScreen({super.key, required this.importService});

  @override
  State<ImportStoryScreen> createState() => _ImportStoryScreenState();
}

class _ImportStoryScreenState extends State<ImportStoryScreen> {
  static const Set<String> _supportedImportHosts = {
    'truyenchu.app',
    'www.truyenchu.app',
    'truyenchu.com',
    'www.truyenchu.com',
    'truyenchu.vn',
    'www.truyenchu.vn',
  };

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;
  late TextEditingController _chapterCountController;
  late TextEditingController _delayController;

  // Mode: 'import' hoặc 'update'
  String _mode = 'import';

  // Author selection
  List<AuthorListItem> _authorsList = [];
  int? _selectedAuthorId;
  bool _isLoadingAuthors = true;

  // Story selection (cho mode update)
  List<StoryListItem> _storiesList = [];
  int? _selectedStoryId;
  bool _isLoadingStories = true;

  String? _currentImportId;
  ImportProgress? _progress;
  bool _isImporting = false;

  late AuthService _authService;
  late AuthorService _authorService;
  late StoryService _storyService;
  late ChapterService _chapterService;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _urlController = TextEditingController();
    _chapterCountController = TextEditingController(text: '10');
    _delayController = TextEditingController(text: '2');

    _authService = AuthService();
    _authorService = AuthorService();
    _storyService = StoryService();
    _chapterService = ChapterService();

    // Set tokens
    if (_authService.token != null) {
      _authorService.setToken(_authService.token);
      _storyService.setToken(_authService.token);
      _chapterService.setToken(_authService.token);
    }

    _loadAuthors();
    _loadStories();
  }

  void _checkAuthorization() {
    final authService = AuthService();
    if (!authService.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bạn không có quyền truy cập tính năng này'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  bool _isSupportedImportUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    return _supportedImportHosts.contains(uri.host.toLowerCase());
  }

  Future<void> _loadAuthors() async {
    try {
      final response = await _authorService.getAllAuthors();
      if (mounted) {
        setState(() {
          _isLoadingAuthors = false;
          if (response.status && response.data != null) {
            _authorsList = response.data!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAuthors = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách tác giả: $e')),
        );
      }
    }
  }

  Future<void> _loadStories() async {
    try {
      final response = await _storyService.getAllStories();
      if (mounted) {
        setState(() {
          _isLoadingStories = false;
          if (response.status && response.data != null) {
            _storiesList = response.data!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStories = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải danh sách truyện: $e')));
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _chapterCountController.dispose();
    _delayController.dispose();
    super.dispose();
  }

  Future<void> _startImport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAuthorId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn tác giả')));
      return;
    }

    try {
      setState(() => _isImporting = true);

      final importId = await widget.importService.startImport(
        storyUrl: _urlController.text,
        authorId: _selectedAuthorId!,
        numberOfChapters: int.parse(_chapterCountController.text),
        delaySeconds: int.parse(_delayController.text),
      );

      if (!mounted) return;

      if (importId != null) {
        setState(() => _currentImportId = importId);
        _watchProgress(importId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quá trình import bắt đầu!')),
        );
      } else {
        throw Exception('Không thể khởi động quá trình import');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _startUpdate() async {
    if (_selectedStoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn truyện')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isImporting = true);

      // Lấy thông tin truyện
      final storyResponse = await _storyService.getStoryById(_selectedStoryId!);
      if (!storyResponse.status) {
        throw Exception('Không tìm thấy truyện');
      }

      final story = storyResponse.data;
      if (story == null) {
        throw Exception('Dữ liệu truyện rỗng');
      }

      // Lấy chapters của truyện
      final chaptersResponse = await _chapterService.getChaptersByStory(
        _selectedStoryId!,
      );
      if (!chaptersResponse.status || chaptersResponse.data == null) {
        throw Exception('Không tìm thấy chapters');
      }

      final chapters = chaptersResponse.data!;
      if (chapters.isEmpty) {
        throw Exception('Truyện chưa có chapter nào');
      }

      // Lấy chapter cuối cùng
      final lastChapter = chapters.last;
      final lastChapterNumber = lastChapter.chapterNumber;

      // Tính toán URL chapter kế tiếp
      final nextChapterUrl = _calculateNextChapterUrl(
        _urlController.text,
        lastChapterNumber,
      );

      final importId = await widget.importService.startImport(
        storyId: _selectedStoryId, // Pass StoryId cho update mode
        storyUrl: nextChapterUrl,
        authorId: story.authorId,
        numberOfChapters: int.parse(_chapterCountController.text),
        delaySeconds: int.parse(_delayController.text),
      );

      if (!mounted) return;

      if (importId != null) {
        setState(() => _currentImportId = importId);
        _watchProgress(importId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bắt đầu cập nhật từ chapter ${lastChapterNumber + 1}',
            ),
          ),
        );
      } else {
        throw Exception('Không thể khởi động quá trình update');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  String _calculateNextChapterUrl(String currentUrl, int lastChapterNumber) {
    // Replace chapter number
    final pattern = RegExp(r'/chapter-(\d+)');
    final match = pattern.firstMatch(currentUrl);

    if (match != null) {
      final oldUrl = currentUrl;
      final newUrl = oldUrl.replaceAll(
        '/chapter-${match.group(1)}',
        '/chapter-${lastChapterNumber + 1}',
      );
      return newUrl;
    }

    return currentUrl;
  }

  void _watchProgress(String importId) {
    widget.importService
        .watchImportProgress(importId)
        .listen(
          (progress) {
            if (!mounted) return;

            setState(() => _progress = progress);

            if (progress.isCompleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hoàn thành!'),
                  backgroundColor: Colors.green,
                ),
              );
              _clearForm();
            } else if (progress.isFailed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Thất bại: ${progress.errorMessage}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          onError: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Lỗi: $error')));
          },
        );
  }

  void _clearForm() {
    _urlController.clear();
    _chapterCountController.text = '10';
    _delayController.text = '2';
    setState(() {
      _currentImportId = null;
      _progress = null;
      _selectedAuthorId = null;
      _selectedStoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import / Cập nhật Truyện'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Mode selection
            if (_progress == null || _progress!.isProcessing)
              _buildModeSelector(),

            const SizedBox(height: 16),

            // Form nhập input
            if (_progress == null || _progress!.isProcessing)
              _buildImportForm(),

            const SizedBox(height: 24),

            // Progress indicator
            if (_progress != null) _buildProgressSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chế độ hoạt động',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'import',
                        label: Text('📥 Import Mới'),
                        icon: Icon(Icons.add),
                      ),
                      ButtonSegment(
                        value: 'update',
                        label: Text('🔄 Cập nhật'),
                        icon: Icon(Icons.refresh),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (newSelection) {
                      setState(() => _mode = newSelection.first);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _mode == 'import'
                    ? 'Nhập thông tin import truyện mới'
                    : 'Cập nhật chapters cho truyện',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Author selection (chỉ show khi import mode)
              if (_mode == 'import') ...[
                const Text(
                  'Tác giả',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _isLoadingAuthors
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<int>(
                      value: _selectedAuthorId,
                      decoration: InputDecoration(
                        labelText: 'Chọn tác giả',
                        prefixIcon: const Icon(Icons.person),
                        border: const OutlineInputBorder(),
                        helperText: 'Tác giả của truyện',
                      ),
                      items:
                          _authorsList
                              .map(
                                (author) => DropdownMenuItem(
                                  value: author.authorId,
                                  child: Text(author.displayName),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() => _selectedAuthorId = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vui lòng chọn tác giả';
                        }
                        return null;
                      },
                    ),
                const SizedBox(height: 12),
              ],

              // Story selection (chỉ show khi update mode)
              if (_mode == 'update') ...[
                const Text(
                  'Truyện cần cập nhật',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _isLoadingStories
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<int>(
                      value: _selectedStoryId,
                      decoration: InputDecoration(
                        labelText: 'Chọn truyện',
                        prefixIcon: const Icon(Icons.book),
                        border: const OutlineInputBorder(),
                        helperText: 'Chọn truyện để cập nhật chapters',
                      ),
                      items:
                          _storiesList
                              .map(
                                (story) => DropdownMenuItem(
                                  value: story.storyId,
                                  child: Text(story.title),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() => _selectedStoryId = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vui lòng chọn truyện';
                        }
                        return null;
                      },
                    ),
                const SizedBox(height: 12),
              ],

              // URL Input
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL Chapter',
                  hintText: 'https://truyenchu.app/truyen/...',
                  prefixIcon: const Icon(Icons.link),
                  border: const OutlineInputBorder(),
                  helperText:
                      _mode == 'import'
                          ? 'URL chapter đầu tiên từ truyenchu.app/com/vn'
                          : 'URL bất kỳ của truyện từ truyenchu.app/com/vn',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'URL không được để trống';
                  }
                  if (!_isSupportedImportUrl(value!)) {
                    return 'URL phải từ truyenchu.app/com/vn';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Chapter Count Input
              TextFormField(
                controller: _chapterCountController,
                decoration: InputDecoration(
                  labelText: 'Số Chapter',
                  prefixIcon: const Icon(Icons.library_books),
                  border: const OutlineInputBorder(),
                  helperText: 'Số lượng chapters cần tải (1-500)',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Số chapters không được để trống';
                  }
                  final count = int.tryParse(value!);
                  if (count == null || count < 1 || count > 500) {
                    return 'Số chapters phải từ 1 đến 500';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Delay Input
              TextFormField(
                controller: _delayController,
                decoration: InputDecoration(
                  labelText: 'Delay (giây)',
                  prefixIcon: const Icon(Icons.timer),
                  border: const OutlineInputBorder(),
                  helperText: 'Khoảng thời gian giữa các request (1-60 giây)',
                  suffixText: 'giây',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Delay không được để trống';
                  }
                  final delay = int.tryParse(value!);
                  if (delay == null || delay < 1 || delay > 60) {
                    return 'Delay phải từ 1 đến 60 giây';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isImporting
                          ? null
                          : (_mode == 'import' ? _startImport : _startUpdate),
                  icon: Icon(
                    _mode == 'import' ? Icons.cloud_download : Icons.refresh,
                  ),
                  label: Text(
                    _isImporting
                        ? 'Đang bắt đầu...'
                        : (_mode == 'import'
                            ? 'Bắt đầu Import'
                            : 'Bắt đầu Cập nhật'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    if (_progress == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      color:
          _progress!.isFailed
              ? Colors.red.shade50
              : _progress!.isCompleted
              ? Colors.green.shade50
              : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
                _getStatusIcon(),
              ],
            ),
            const SizedBox(height: 12),

            // Chapter Counter
            Text(
              'Chapters: ${_progress!.chaptersImported}/${_progress!.totalChapters}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress!.progressPercentage,
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              ),
            ),
            const SizedBox(height: 8),

            // Percentage Text
            Text(
              '${(_progress!.progressPercentage * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            // Error Message
            if (_progress!.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_progress!.errorMessage}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),

            // Timestamps
            if (_progress!.completedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Hoàn thành lúc: ${_progress!.completedAt!.toString().split('.')[0]}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),

            // Action Buttons
            if (_progress!.isCompleted || _progress!.isFailed)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _clearForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Import Truyện Khác'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    if (_progress?.isProcessing ?? false) {
      return 'Đang xử lý...';
    } else if (_progress?.isCompleted ?? false) {
      return 'Hoàn thành!';
    } else if (_progress?.isFailed ?? false) {
      return 'Thất bại';
    }
    return 'N/A';
  }

  Color _getStatusColor() {
    if (_progress?.isProcessing ?? false) return Colors.blue;
    if (_progress?.isCompleted ?? false) return Colors.green;
    if (_progress?.isFailed ?? false) return Colors.red;
    return Colors.grey;
  }

  Widget _getStatusIcon() {
    if (_progress?.isProcessing ?? false) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_progress?.isCompleted ?? false) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
    } else if (_progress?.isFailed ?? false) {
      return const Icon(Icons.error, color: Colors.red, size: 24);
    }
    return const SizedBox();
  }
}
