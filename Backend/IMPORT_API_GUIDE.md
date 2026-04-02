# Hướng dẫn Tích hợp Tải Truyện từ TruyenChu.app

## Tổng quan

Hệ thống web backend đã được tích hợp chức năng tải dữ liệu chapter từ truyenchu.app. Quy trình load bao gồm:

1. **Backend tải dữ liệu** từ URL truyenchu.app bằng HTTP scraper
2. **Tự động tạo Story** (truyện) với metadata
3. **Lưu chapters** vào database
4. **Theo dõi tiến độ** của quá trình import

## API Endpoints

### 1. Bắt đầu Quá trình Import Chapter

**Endpoint:** `POST /api/stories/import`

**Authorization:** `Bearer <JWT_TOKEN>` (Role: Admin hoặc Employee)

**Request Body:**

```json
{
  "storyUrl": "https://truyenchu.app/truyen/...",
  "authorId": 1,
  "primaryGenreId": 1,
  "genreIds": [1, 2, 3],
  "numberOfChapters": 10,
  "delaySeconds": 2
}
```

**Parameters:**

- `storyUrl` (string, required): URL chapter đầu tiên của truyện
- `authorId` (int, required): ID của tác giả trong hệ thống (phải tồn tại)
- `primaryGenreId` (int, optional): ID thể loại chính
- `genreIds` (array, optional): Danh sách ID thể loại
- `numberOfChapters` (int, required): Số chapter cần tải (1-500)
- `delaySeconds` (int, required): Delay giữa các request, tính bằng giây (1-60)

**Success Response (202 Accepted):**

```json
{
  "status": true,
  "message": "Quá trình tải chapter bắt đầu.",
  "data": {
    "importId": "uuid-string",
    "storyUrl": "https://truyenchu.app/truyen/...",
    "numberOfChapters": 10
  }
}
```

**Example cURL:**

```bash
curl -X POST http://localhost:5000/api/stories/import \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "storyUrl": "https://truyenchu.app/truyen/...",
    "authorId": 1,
    "numberOfChapters": 5,
    "delaySeconds": 2
  }'
```

---

### 2. Kiểm tra Trạng thái Import

**Endpoint:** `GET /api/stories/import/status/{importId}`

**Authorization:** Không cần (Public)

**URL Parameters:**

- `importId` (string, required): ID nhận được từ endpoint import

**Success Response (200 OK):**

```json
{
  "status": true,
  "message": "Lấy trạng thái import thành công.",
  "data": {
    "importId": "uuid-string",
    "status": "processing",
    "chaptersImported": 3,
    "totalChapters": 10,
    "errorMessage": null,
    "startedAt": "2024-01-15T10:30:00Z",
    "completedAt": null
  }
}
```

**Status Values:**

- `processing`: Quá trình import đang diễn ra
- `completed`: Hoàn thành thành công
- `failed`: Lỗi trong quá trình import

**Example cURL:**

```bash
curl -X GET http://localhost:5000/api/stories/import/status/550e8400-e29b-41d4-a716-446655440000
```

---

## Quy trình Hoạt động

### 1. Bước 1: Khởi động Import

```
Client → POST /api/stories/import
    ↓
Backend kiểm tra params
    ↓
Tạo ImportId & Progress
    ↓
Response với ImportId (202 Accepted)
    ↓
Bắt đầu Background Task (không chặn request)
```

### 2. Bước 2: Background Task Xử lý

```
Background Task:
    ↓
FetchChapters từ truyenchu.app (qua HTTP Scraper)
    ↓
Tạo Story mới
    ↓
Lưu từng Chapter vào DB
    ↓
Update Progress → Memory Cache
```

### 3. Bước 3: Theo dõi Tiến độ

```
Client → GET /api/stories/import/status/{importId}
    ↓
Backend trả về Progress từ Memory Cache
    ↓
Response với trạng thái hiện tại (200 OK)
```

---

## Ví dụ Sử dụng (Frontend)

### React/DOM Example:

```javascript
// 1. Bắt đầu import
async function startImport() {
  const response = await fetch("/api/stories/import", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      storyUrl: "https://truyenchu.app/truyen/...",
      authorId: 1,
      numberOfChapters: 10,
      delaySeconds: 2,
    }),
  });

  if (response.status === 202) {
    const data = await response.json();
    const importId = data.data.importId;
    // Bắt đầu polling
    pollImportStatus(importId);
  }
}

// 2. Polling trạng thái
async function pollImportStatus(importId) {
  const interval = setInterval(async () => {
    const response = await fetch(`/api/stories/import/status/${importId}`);
    const data = await response.json();

    if (data.data) {
      const progress = data.data;
      console.log(
        `Import: ${progress.chaptersImported}/${progress.totalChapters}`,
      );

      if (progress.status === "completed") {
        clearInterval(interval);
        console.log("Import hoàn thành!");
      } else if (progress.status === "failed") {
        clearInterval(interval);
        console.error("Import failed:", progress.errorMessage);
      }
    }
  }, 2000); // Poll mỗi 2 giây
}
```

