# 📚 TruyenChu.app Downloader (Selenium)

Tool tải truyện từ TruyenChu.app với giao diện đồ họa, hỗ trợ tải nhiều chapter tự động.

## 📋 Yêu Cầu Hệ Thống

### 1. Python
- **Python 3.8+** (đã cài sẵn trong máy của bạn)
- Kiểm tra: `python --version`

### 2. Google Chrome
- Cần có **Google Chrome** đã cài đặt
- Tải tại: https://www.google.com/chrome/

### 3. Thư Viện Python
Xem file `requirements.txt`

---

## 🚀 Cài Đặt

### Bước 1: Cài đặt thư viện
Mở terminal/PowerShell tại thư mục chứa file, chạy:

```bash
pip install -r requirements.txt
```

Hoặc cài từng package:
```bash
pip install beautifulsoup4 selenium webdriver-manager
```

### Bước 2: Chạy chương trình
```bash
python truyenchu_downloader_selenium.py
```

**Lần đầu chạy**: Tool sẽ tự động tải ChromeDriver (10-20 giây)

---

## 📁 Cấu Trúc File

```
📦 TruyenChu Downloader/
├── 📄 truyenchu_downloader_selenium.py  ← File chính (chạy file này)
├── 📄 requirements.txt                   ← Danh sách thư viện cần thiết
└── 📄 README.md                          ← Hướng dẫn (file này)
```

---

## 🎯 Cách Sử Dụng

### 1. Mở Tool
```bash
python truyenchu_downloader_selenium.py
```

### 2. Nhập Thông Tin

#### a) URL Chapter
- Vào https://truyenchu.app
- Chọn truyện muốn đọc
- Mở chapter bất kỳ
- Copy URL (ví dụ: `https://truyenchu.app/truyen/sua-mong/chuong-1.FkchGjEZNA4`)
- Dán vào ô "URL Chapter"

#### b) Chọn Chế Độ
- **Tải 1 chapter**: Chỉ tải chapter hiện tại
- **Tải nhiều chapter**: Tải nhiều chapter liên tiếp
  - Số chapter: 1-500
  - Delay: 0.5-10 giây (khuyến nghị: 1-2s)

#### c) Định Dạng Xuất
- **Text (.txt)**: File văn bản thuần
- **JSON (.json)**: Dữ liệu có cấu trúc

#### d) Tùy Chọn Tách File
- ☑️ **Tách thành file riêng**: Mỗi chapter = 1 file TXT
  - Tạo thư mục con theo tên truyện
  - File được đánh số: `001 - Chương 1.txt`, `002 - Chương 2.txt`, ...
- ☐ **Không tách**: Gộp tất cả chapter vào 1 file

#### e) Thư Mục Lưu
- Mặc định: `Downloads`
- Nhấn "📁 Chọn" để đổi thư mục

### 3. Bắt Đầu Tải
- Nhấn **"🚀 Bắt đầu tải"**
- Theo dõi tiến trình trong log
- Chờ hoàn thành

---

## 📊 Ví Dụ Kết Quả

### Chế độ: Gộp 1 file
```
Downloads/
└── Sửa Mộng - 10 chapters.txt
```

### Chế độ: Tách file riêng
```
Downloads/
└── Sửa Mộng/
    ├── 001 - Chương 1.txt
    ├── 002 - Chương 2.txt
    ├── 003 - Chương 3.txt
    ├── ...
    └── 010 - Chương 10.txt
```

---

## ⚙️ Thư Viện Sử Dụng

| Package | Version | Mục đích |
|---------|---------|----------|
| `beautifulsoup4` | 4.14.3 | Parse HTML |
| `selenium` | 4.39.0 | Automation browser |
| `webdriver-manager` | 4.0.2 | Quản lý ChromeDriver |

---

## 🔧 Troubleshooting

### Lỗi: "python không được nhận dạng"
**Giải pháp**: Thêm Python vào PATH hoặc dùng:
```bash
C:\Users\khanh\AppData\Local\Microsoft\WindowsApps\python.exe truyenchu_downloader_selenium.py
```

### Lỗi: "Lỗi khởi tạo trình duyệt"
**Nguyên nhân**: Chưa cài Chrome hoặc ChromeDriver lỗi  
**Giải pháp**: 
1. Cài Google Chrome
2. Chạy lại, webdriver-manager sẽ tự sửa

### Lỗi: "Không tìm thấy nội dung chapter"
**Nguyên nhân**: Timeout khi load trang  
**Giải pháp**: Kiểm tra internet, thử lại

### Tool chạy chậm
**Bình thường**: Selenium cần 2-3 giây/chapter để render JavaScript

---

## 💡 Tips

1. **Delay hợp lý**: Đặt 1-2 giây để tránh bị chặn
2. **Tải ít chapter trước**: Test với 5-10 chapter trước khi tải hàng trăm
3. **Headless mode**: Tool chạy ẩn, không hiển thị browser
4. **Tự động mở thư mục**: Sau khi tải xong, thư mục chứa file sẽ tự mở

---

## 📝 Ghi Chú

- Tool sử dụng Selenium nên **chậm hơn** phương pháp requests thông thường
- Nhưng **đáng tin cậy hơn** vì xử lý được JavaScript
- Tương thích với mọi website render nội dung bằng JS

---

## 📞 Hỗ Trợ

Nếu gặp lỗi, kiểm tra:
1. ✅ Python đã cài đặt
2. ✅ Google Chrome đã cài đặt
3. ✅ Đã chạy `pip install -r requirements.txt`
4. ✅ URL chapter hợp lệ từ truyenchu.app

---

**Phiên bản**: 2.0 (Selenium)  
**Ngày cập nhật**: 2026-01-11
