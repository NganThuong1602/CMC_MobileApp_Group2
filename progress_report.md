# BÁO CÁO TIẾN ĐỘ DỰ ÁN: BARBERSMART (FULLSTACK NESTJS + SUPABASE + FLUTTER)

> **Cập nhật lần cuối:** 02/11/2026 (Bản cập nhật v3: Fix Logout Blank Screen, Tích hợp `image_picker` + Cloudinary, GPS thật `geolocator` + OSM, và Auto-Seeding Supabase khu vực Vạn Phúc - Hà Đông)  
> **Trạng thái tổng thể:** Đã hoàn thiện 100% mã nguồn Fullstack (`backend/` NestJS + Supabase PostgreSQL + TypeORM + Socket.IO + SePay + Nodemailer + Cloudinary + FCM) và Mobile App (`mobile/` Flutter Clean Architecture + `flutter_bloc` + `get_it` + `dio` + `go_router` + `image_picker` + `geolocator` + `flutter_map` OSM), vượt qua toàn bộ kiểm tra `nest build`, `flutter analyze` (`No issues found!`) và `flutter test`.

---

## ✅ Đã xong

### 1. Khởi tạo & Cập nhật Workspace
- `project_prompt.md`: Lưu trữ đầy đủ toàn bộ đặc tả gốc + đặc tả cập nhật v3 (Fix Bug Logout, Upload ảnh `image_picker` -> Cloudinary -> Supabase, Vị trí GPS thực tế `geolocator` -> `flutter_map` OSM, và Database Seeding khu vực Vạn Phúc - Hà Đông).
- `progress_report.md`: Theo dõi tiến độ chi tiết từng hạng mục.

### 2. Yêu cầu 1 — Fix Lỗi Trắng Màn Hình Khi Đăng Xuất (Logout Blank Screen Bug)
- `mobile/lib/presentation/blocs/auth/auth_cubit.dart`: Bổ sung `AuthStatus.unauthenticated` / `AuthStatus.authenticated`. Hàm `logout()` xoá sạch JWT Token & đóng kết nối Socket qua `AuthRepositoryImpl.logout()`, sau đó emit `const AuthState(status: AuthStatus.unauthenticated)` ngay lập tức.
- `mobile/lib/presentation/routes/app_router.dart`: Tích hợp `GoRouterRefreshStream(authCubit.stream)`, đặt route chuẩn `/login` (kèm redirect `/auth` -> `/login`), tự động lắng nghe state `unauthenticated` để redirect thẳng về `/login` (tuyệt đối không gọi `Navigator.pop()` gây văng khỏi stack).
- `mobile/lib/presentation/pages/main/main_shell_page.dart`, `account_page.dart`, `profile_social_page.dart`: Loại bỏ hoàn toàn `SizedBox.shrink()` khi `user == null`, thay bằng loading an toàn kèm fallback `context.go('/login')`.

### 3. Yêu cầu 2 — Xử Lý Hình Ảnh & Upload (`image_picker` -> NestJS -> Cloudinary -> Supabase)
- `mobile/pubspec.yaml`, `AndroidManifest.xml`, `Info.plist`: Tích hợp `image_picker: ^1.1.2` và khai báo đầy đủ quyền Camera / Thư viện ảnh.
- `backend/src/modules/upload/upload.module.ts`: Chuẩn hoá `cloud_name: cloudName.trim().toLowerCase()` cho Cloudinary API, nhận tối đa 5 ảnh qua `POST /api/v1/upload/images` (`FilesInterceptor('files', 5)`).
- `mobile/lib/data/datasources/remote/remote_api_datasource.dart`: Cài đặt `uploadImages(List<XFile> files)` đọc bytes đa nền tảng (chạy mượt trên cả Chrome Web, Android và iOS) đẩy `multipart/form-data` lên `/upload/images`.
- `mobile/lib/presentation/widgets/image_picker_widgets.dart`: Xây dựng 2 widget tái sử dụng `SingleImagePickerField` và `MultiImagePickerField` cung cấp song song **2 lựa chọn**: **(1) Tải ảnh từ Thiết bị (Thư viện / Camera) lên Cloudinary** hoặc **(2) Nhập trực tiếp URL ảnh**, đã tích hợp vào toàn bộ các form:
  - **Đổi Avatar & Ảnh bìa (Cover)** trên Trang cá nhân (`profile_social_page.dart` -> lưu vào Supabase qua `PATCH /api/v1/auth/profile`).
  - **Đăng bài viết mới (tối đa 5 ảnh)** (`profile_social_page.dart` -> lưu vào Supabase qua `POST /api/v1/posts`).
  - **Đăng ký mở quán mới** (`register_shop_page.dart`) & **Quản lý thông tin / Bộ sưu tập ảnh quán** (`my_shop_page.dart`).

