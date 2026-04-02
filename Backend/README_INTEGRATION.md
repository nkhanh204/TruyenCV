# Tích hợp Tải Truyện - Tóm tắt Thay đổi

## 📋 Tổng quan

File tải dữ liệu `truyenchu_downloader_selenium.py` đã được chuyển đổi và tích hợp vào backend ASP.NET Core. Hệ thống web giờ đây có thể **tải chapters từ truyenchu.app** và **tự động thêm truyện** vào database.

---

## 🔧 Các Thành phần được Thêm

### 1. **DTOs (Data Transfer Objects)**

#### `DTOs/Story/ImportStoryDTO.cs`

- Định nghĩa request payload cho việc import truyện
- Fields: `StoryUrl`, `AuthorId`, `NumberOfChapters`, `DelaySeconds`, `GenreIds`

#### `DTOs/Story/ImportStoryProgressDTO.cs`

- Theo dõi trạng thái import
- Fields: `ImportId`, `Status`, `ChaptersImported`, `ErrorMessage`, `CompletedAt`

#### `DTOs/Chapter/ImportChapterDTO.cs`

- Dữ liệu chapter khi import

---

### 2. **Services**

#### `Services/IService/IDataScraperService.cs`

```csharp
interface IDataScraperService {
    Task<ChapterData> FetchChapterAsync(string url);
    Task<List<ChapterData>> FetchMultipleChaptersAsync(...);
}
```

#### `Services/Implementation/DataScraperService.cs`

- **Chức năng chính:**
  - Tải HTML từ truyenchu.app
  - Parse HTML để lấy: tên truyện, tên chapter, nội dung
  - Tìm link chapter tiếp theo
  - Hỗ trợ multiple chapters với delay
- **Technologies:** HttpClient + HtmlAgilityPack

---

### 3. **Controllers**

#### `StoriesController.cs` - New Endpoints

**A. POST `/api/stories/import` - Bắt đầu Import**

```
Request:
{
  "storyUrl": "https://truyenchu.app/truyen/...",
  "authorId": 1,
  "numberOfChapters": 10,
  "delaySeconds": 2
}

Response (202 Accepted):
{
  "importId": "uuid",
  "status": "processing"
}
```

**B. GET `/api/stories/import/status/{importId}` - Kiểm tra Trạng thái**

```
Response (200 OK):
{
  "importId": "uuid",
  "status": "processing|completed|failed",
  "chaptersImported": 3,
  "totalChapters": 10,
  "errorMessage": null
}
```

---

### 4. **Configuration**

#### `Program.cs` - Service Registration

```csharp
// Thêm:
builder.Services.AddHttpClient<IDataScraperService, DataScraperService>();
builder.Services.AddMemoryCache();
```

#### `TruyenCV.csproj` - Dependencies

```xml
<PackageReference Include="HtmlAgilityPack" Version="1.11.63" />
```

---

## 🚀 Quy trình Hoạt động

### Step 1: Frontend gửi request import

```
[Flutter App] → POST /api/stories/import
                    ↓
                Backend: Kiểm tra params
                    ↓
                Response: ImportId (202 Accepted)
```

### Step 2: Backend tải dữ liệu (Background)

```
Background Task:
    ├─ Tải HTML từ URL
    ├─ Parse HTML → Lấy chapter info
    ├─ Tạo Story record
    ├─ Lưu 10 Chapter records
    └─ Update status → Memory Cache
```

### Step 3: Frontend polling trạng thái

```
[Flutter App] → GET /api/stories/import/status/{importId}
                    ↓
                Backend: Trả về progress
                    ↓
                [Display Progress Bar]
                    ↓
                Khi status = "completed" → Hiển thị kết quả
```

---

## 📱 Sử dụng trong Flutter

### Import a Story (Dart):

```dart
Future<void> importStory() async {
  final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}/api/stories/import'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'storyUrl': 'https://truyenchu.app/truyen/...',
      'authorId': 1,
      'numberOfChapters': 10,
      'delaySeconds': 2,
    }),
  );

  if (response.statusCode == 202) {
    final data = jsonDecode(response.body);
    final importId = data['data']['importId'];

    // Start polling
    _showImportProgress(importId);
  }
}

void _showImportProgress(String importId) {
  // Poll every 2 seconds
  Timer.periodic(Duration(seconds: 2), (timer) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/stories/import/status/$importId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final progress = data['data'];

      // Update UI
      setState(() {
        _progress = progress['chaptersImported'] / progress['totalChapters'];
      });

      if (progress['status'] == 'completed') {
        timer.cancel();
        _showSnackBar('Import hoàn thành!');
        // Reload stories list
        _loadStories();
      }
    }
  });
}
```

---

## ✅ Kiểm tra Chức năng

### 1. Build Project

