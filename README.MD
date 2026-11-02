# ✂️ BARBERSMART - ỨNG DỤNG ĐẶT LỊCH CẮT TÓC (FULLSTACK NESTJS & FLUTTER)

Dự án **BarberSmart** được xây dựng theo kiến trúc Monorepo gồm 2 phần tách biệt:
- `backend/`: **NestJS** (RESTful API + **Socket.IO** WebSocket), **PostgreSQL (Supabase)** với **TypeORM**, **Nodemailer** (Gmail OTP 6 số), **Cloudinary** (lưu trữ tối đa 5 ảnh/bài), **Firebase Cloud Messaging (FCM)**, và **SePay Webhook + VietQR động**.
- `mobile/`: **Flutter** theo **Clean Architecture** (`core`, `domain`, `data`, `presentation`), quản lý state bằng `flutter_bloc`, DI bằng `get_it`, HTTP bằng `dio`, điều hướng bằng `go_router`, bản đồ **OpenStreetMap (`flutter_map`)** và giao diện chuẩn Pixel-perfect tông xanh `#00A859`.

---

## 🚀 CÁCH CHẠY DỰ ÁN NGAY LẬP TỨC

### Cách 1: Chạy ngay ứng dụng Flutter (`mobile/`) trên Chrome / Edge / Windows (Không cần chờ cài Database)
Mình đã khởi tạo sẵn đầy đủ thư mục nền tảng (`web`, `windows`, `android`, `ios`) và dữ liệu mẫu sẵn có. Tại Terminal đang đứng ở `mobile`, bạn chỉ cần gõ **1 trong 3 lệnh** sau:

```powershell
# Chạy trên trình duyệt Google Chrome (Nhanh nhất & Khuyên dùng để test ngay):
flutter run -d chrome

# Hoặc chạy trên trình duyệt Microsoft Edge:
flutter run -d edge

# Hoặc chạy thành app Desktop trên Windows:
flutter run -d windows
```
*(Nếu bạn bật máy ảo Android từ Android Studio thì chỉ cần gõ `flutter run`).*

---

### Cách 2: Chạy thêm Server Backend NestJS (`backend/`) kết nối Supabase PostgreSQL
1. Mở file `backend/.env` (mình đã tạo sẵn cho bạn từ `.env.example`).
2. Vào [Supabase](https://supabase.com) tạo 1 project miễn phí -> vào **Project Settings -> Database -> Connection string (URI)** -> copy chuỗi kết nối dán đè vào dòng `DATABASE_URL=...` trong `backend/.env`.
3. Tại Terminal đứng ở thư mục `backend`, chạy:
```powershell
npm run start:dev
```
Server sẽ tự động tạo toàn bộ bảng PostgreSQL (`DB_SYNCHRONIZE=true`) và lắng nghe tại `http://localhost:3000/api/v1` cùng Socket.IO `/realtime`.

---

### 🔑 Tài khoản Demo có sẵn để đăng nhập test ngay (Mật khẩu: `123456` | OTP: `123456`)
*(Trên màn hình Đăng nhập có sẵn 3 nút bấm chuyển nhanh Role ở phía dưới)*:

| Phân quyền (Role) | Email đăng nhập | Tính năng nổi bật |
|---|---|---|
| **Khách hàng (`USER`)** | `user@barbersmart.vn` | Đặt lịch 2 ca chặn tràn giờ, Hủy lịch, Bản đồ OSM, Đăng ký quán SePay 100k, MXH |
| **Quản lý quán (`MANAGER`)** | `manager@barbersmart.vn` | Nút nổi `Quản lý`, Mua gói Nổi bật SePay, Mời Barber qua Email/SĐT, Doanh thu & Lương |
| **Thợ cắt (`BARBER`)** | `barber@barbersmart.vn` | Nút nổi `Lịch`, Heatmap tháng, Nút `"Xác nhận đã thanh toán"`, Group Chat, Thu nhập 10% |