### 4. Yêu cầu 3 — Tích Hợp Vị Trí Thực Tế & Bản Đồ (`geolocator` + `flutter_map` OSM)
- `mobile/pubspec.yaml`, `AndroidManifest.xml`, `Info.plist`: Tích hợp `geolocator: ^13.0.1` kèm quyền `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`.
- `mobile/lib/core/services/location_service.dart` & `shop_discovery_cubit.dart`: Khi mở ứng dụng tại `HomePage`, tự động kích hoạt popup xin quyền GPS thực tế của hệ điều hành / trình duyệt (`requestRealDeviceLocation`), lấy `latitude` & `longitude` thật của thiết bị và tính khoảng cách thực tế (`km`) từ vị trí người dùng tới từng quán.
- `mobile/lib/presentation/pages/map/map_page.dart`: Tự động dịch chuyển tâm bản đồ `FlutterMap` (OpenStreetMap - OSM) về đúng toạ độ GPS thật của user (`_safeMoveMap` an toàn sau `onMapReady`), xoá bỏ text cứng `'Hồ Chí Minh, Việt Nam'`, và hiển thị **Tên quán + Khoảng cách thực tế (`km`)** ngay trên từng Marker của quán trên bản đồ.

### 5. Yêu cầu 4 — Tạo Dữ Liệu Mẫu (`onModuleInit` Seeder trên Supabase Khu Vực Vạn Phúc, Hà Đông)
- `backend/src/database/seeder.module.ts`, `backend/src/database/run-seed.ts`, `backend/src/app.module.ts`: Tự động kiểm tra và bơm dữ liệu mẫu vào **Supabase PostgreSQL** ngay khi Backend khởi động (`OnModuleInit`) hoặc qua lệnh `npm run seed` (idempotent, không tạo trùng lặp):
  - **5 Quán cắt tóc khu vực Vạn Phúc, Hà Đông, Hà Nội (`~20.976xxx, 105.772xxx`)**:
    1. `Vạn Phúc Barber House` (`20.9768, 105.7724`) — **Nổi bật (+100 ngày)**
    2. `The Gentlemen Hair Salon Hà Đông` (`20.9785, 105.7746`) — **Nổi bật (+100 ngày)**
    3. `30Shine Studio Vạn Phúc` (`20.9749, 105.7708`) — **Nổi bật (+100 ngày)**
    4. `Liem Barber Shop Hà Đông` (`20.9776, 105.7695`)
    5. `Classic Fade Club Vạn Phúc` (`20.9734, 105.7751`)
  - **5 tài khoản Chủ quán (`MANAGER`) thật** (`manager@barbersmart.vn`, `manager2..5@barbersmart.vn`, mật khẩu chung `123456`) — mỗi chủ sở hữu đúng 1 quán.
  - **19 tài khoản Thợ cắt tóc (`BARBER`) thật** (3–4 Barber/quán, mật khẩu chung `123456`, ví dụ `barber@barbersmart.vn`), 20 dịch vụ cắt/uốn/nhuộm, đánh giá sao và bài viết MXH mẫu với ảnh thật sắc nét.
  - **3 giao dịch `BUY_HIGHLIGHT` (`SUCCESS`)** lưu thật trong bảng `transactions` và `highlight_expires_at = NOW() + 100 days` để tab **"Nổi bật"** truy vấn trực tiếp từ Supabase.
  - **Avatar mặc định trong Database:** Cấu hình hằng số `DEFAULT_AVATAR_URL` (`https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y` — hình bóng người xám rỗng) tại `user.entity.ts` và `auth.module.ts` cho mọi tài khoản tạo mới chưa tải ảnh đại diện.

