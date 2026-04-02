import 'package:flutter/material.dart';
import '../models/story.dart';
import '../models/author.dart';
import '../services/story_service.dart';
import '../services/author_service.dart';
import '../services/auth_service.dart';
import '../services/import_service.dart';
import '../config/api_config.dart';
import 'story_form_screen.dart';
import 'author_form_screen.dart';
import 'pending_authors_screen.dart';
import 'chapters_list_screen.dart';
import 'genre_management_screen.dart';
import 'admin/import_story_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StoryService _storyService = StoryService();
  final AuthorService _authorService = AuthorService();

  List<StoryListItem> _stories = [];
  List<AuthorListItem> _authors = [];
  bool _isLoadingStories = true;
  bool _isLoadingAuthors = true;
  String? _errorStories;
  String? _errorAuthors;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _tabController = TabController(length: 5, vsync: this);
    _initializeServices();
    _loadStories();
    _loadAuthors();
  }

  void _checkAccess() {
    final authService = AuthService();
    if (!authService.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Kiểm tra lại mounted trước khi pop
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bạn không có quyền truy cập trang này'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  void _initializeServices() {
    // Set token cho các service từ AuthService
    final authService = AuthService();
    if (authService.token != null) {
      _storyService.setToken(authService.token);
      _authorService.setToken(authService.token);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    setState(() {
      _isLoadingStories = true;
      _errorStories = null;
    });

    // Đảm bảo token được set
    final authService = AuthService();
    if (authService.token != null) {
      _storyService.setToken(authService.token);
    }

    final response = await _storyService.getAllStories();

    setState(() {
      _isLoadingStories = false;
      if (response.status && response.data != null) {
        _stories = response.data!;
        _errorStories = null;
      } else {
        _errorStories = response.message;
      }
    });
  }

  Future<void> _loadAuthors() async {
    setState(() {
      _isLoadingAuthors = true;
      _errorAuthors = null;
    });

    // Đảm bảo token được set
    final authService = AuthService();
    if (authService.token != null) {
      _authorService.setToken(authService.token);
    }

    final response = await _authorService.getAllAuthors();

    setState(() {
      _isLoadingAuthors = false;
      if (response.status && response.data != null) {
        _authors = response.data!;
        _errorAuthors = null;
      } else {
        _errorAuthors = response.message;
      }
    });
  }

  Future<void> _deleteStory(int storyId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text('Bạn có chắc chắn muốn xóa truyện "$title"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final response = await _storyService.deleteStory(storyId);

      if (mounted) {
        if (response.status) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xóa truyện thành công'),
              backgroundColor: Colors.green,
            ),
          );
          _loadStories();
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
  }

  Future<void> _deleteAuthor(int authorId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text('Bạn có chắc chắn muốn xóa tác giả "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      // Đảm bảo token được set trước khi xóa
      final authService = AuthService();
      if (authService.token != null) {
        _authorService.setToken(authService.token);
      }

      final response = await _authorService.deleteAuthor(authorId);

      if (mounted) {
        if (response.status) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xóa tác giả thành công'),
              backgroundColor: Colors.green,
            ),
          );
          _loadAuthors();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.book), text: 'Truyện'),
            Tab(icon: Icon(Icons.person), text: 'Tác giả'),
            Tab(icon: Icon(Icons.verified_user), text: 'Duyệt tác giả'),
            Tab(icon: Icon(Icons.category), text: 'Thể loại'),
            Tab(icon: Icon(Icons.cloud_download), text: 'Import'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoriesTab(),
          _buildAuthorsTab(),
          _buildPendingAuthorsTab(),
          const GenreManagementScreen(),
          _buildImportTab(),
        ],
      ),
    );
  }

  Widget _buildStoriesTab() {
    return Column(
      children: [
        // Nút thêm truyện
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StoryFormScreen(),
                  ),
                );
                if (result == true) {
                  _loadStories();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm truyện mới'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        // Danh sách truyện
        Expanded(
          child:
              _isLoadingStories
                  ? const Center(child: CircularProgressIndicator())
                  : _errorStories != null
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _errorStories!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadStories,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                  : _stories.isEmpty
                  ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có truyện nào',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _loadStories,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _stories.length,
                      itemBuilder: (context, index) {
                        final story = _stories[index];
                        return _buildStoryItem(story);
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildStoryItem(StoryListItem story) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Khi click vào card truyện, mở danh sách chapters với quyền edit
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ChaptersListScreen(
                    storyId: story.storyId,
                    storyTitle: story.title,
                    canEdit: true, // Admin luôn có quyền edit
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover image
              if (story.coverImage != null && story.coverImage!.isNotEmpty)
                Container(
                  width: 60,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      story.coverImage!,
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.book,
                          size: 30,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                ),
              if (story.coverImage != null && story.coverImage!.isNotEmpty)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              story.status,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            story.status,
                            style: TextStyle(
                              color: _getStatusColor(story.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cập nhật: ${_formatDate(story.updatedAt)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Button thêm/quản lý chương - rõ ràng hơn
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ChaptersListScreen(
                                storyId: story.storyId,
                                storyTitle: story.title,
                                canEdit: true, // Admin luôn có quyền edit
                              ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book, size: 18),
                    label: const Text('Chương', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    tooltip: 'Sửa truyện',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  StoryFormScreen(storyId: story.storyId),
                        ),
                      );
                      if (result == true) {
                        _loadStories();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Xóa truyện',
                    onPressed: () => _deleteStory(story.storyId, story.title),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorsTab() {
    return Column(
      children: [
        // Nút thêm tác giả
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuthorFormScreen(),
                  ),
                );
                if (result == true) {
                  _loadAuthors();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm tác giả mới'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        // Danh sách tác giả
        Expanded(
          child:
              _isLoadingAuthors
                  ? const Center(child: CircularProgressIndicator())
                  : _errorAuthors != null
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _errorAuthors!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAuthors,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                  : _authors.isEmpty
                  ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có tác giả nào',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _loadAuthors,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _authors.length,
                      itemBuilder: (context, index) {
                        final author = _authors[index];
                        return _buildAuthorItem(author);
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildAuthorItem(AuthorListItem author) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.deepPurple.shade100,
              child:
                  author.avatarUrl != null && author.avatarUrl!.isNotEmpty
                      ? ClipOval(
                        child: Image.network(
                          author.avatarUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              color: Colors.deepPurple,
                            );
                          },
                        ),
                      )
                      : const Icon(Icons.person, color: Colors.deepPurple),
            ),
            const SizedBox(width: 12),
            // Author info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tạo: ${_formatDate(author.createdAt)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                AuthorFormScreen(authorId: author.authorId),
                      ),
                    );
                    if (result == true) {
                      _loadAuthors();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed:
                      () => _deleteAuthor(author.authorId, author.displayName),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Đã hoàn thành':
        return Colors.green;
      case 'Đang tiến hành':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPendingAuthorsTab() {
    return const PendingAuthorsScreen();
  }

  Widget _buildImportTab() {
    final authService = AuthService();
    final importService = ImportService(
      baseUrl: ApiConfig.baseUrl,
      authToken: authService.token ?? '',
    );

    return ImportStoryScreen(importService: importService);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