### Flutter Example:

```dart
Future<void> startImport() async {
  final authToken = await getAuthToken(); // Lấy JWT token

  final response = await http.post(
    Uri.parse('http://api.example.com/api/stories/import'),
    headers: {
      'Authorization': 'Bearer $authToken',
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

    // Bắt đầu polling
    _pollImportStatus(importId);
  }
}

void _pollImportStatus(String importId) {
  Future.doWhile(() => Future.delayed(Duration(seconds: 2)).then((_) async {
    final response = await http.get(
      Uri.parse('http://api.example.com/api/stories/import/status/$importId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final progress = data['data'];

      print('${progress['chaptersImported']}/${progress['totalChapters']}');

      if (progress['status'] == 'completed' || progress['status'] == 'failed') {
        return false; // Stop polling
      }
      return true; // Continue polling
    }
    return false;
  }));
}
```

---

## Cấu hình Backend

### Install Dependencies

```bash
dotnet add package HtmlAgilityPack
```

### Program.cs Configuration

Đã được thêm:

```csharp
builder.Services.AddHttpClient<IDataScraperService, DataScraperService>();
builder.Services.AddMemoryCache();
```

---

## Error Handling

### Possible Errors:

| Error                        | HTTP Status | Message                           | Giải pháp                    |
| ---------------------------- | ----------- | --------------------------------- | ---------------------------- |
| URL không đạt yêu cầu        | 400         | "URL không hợp lệ"                | Kiểm tra URL đúng định dạng  |
| URL không từ truyenchu.app   | 400         | "Chỉ hỗ trợ URL từ truyenchu.app" | Sử dụng URL từ truyenchu.app |
| Author không tồn tại         | 400         | "AuthorId không hợp lệ"           | Tạo Author trước             |
| Số chapter vượt quá giới hạn | 400         | "Số chapter phải từ 1 đến 500"    | Giảm số chapter              |
| Delay không hợp lệ           | 400         | "Delay phải từ 1 đến 60 giây"     | Điều chỉnh delay             |
| Không tìm thấy chapter       | 500         | "Không tải được chapter nào"      | Kiểm tra URL có hợp lệ       |
| Network error                | 500         | Lỗi kết nối                       | Kiểm tra internet            |

---

## Constraints & Limitations

1. **Max chapters:** 500 (để tránh overload server)
2. **Min delay:** 1 giây (để tránh spam)
3. **Max delay:** 60 giây (để tránh timeout)
4. **Session timeout:** 1 giờ (progress data bị xóa sau 1 giờ)
5. **Only HTTP GET/POST:** Không hỗ trợ PUT/DELETE tài nguyên từ URL gốc

---

## Notes

- Background task chạy **non-blocking**, client không cần chờ kết quả ngay
- Progress được lưu trong **memory cache** (không persistent)
- Quá trình import là **asynchronous**
- Hỗ trợ **concurrent imports** (nhiều import cùng lúc)
- DataScraperService sử dụng **HtmlAgilityPack** để parse HTML

---

## Troubleshooting

### Import không bắt đầu?

- Kiểm tra JWT token hợp lệ
- Kiểm tra role: Admin hoặc Employee
- Kiểm tra AuthorId tồn tại

### Status luôn "processing"?

- Kiểm tra logs backend
- Kiểm tra internet kết nối
- Kiểm tra URL truyenchu.app có thay đổi structure

### Không tải được chapters?

- Kiểm tra HTML structure của truyenchu.app
- Có thể website đã thay đổi CSS selectors
- Cần update DataScraperService selectors

---

## Advanced: Tích hợp với Python Scraper

Nếu HtmlAgilityPack không đủ (site dùng JavaScript), có thể:

1. **Sử dụng PuppeteerSharp**

```csharp
// Thay HtmlAgilityPack bằng PuppeteerSharp
// PuppeteerSharp có khả năng load JavaScript
```

2. **Gọi Python Script từ C#**

```csharp
// ProcessStart gọi Python scraper
// JSON result parse vào DB
```

---

## Future Enhancements

- [ ] Hỗ trợ Python Selenium integration
- [ ] Database persistent progress tracking
- [ ] Scheduled import jobs
- [ ] Retry failed chapters
- [ ] Hỗ trợ multiple story sources
