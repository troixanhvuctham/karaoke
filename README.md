# 🎤 Hát Karaoke

Gõ tên bài hát, chọn video karaoke và hát ngay trong trang. Chạy trên Windows, không cần cài thêm gì.

## Cách dùng

1. Bấm nút xanh **Code** → **Download ZIP**, rồi giải nén ra một thư mục (ví dụ `Documents\Karaoke`).
2. Nhấp đúp file **`Karaoke.bat`**.
   - Nếu Windows hiện cảnh báo, bấm **More info** → **Run anyway** (hoặc **Run**).
3. **Lần đầu tiên**, Notepad sẽ mở ra: dán YouTube API key vào dòng trống cuối, bấm **Ctrl+S**, rồi đóng Notepad. Trang karaoke sẽ tự mở.
   - Không có key cũng được: cứ đóng Notepad, trang vẫn tìm bài bình thường.
4. Ngoài Desktop sẽ tự có biểu tượng micro **Hát Karaoke**. Những lần sau chỉ cần nhấp đúp biểu tượng đó.
   - Nếu chuyển thư mục đi chỗ khác, nhấp đúp `Karaoke.bat` một lần để biểu tượng ngoài Desktop cập nhật theo.

## App cho hộp TV Android

Dành cho hộp TV Android (kể cả Android 7) không còn dùng được app YouTube. Không cần API key.

1. Trên hộp TV, mở trình duyệt và vào link:
   **https://github.com/troixanhvuctham/karaoke/releases/latest/download/karaoke.apk**
2. Mở file `karaoke.apk` vừa tải để cài. Nếu máy hỏi, cho phép **cài ứng dụng từ nguồn không xác định** (Unknown sources).
3. Mở app **Hát Karaoke** trên màn hình chính.

Dùng remote: mũi tên để di chuyển, **OK** để chọn. Khi đang phát: **OK** dừng/phát, **◀ ▶** tua 10 giây, **Back** chọn bài khác. Hát xong bài, app tự quay về màn hình tìm bài.
Có bản mới thì tải lại link trên và cài đè, không cần gỡ app cũ.

## Lấy YouTube API key (miễn phí, không bắt buộc)

Không có key, trang tự tìm trên YouTube và không giới hạn số lần tìm. Có key thì trang dùng key trước (kết quả chỉ gồm video cho phát ngay trong trang).

1. Vào [Google Cloud Console](https://console.cloud.google.com), đăng nhập Gmail, tạo một project mới.
2. Vào [YouTube Data API v3](https://console.cloud.google.com/apis/library/youtube.googleapis.com) → bấm **Enable**.
3. Vào [Credentials](https://console.cloud.google.com/apis/credentials) → **Create credentials** → **API key**, copy key (bắt đầu bằng `AIza...`).

Mỗi ngày key tìm được khoảng 100 lần. Bài đã tìm được nhớ lại 7 ngày nên tìm lại không tốn lượt. Hết lượt thì trang tự tìm không cần key như trên.

Muốn đổi key: mở file `api-key.txt` bằng Notepad, hoặc bấm **Cài đặt** ở cuối trang karaoke.
