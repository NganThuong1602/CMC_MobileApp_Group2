# ✂️ BARBERSMART - ỨNG DỤNG ĐẶT LỊCH CẮT TÓC (FULLSTACK NESTJS & FLUTTER)

Dự án **BarberSmart** được xây dựng theo kiến trúc Monorepo gồm 2 phần tách biệt:
- `backend/`: **NestJS** (RESTful API + **Socket.IO** WebSocket), **PostgreSQL (Supabase)** với **TypeORM**, **Nodemailer** (Gmail OTP 6 số), **Cloudinary** (lưu trữ tối đa 5 ảnh/bài), **Firebase Cloud Messaging (FCM)**, và **SePay Webhook + VietQR động**.
- `mobile/`: **Flutter** theo **Clean Architecture** (`core`, `domain`, `data`, `presentation`), quản lý state bằng `flutter_bloc`, DI bằng `get_it`, HTTP bằng `dio`, điều hướng bằng `go_router`, bản đồ **OpenStreetMap (`flutter_map`)** và giao diện chuẩn Pixel-perfect tông xanh `#00A859`.

---

## 🚀 Hướng dẫn chạy dự án

### 1. Chạy Backend (`backend/`)
```bash
cd backend
cp .env.example .env
# Điền thông tin DATABASE_URL (Supabase), SMTP Gmail, Cloudinary, SePay vào .env
npm install
npm run start:dev
```
Server khởi chạy mặc định tại `http://localhost:3000/api/v1` và WebSocket namespace `/realtime`.

### 2. Chạy Mobile App (`mobile/`)
```bash
cd mobile
flutter pub get
flutter test
flutter run
```
> **Lưu ý tiện lợi:** Tầng Data của `mobile/` được thiết kế theo cơ chế **Hybrid (Remote NestJS API + Seeded Local Fallback)**. Bạn có thể bấm `flutter run` để trải nghiệm ngay toàn bộ 10 màn hình, 3 phân quyền (User / Manager / Barber), đặt lịch chặn tràn giờ và giả lập SePay Webhook ngay cả khi chưa bật server Backend!