```bash
cd Backend/TruyenCV
dotnet build
# Output: TruyenCV succeeded with 8 warning(s)
```

### 2. Test Endpoints

**Postman Example:**

```
POST http://localhost:5000/api/stories/import
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "storyUrl": "https://truyenchu.app/truyen/...",
  "authorId": 1,
  "numberOfChapters": 5,
  "delaySeconds": 2
}

Response: 202 Accepted
{"importId": "550e8400-e29b-41d4-a716-446655440000"}
```

```
GET http://localhost:5000/api/stories/import/status/550e8400-e29b-41d4-a716-446655440000

Response: 200 OK
{
  "status": "processing",
  "chaptersImported": 3,
  "totalChapters": 5
}
```

---

## 📁 File Structure

```
Backend/
├── TruyenCV/
│   ├── Controllers/
│   │   └── StoriesController.cs ✅ (Updated)
│   ├── Services/
│   │   ├── IService/
│   │   │   ├── IDataScraperService.cs ✅ (New)
│   │   │   └── ...
│   │   └── Implementation/
│   │       ├── DataScraperService.cs ✅ (New)
│   │       └── ...
│   ├── DTOs/
│   │   ├── Story/
│   │   │   └── ImportStoryDTO.cs ✅ (New)
│   │   ├── Chapter/
│   │   │   └── ImportChapterDTO.cs ✅ (New)
│   │   └── ...
│   ├── Program.cs ✅ (Updated)
│   └── TruyenCV.csproj ✅ (Updated)
├── IMPORT_API_GUIDE.md ✅ (New)
└── README_INTEGRATION.md ✅ (This file)
```

---

## ⚙️ Configuration Notes

### HtmlAgilityPack Selectors

DataScraperService sử dụng XPath selectors để parse HTML:

```csharp
// Novel Title
"//h1[@class='reading-book-title']"

// Chapter Title
"//h2[@class='reading-chapter-title']"

// Chapter Content
"//article[@class='reading-content']"

// Next Chapter Link
"//a[contains(@class, 'reading-chapter-btn--next')]"
```

Nếu truyenchu.app thay đổi HTML structure, cần cập nhật selectors trong `DataScraperService`.

---

## 🔐 Security

- ✅ Requires **JWT Authentication** (Bearer token)
- ✅ Requires **Admin or Employee Role**
- ✅ Input validation: URL, AuthorId, numberOfChapters
- ✅ Rate limiting: Delay between requests
- ✅ URL whitelisting: Only truyenchu.app

---

## 📊 Performance Considerations

| Metric                  | Value     | Notes                    |
| ----------------------- | --------- | ------------------------ |
| Max chapters per import | 500       | Prevent server overload  |
| Min/Max delay           | 1-60 sec  | Rate limiting            |
| Progress cache TTL      | 1 hour    | In-memory cache          |
| Request timeout         | 30 sec    | Per chapter HTTP request |
| Concurrent imports      | Unlimited | Background tasks         |

---

## 🐛 Troubleshooting

### Issue: Import không bắt đầu

- ✅ Kiểm tra JWT token hợp lệ
- ✅ Kiểm tra role: Admin hoặc Employee?
- ✅ Kiểm tra AuthorId tồn tại

### Issue: Status luôn "processing"

- ✅ Kiểm tra logs: `_logger.LogInformation()`
- ✅ Kiểm tra internet connection
- ✅ Kiểm tra truyenchu.app có accessible

### Issue: Không parse được chapters

- ✅ Truyenchu.app thay đổi HTML?
- ✅ Cần cập nhật XPath selectors
- ✅ Có thể nâng cấp sang PuppeteerSharp (JavaScript support)

---

## 🔮 Future Enhancements

- [ ] **PuppeteerSharp Integration** - Hỗ trợ JavaScript loading
- [ ] **Database Progress Persistence** - Không mất khi restart
- [ ] **Scheduled Import Jobs** - Cron jobs import tuyên định
- [ ] **Retry Mechanism** - Auto retry failed chapters
- [ ] **Multi-source Support** - Hỗ trợ nhiều website khác
- [ ] **WebSocket Updates** - Real-time progress updates
- [ ] **Python Integration** - Call Python script từ C#

---

## 📚 Related Files

- **API Documentation:** `IMPORT_API_GUIDE.md`
- **Python Original:** `truyenchu_downloader_selenium.py`
- **Backend:** `Backend/TruyenCV/`
- **Frontend:** `Frontend/truyencv_frontend/`

---

## 👤 Author Notes

- Converter từ Python GUI → C# Web API
- Chuyển từ Selenium → HtmlAgilityPack
- Background task processing (non-blocking)
- Memory cache for progress tracking
- RESTful API design

---

Generated: 2024-01-15
Status: ✅ Integration Complete
