import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
from bs4 import BeautifulSoup
import json
import os
import time
from datetime import datetime
import threading
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager


class TruyenChuDownloader:
    def __init__(self, root):
        self.root = root
        self.root.title("TruyenChu.app Downloader (Selenium)")
        self.root.geometry("900x700")
        self.root.configure(bg='#2b2d42')
        
        # Biến lưu trữ
        self.downloaded_chapters = []
        self.is_downloading = False
        self.save_directory = os.path.expanduser("~/Downloads")
        self.driver = None
        
        # Tạo giao diện
        self.create_widgets()
        
        # Cleanup khi đóng cửa sổ
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
    def create_widgets(self):
        # Style
        style = ttk.Style()
        style.theme_use('clam')
        style.configure('TLabel', background='#2b2d42', foreground='#edf2f4', font=('Segoe UI', 10))
        style.configure('TButton', font=('Segoe UI', 10, 'bold'))
        style.configure('TEntry', fieldbackground='#8d99ae', foreground='#000000')
        style.configure('TCombobox', fieldbackground='#8d99ae', foreground='#000000')
        
        # Header
        header = tk.Label(self.root, text="📚 TruyenChu.app Downloader (Selenium)", 
                         font=('Segoe UI', 24, 'bold'), bg='#2b2d42', fg='#edf2f4')
        header.pack(pady=20)
        
        # Main Frame
        main_frame = tk.Frame(self.root, bg='#2b2d42')
        main_frame.pack(padx=20, pady=10, fill='both', expand=True)
        
        # URL Input
        url_frame = tk.Frame(main_frame, bg='#2b2d42')
        url_frame.pack(fill='x', pady=5)
        
        tk.Label(url_frame, text="URL Chapter:", bg='#2b2d42', fg='#edf2f4', 
                font=('Segoe UI', 11, 'bold')).pack(anchor='w')
        self.url_entry = ttk.Entry(url_frame, font=('Segoe UI', 10))
        self.url_entry.pack(fill='x', pady=5)
        self.url_entry.insert(0, "https://truyenchu.app/truyen/...")
        
        # Options Frame
        options_frame = tk.Frame(main_frame, bg='#2b2d42')
        options_frame.pack(fill='x', pady=10)
        
        # Left Column
        left_col = tk.Frame(options_frame, bg='#2b2d42')
        left_col.pack(side='left', fill='both', expand=True, padx=(0, 10))
        
        tk.Label(left_col, text="Chế độ tải:", bg='#2b2d42', fg='#edf2f4',
                font=('Segoe UI', 10, 'bold')).pack(anchor='w')
        self.mode_var = tk.StringVar(value="single")
        mode_frame = tk.Frame(left_col, bg='#2b2d42')
        mode_frame.pack(fill='x', pady=5)
        
        ttk.Radiobutton(mode_frame, text="Tải 1 chapter", variable=self.mode_var, 
                       value="single", command=self.toggle_mode).pack(side='left', padx=5)
        ttk.Radiobutton(mode_frame, text="Tải nhiều chapter", variable=self.mode_var, 
                       value="multiple", command=self.toggle_mode).pack(side='left', padx=5)
        
        # Number of chapters
        num_frame = tk.Frame(left_col, bg='#2b2d42')
        num_frame.pack(fill='x', pady=5)
        tk.Label(num_frame, text="Số chapter:", bg='#2b2d42', fg='#edf2f4',
                font=('Segoe UI', 10)).pack(side='left', padx=(0, 10))
        self.num_chapters = tk.Spinbox(num_frame, from_=1, to=500, width=10, 
                                      font=('Segoe UI', 10), state='disabled')
        self.num_chapters.pack(side='left')
        
        # Delay
        delay_frame = tk.Frame(left_col, bg='#2b2d42')
        delay_frame.pack(fill='x', pady=5)
        tk.Label(delay_frame, text="Delay (giây):", bg='#2b2d42', fg='#edf2f4',
                font=('Segoe UI', 10)).pack(side='left', padx=(0, 10))
        self.delay_var = tk.Spinbox(delay_frame, from_=0.5, to=10, increment=0.5, 
                                   width=10, font=('Segoe UI', 10), state='disabled')
        self.delay_var.pack(side='left')
        
        # Right Column
        right_col = tk.Frame(options_frame, bg='#2b2d42')
        right_col.pack(side='left', fill='both', expand=True)
        
        tk.Label(right_col, text="Định dạng xuất:", bg='#2b2d42', fg='#edf2f4',
                font=('Segoe UI', 10, 'bold')).pack(anchor='w')
        self.format_var = tk.StringVar(value="txt")
        format_frame = tk.Frame(right_col, bg='#2b2d42')
        format_frame.pack(fill='x', pady=5)
        
        ttk.Radiobutton(format_frame, text="Text (.txt)", variable=self.format_var, 
                       value="txt").pack(side='left', padx=5)
        ttk.Radiobutton(format_frame, text="JSON (.json)", variable=self.format_var, 
                       value="json").pack(side='left', padx=5)
        
        # Separate files option
        self.separate_files_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(right_col, text="Tách thành file riêng (mỗi chapter 1 file)", 
                       variable=self.separate_files_var).pack(anchor='w', pady=5)
        
        # Save Directory
        save_frame = tk.Frame(right_col, bg='#2b2d42')
        save_frame.pack(fill='x', pady=5)
        tk.Label(save_frame, text="Thư mục lưu:", bg='#2b2d42', fg='#edf2f4',
                font=('Segoe UI', 10, 'bold')).pack(anchor='w')
        
        dir_input_frame = tk.Frame(save_frame, bg='#2b2d42')
        dir_input_frame.pack(fill='x', pady=5)
        self.save_dir_label = tk.Label(dir_input_frame, text=self.save_directory, 
                                      bg='#8d99ae', fg='#000000', font=('Segoe UI', 9),
                                      anchor='w', padx=5, relief='sunken')
        self.save_dir_label.pack(side='left', fill='x', expand=True, padx=(0, 5))
        
        browse_btn = tk.Button(dir_input_frame, text="📁 Chọn", command=self.browse_directory,
                              bg='#8d99ae', fg='#000000', font=('Segoe UI', 9, 'bold'),
                              relief='raised', cursor='hand2')
        browse_btn.pack(side='left')
        
        # Buttons
        button_frame = tk.Frame(main_frame, bg='#2b2d42')
        button_frame.pack(fill='x', pady=15)
        
        self.download_btn = tk.Button(button_frame, text="🚀 Bắt đầu tải", 
                                     command=self.start_download_thread,
                                     bg='#ef233c', fg='#ffffff', font=('Segoe UI', 12, 'bold'),
                                     relief='raised', cursor='hand2', padx=20, pady=10)
        self.download_btn.pack(side='left', padx=5)
        
        self.stop_btn = tk.Button(button_frame, text="⏹️ Dừng", 
                                 command=self.stop_download,
                                 bg='#d90429', fg='#ffffff', font=('Segoe UI', 12, 'bold'),
                                 relief='raised', cursor='hand2', padx=20, pady=10,
                                 state='disabled')
        self.stop_btn.pack(side='left', padx=5)
        
        clear_btn = tk.Button(button_frame, text="🗑️ Xóa log", 
                             command=self.clear_log,
                             bg='#8d99ae', fg='#000000', font=('Segoe UI', 12, 'bold'),
                             relief='raised', cursor='hand2', padx=20, pady=10)
        clear_btn.pack(side='left', padx=5)
        
        # Progress Bar
        self.progress = ttk.Progressbar(main_frame, mode='determinate', length=400)
        self.progress.pack(fill='x', pady=10)
        
        self.progress_label = tk.Label(main_frame, text="Sẵn sàng...", 
                                      bg='#2b2d42', fg='#a8dadc', font=('Segoe UI', 10))
        self.progress_label.pack()
        
        # Log Area
        log_frame = tk.Frame(main_frame, bg='#2b2d42')
        log_frame.pack(fill='both', expand=True, pady=10)
        
        tk.Label(log_frame, text="📋 Log:", bg='#2b2d42', fg='#edf2f4',
                font=('Segoe UI', 11, 'bold')).pack(anchor='w')
        
        self.log_text = scrolledtext.ScrolledText(log_frame, height=15, 
                                                 bg='#1a1a2e', fg='#edf2f4',
                                                 font=('Consolas', 9), relief='sunken')
        self.log_text.pack(fill='both', expand=True)
        
        # Tags cho màu sắc log
        self.log_text.tag_config('info', foreground='#a8dadc')
        self.log_text.tag_config('success', foreground='#06ffa5')
        self.log_text.tag_config('error', foreground='#ef233c')
        self.log_text.tag_config('warning', foreground='#ffd60a')
        
        self.add_log("Sẵn sàng tải truyện với Selenium...", 'info')
        
    def toggle_mode(self):
        if self.mode_var.get() == 'multiple':
            self.num_chapters.config(state='normal')
            self.delay_var.config(state='normal')
        else:
            self.num_chapters.config(state='disabled')
            self.delay_var.config(state='disabled')
            
    def browse_directory(self):
        directory = filedialog.askdirectory(initialdir=self.save_directory)
        if directory:
            self.save_directory = directory
            self.save_dir_label.config(text=directory)
            self.add_log(f"Đã chọn thư mục: {directory}", 'info')
            
    def add_log(self, message, tag='info'):
        timestamp = datetime.now().strftime('%H:%M:%S')
        self.log_text.insert('end', f"[{timestamp}] {message}\n", tag)
        self.log_text.see('end')
        
    def clear_log(self):
        self.log_text.delete('1.0', 'end')
        self.downloaded_chapters = []
        self.add_log("Đã xóa log...", 'info')
    
    def init_driver(self):
        """Khởi tạo Selenium WebDriver"""
        if self.driver is None:
            try:
                self.add_log("Đang khởi tạo trình duyệt...", 'info')
                chrome_options = Options()
                chrome_options.add_argument('--headless')
                chrome_options.add_argument('--disable-gpu')
                chrome_options.add_argument('--no-sandbox')
                chrome_options.add_argument('--disable-dev-shm-usage')
                chrome_options.add_argument('--log-level=3')
                chrome_options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
                
                service = Service(ChromeDriverManager().install())
                self.driver = webdriver.Chrome(service=service, options=chrome_options)
                self.add_log("✓ Đã khởi tạo trình duyệt", 'success')
            except Exception as e:
                raise Exception(f"Lỗi khởi tạo trình duyệt: {str(e)}")
        
    def fetch_chapter(self, url):
        """Tải nội dung chapter từ URL bằng Selenium"""
        try:
            # Khởi tạo driver nếu chưa có
            if self.driver is None:
                self.init_driver()
            
            # Truy cập trang
            self.driver.get(url)
            
            # Đợi nội dung load
            wait = WebDriverWait(self.driver, 10)
            wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, 'article.reading-content')))
            
            # Lấy thông tin
            try:
                novel_title = self.driver.find_element(By.CSS_SELECTOR, 'h1.reading-book-title').text
            except:
                novel_title = 'Không tìm thấy tên truyện'
            
            try:
                chapter_title = self.driver.find_element(By.CSS_SELECTOR, 'h2.reading-chapter-title').text
            except:
                chapter_title = 'Không tìm thấy tên chương'
            
            # Lấy nội dung
            try:
                content_element = self.driver.find_element(By.CSS_SELECTOR, 'article.reading-content')
                content = content_element.text
                paragraph_count = len([p for p in content.split('\n\n') if p.strip()])
            except:
                raise Exception('Không tìm thấy nội dung chapter')
            
            # Lấy link chapter tiếp theo
            next_url = None
            try:
                next_link = self.driver.find_element(By.CSS_SELECTOR, 'a.reading-chapter-btn--next')
                next_url = next_link.get_attribute('href')
            except:
                pass  # Không có chapter tiếp theo
            
            return {
                'novel_title': novel_title,
                'chapter_title': chapter_title,
                'content': content,
                'url': url,
                'next_url': next_url,
                'paragraph_count': paragraph_count
            }
            
        except Exception as e:
            raise Exception(f"Lỗi khi tải chapter: {str(e)}")
            
    def start_download_thread(self):
        """Bắt đầu tải trong thread riêng"""
        if not self.is_downloading:
            thread = threading.Thread(target=self.start_download, daemon=True)
            thread.start()
            
    def start_download(self):
        """Bắt đầu quá trình tải"""
        url = self.url_entry.get().strip()
        
        if not url or url == "https://truyenchu.app/truyen/...":
            messagebox.showerror("Lỗi", "Vui lòng nhập URL chapter!")
            return
            
        if 'truyenchu.app' not in url:
            messagebox.showerror("Lỗi", "URL không hợp lệ! Vui lòng nhập URL từ truyenchu.app")
            return
            
        self.is_downloading = True
        self.downloaded_chapters = []
        self.download_btn.config(state='disabled')
        self.stop_btn.config(state='normal')
        
        mode = self.mode_var.get()
        num_chapters = int(self.num_chapters.get()) if mode == 'multiple' else 1
        delay = float(self.delay_var.get()) if mode == 'multiple' else 0
        
        self.add_log(f"Bắt đầu tải {num_chapters} chapter...", 'info')
        self.progress['maximum'] = num_chapters
        self.progress['value'] = 0
        
        current_url = url
        downloaded = 0
        
        try:
            for i in range(num_chapters):
                if not self.is_downloading:
                    self.add_log("Đã dừng tải!", 'warning')
                    break
                    
                if not current_url:
                    self.add_log("Không còn chapter tiếp theo!", 'warning')
                    break
                    
                self.add_log(f"Đang tải chapter {i + 1}/{num_chapters}...", 'info')
                self.progress_label.config(text=f"Đang tải {i + 1}/{num_chapters}...")
                
                chapter_data = self.fetch_chapter(current_url)
                self.downloaded_chapters.append(chapter_data)
                downloaded += 1
                
                self.add_log(f"✓ {chapter_data['chapter_title']} ({chapter_data['paragraph_count']} đoạn)", 'success')
                
                self.progress['value'] = downloaded
                self.root.update_idletasks()
                
                current_url = chapter_data['next_url']
                
                # Delay
                if i < num_chapters - 1 and current_url and self.is_downloading:
                    time.sleep(delay)
                    
            if self.is_downloading:
                self.add_log(f"Hoàn thành! Đã tải {downloaded} chapter.", 'success')
                self.save_file()
            
        except Exception as e:
            self.add_log(f"Lỗi: {str(e)}", 'error')
            messagebox.showerror("Lỗi", str(e))
            
        finally:
            self.is_downloading = False
            self.download_btn.config(state='normal')
            self.stop_btn.config(state='disabled')
            self.progress_label.config(text="Hoàn thành!")
            
    def stop_download(self):
        """Dừng quá trình tải"""
        self.is_downloading = False
        self.add_log("Đang dừng...", 'warning')
        
    def save_file(self):
        """Lưu file"""
        if not self.downloaded_chapters:
            self.add_log("Không có nội dung để lưu!", 'error')
            return
            
        format_type = self.format_var.get()
        novel_title = self.downloaded_chapters[0]['novel_title']
        num_chapters = len(self.downloaded_chapters)
        separate_files = self.separate_files_var.get()
        
        # Tạo tên file an toàn
        safe_title = "".join(c for c in novel_title if c.isalnum() or c in (' ', '-', '_')).strip()
        
        if format_type == 'txt':
            if separate_files:
                # Tạo thư mục con cho truyện
                story_dir = os.path.join(self.save_directory, safe_title)
                os.makedirs(story_dir, exist_ok=True)
                
                # Lưu từng chapter riêng
                for i, chapter in enumerate(self.downloaded_chapters, 1):
                    # Tạo tên file từ tên chapter
                    chapter_name = chapter['chapter_title'].replace('/', '-').replace('\\', '-')
                    safe_chapter = "".join(c for c in chapter_name if c.isalnum() or c in (' ', '-', '_')).strip()
                    filename = f"{i:03d} - {safe_chapter}.txt"
                    filepath = os.path.join(story_dir, filename)
                    
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write('=' * 80 + '\n')
                        f.write(f"{chapter['novel_title']}\n")
                        f.write(f"{chapter['chapter_title']}\n")
                        f.write('=' * 80 + '\n\n')
                        f.write(chapter['content'])
                
                self.add_log(f"✓ Đã lưu {num_chapters} file vào: {story_dir}", 'success')
                messagebox.showinfo("Thành công", f"Đã lưu {num_chapters} file vào:\n{story_dir}")
                os.startfile(story_dir)
            else:
                # Lưu tất cả vào 1 file
                filename = f"{safe_title} - {num_chapters} chapters.txt"
                filepath = os.path.join(self.save_directory, filename)
                
                with open(filepath, 'w', encoding='utf-8') as f:
                    for chapter in self.downloaded_chapters:
                        f.write('=' * 80 + '\n')
                        f.write(f"{chapter['novel_title']}\n")
                        f.write(f"{chapter['chapter_title']}\n")
                        f.write('=' * 80 + '\n\n')
                        f.write(chapter['content'] + '\n\n\n')
                
                self.add_log(f"✓ Đã lưu file: {filename}", 'success')
                messagebox.showinfo("Thành công", f"Đã lưu file:\n{filepath}")
                os.startfile(self.save_directory)
                    
        elif format_type == 'json':
            filename = f"{safe_title} - {num_chapters} chapters.json"
            filepath = os.path.join(self.save_directory, filename)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(self.downloaded_chapters, f, ensure_ascii=False, indent=2)
            
            self.add_log(f"✓ Đã lưu file: {filename}", 'success')
            messagebox.showinfo("Thành công", f"Đã lưu file:\n{filepath}")
            os.startfile(self.save_directory)
    
    def on_closing(self):
        """Cleanup khi đóng ứng dụng"""
        if self.driver:
            try:
                self.driver.quit()
            except:
                pass
        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = TruyenChuDownloader(root)
    root.mainloop()