### 6. Bản cập nhật v3.1 — Fix TSConfig/Entities Đỏ, Nút Back sau Thanh toán, Reset Filter đổi Tab & Bộ lọc Khoảng cách 1–20km
- **Fix `tsconfig.json` & TypeORM Entities bị báo đỏ trên VS Code:**
  - Cập nhật `backend/tsconfig.json` (`strictPropertyInitialization: false`, `rootDir: "./src"`, `include: ["src/**/*.ts"]`), xoá file nháp cũ `seed.js`, cấu hình `.vscode/settings.json` trỏ tới `backend/node_modules/typescript/lib` và thêm toán tử `!` cho toàn bộ các thuộc tính trong `backend/src/database/entities/*.ts`, `auth.module.ts`, `realtime.module.ts` (đạt 0 lỗi kể cả ở chế độ `strictPropertyInitialization`).
- **Fix không có nút Back ở màn `Lịch đã đặt` (`/my-bookings`) sau khi Thanh toán + Fix tràn chữ ở màn 320px:**
  - Chuyển các route phụ (`my-bookings`, `booking/:shopId`, `notifications`, `register-shop`, `profile-social`, `chat/:roomId`) thành sub-routes trực thuộc `/` trong `app_router.dart`, đồng thời bổ sung nút Back an toàn (`context.canPop() ? context.pop() : context.go('/')`) + nút `Trang chủ` trên `AppBar` của `my_bookings_page.dart` và xử lý `Expanded + Wrap` chống tràn ngang 54px trên màn hẹp `320px`.
- **Tự động xoá Filter & Từ khoá khi chuyển qua lại giữa `Trang chủ` và `Bản đồ`:**
  - Bổ sung `resetAllSearchAndFiltersOnTabSwitch` trong `shop_discovery_cubit.dart` và kích hoạt tại `main_shell_page.dart` để khi chuyển từ Bản đồ về Trang chủ (hoặc ngược lại), toàn bộ ô tìm kiếm và bộ lọc cũ được dọn sạch tự động.
- **Bộ lọc dùng chung (`ShopFilterBottomSheet`) cạnh thanh tìm kiếm ở cả `Trang chủ` và `Bản đồ`:**
  - Xây dựng `mobile/lib/presentation/widgets/shop_filter_bottom_sheet.dart` đặt ngay cạnh thanh tìm kiếm trên cả `home_page.dart` lẫn `map_page.dart`, cho phép lọc kết hợp **Đánh giá sao** + **Thanh trượt Khoảng cách từ `1 km` đến `20 km`** (lọc từ `0 km` đến mức thanh trượt đang chọn) cùng 2 nút cuối bảng: **`Xoá lọc`** và **`Tìm kiếm`**.

---

## 🚧 Đang làm dở
- **Không có hạng mục nào dở dang.** Toàn bộ Backend và Mobile đã hoàn tất đồng bộ và vượt qua Self-Testing.

---

## ⏳ Chưa làm (Tuỳ chọn mở rộng khi phát hành Production lên CH Play / App Store)
1. Thay `ngrokDomain` trong `mobile/lib/core/constants/app_constants.dart` (hoặc truyền `--dart-define=API_HOST=https://api.tenmiencuaban.com` khi build APK/AAB release) khi chuyển Backend từ máy cá nhân lên VPS/Cloud cố định.
2. Thêm file cấu hình native `android/app/google-services.json` nếu muốn nhận Push Notification FCM khi đóng hẳn app trên máy Android vật lý.

---

## ⏭️ Lệnh tiếp theo
Ở lần làm việc tiếp theo (ví dụ kiểm thử thanh toán VietQR SePay thực tế, đóng gói file `.apk` / `.aab` đăng CH Play, hoặc tinh chỉnh thêm nghiệp vụ), bạn chỉ cần copy câu lệnh sau gửi lại cho tôi:

> **"Hãy đọc file `progress_report.md` và `project_prompt.md`, kiểm tra trạng thái kết nối hiện tại của dự án BarberSmart và hỗ trợ tôi kiểm thử luồng đặt lịch / thanh toán SePay hoặc đóng gói bản cài đặt Android APK."**
