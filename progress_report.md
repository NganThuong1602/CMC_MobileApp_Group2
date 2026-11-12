# BÁO CÁO TIẾN ĐỘ DỰ ÁN: BARBERSMART (FULLSTACK NESTJS + SUPABASE + FLUTTER)

> **Cập nhật lần cuối:** 12/11/2026 (Bản cập nhật v4.0: Đổi "Nổi bật" -> "Diễn đàn" lọc bài đăng Barber từ `joinedAt`; Luồng Đăng ký quán mới 4 Gói Thành viên/Hợp tác -> Thanh toán QR SePay -> Điền form -> Admin duyệt & Gia hạn/Tự động xoá; Admin thêm Mã giảm giá tự động áp cho quán Hợp tác & xem chi tiết hồ sơ + bản đồ; Ưu tiên quán Nổi bật + Filter Trang chủ; Đánh giá sao thực tế ẩn khi 0 đánh giá; Xếp lịch tự động theo Ca sáng/Ca chiều + fix `ListTile` Web; Định vị GPS thời gian thực)  
> **Trạng thái tổng thể:** Đã hoàn thiện 100% mã nguồn Fullstack (`backend/` NestJS + Supabase PostgreSQL IPv4 Session Pooler + TypeORM + Socket.IO + SePay + Nodemailer + Cloudinary + FCM) và Mobile App (`mobile/` Flutter Clean Architecture + Centralized Design System `AppTheme` + `google_fonts` Inter + `flutter_bloc` + `get_it` + `dio` + `go_router` + `image_picker` + `geolocator` + `flutter_map` OSM), vượt qua toàn bộ kiểm tra `nest build` và `dart analyze` (`No issues found!`).

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

### 7. Bản cập nhật v3.2 — Chuẩn hóa Design System (`AppTheme` + Font `Inter`) & Fix 3 Lỗi Giao Diện / Nghiệp Vụ
- **Chuẩn hóa & Quản lý tập trung Màu sắc và Font chữ (`mobile/lib/core/theme/app_theme.dart`):**
  - Cài đặt `google_fonts: ^6.2.1` trong `mobile/pubspec.yaml` và thiết lập font mặc định toàn cục là **`Inter`** (`GoogleFonts.interTextTheme()`).
  - Gom toàn bộ bảng màu vào `ColorScheme` (Material 3) kết hợp `AppColorsExtension` (`ThemeExtension`) và hệ thống kiểu chữ ngữ nghĩa `AppTextStyles` + `ThemeContextX` (`context.colorScheme`, `context.appColors`, `context.appTextStyles`) trong duy nhất 1 file `mobile/lib/core/theme/app_theme.dart`.
  - Refactor toàn bộ **19 file màn hình & widget** trong `mobile/lib/presentation/` để xoá sạch 100% các mã màu hard-code (`Color(0x...)`, `Colors.*`) và `TextStyle(...)` cục bộ.
- **Fix 1 — Trang cá nhân & Bài đăng riêng biệt theo từng tài khoản + Menu 3 chấm Sửa/Xoá bài đăng:**
  - Cập nhật Backend (`community.module.ts`, `seeder.module.ts`) và Mobile (`profile_social_page.dart`, `social_repository_impl.dart`, `app_router.dart`) để mỗi tài khoản (`USER`, `MANAGER`, `BARBER`) có trang cá nhân riêng chỉ hiển thị bài đăng của chính tài khoản đó (`getFeedPosts(authorId: targetId)`), kèm nút **3 chấm (`PopupMenuButton`)** ở góc trên bên phải mỗi bài đăng cho phép **Chỉnh sửa bài đăng** (`PATCH /api/v1/posts/:postId`) và **Xoá bài đăng** (`DELETE /api/v1/posts/:postId`). Hỗ trợ xem trang cá nhân của người khác qua `/profile-social?userId=...`.
- **Fix 2 — Tách mục `Quản lý dịch vụ` riêng trên trang Quản lý (`MyShopPage`):**
  - Bổ sung dòng menu **`Quản lý dịch vụ`** trên màn Quản lý quán (`my_shop_page.dart`) và chuyển toàn bộ phần `Danh sách dịch vụ` (Thêm dịch vụ, Chỉnh sửa dịch vụ `PATCH /api/v1/shops/services/:serviceId`, Xoá dịch vụ) từ `Quản lý thông tin` sang màn hình riêng `_ManageShopServicesScreen`.
- **Fix 3 — Khắc phục lỗi khoảng trống dưới thanh điều hướng đáy (`RoleBottomNavBar`):**
  - Chuẩn hoá `MediaQuery` bottom padding trên Web tại `mobile/lib/app.dart`, `mobile/web/index.html`, `mobile/lib/presentation/pages/main/main_shell_page.dart` và `mobile/lib/presentation/widgets/role_bottom_nav_bar.dart` để thanh điều hướng luôn bám sát mép dưới màn hình.
- **Khôi phục `.env` & Kết nối Supabase IPv4 Session Pooler:**
  - Cập nhật `DATABASE_URL` trong `backend/.env` sang cổng **Supabase Session Pooler IPv4** (`aws-0-ap-southeast-1.pooler.supabase.com:5432`) khắc phục triệt để lỗi `ENOTFOUND` / `ETIMEDOUT` IPv6 trên Windows.

### 8. Bản cập nhật v3.3 — 7 Nâng cấp Nghiệp vụ Quản lý, Chat với Quán, Thông báo thật, Inline Validation & Role Admin
- **1. Tách riêng mục `Quản lý dịch vụ` nằm ngay dưới `Quản lý thông tin` (`my_shop_page.dart`):**
  - Đưa toàn bộ danh sách dịch vụ ra khỏi màn `Quản lý thông tin & Nổi bật` sang màn hình riêng `_ManageShopServicesScreen` mở từ dòng **`Quản lý dịch vụ`** nằm ngay dưới `Quản lý thông tin`. Hỗ trợ đầy đủ **Thêm dịch vụ mới**, **Sửa dịch vụ** (`PATCH /api/v1/shops/services/:serviceId`) và **Xoá dịch vụ** (`DELETE /api/v1/shops/services/:serviceId`).
- **2. Thêm chức năng `Xoá Barber` trong `Quản lý Barber` (`barbers.module.ts` & `my_shop_page.dart`):**
  - Bổ sung endpoint `DELETE /api/v1/barbers/:id` (xoá Barber khỏi quán, đưa `role` về `USER` nếu không còn thuộc quán nào và gửi thông báo thật cho Barber) kèm nút **Xoá Barber** (`Icons.delete_outline_rounded`) và hộp thoại xác nhận trên từng dòng Barber.
- **3. Làm mờ & Khoá nút `Đăng ký quán` đối với Role Quản lý (`account_page.dart`):**
  - Làm mờ (`Opacity(opacity: 0.45)`) và vô hiệu hoá mục `Đăng ký quán` khi tài khoản đang là `MANAGER` (mỗi quản lý chỉ quản lý 1 quán), `ADMIN`, `BARBER` hoặc đang có hồ sơ quán ở trạng thái `"Chờ duyệt"`.
- **4. Đổi `Chat với barber` thành `Chat với quán` & Chuyển `Tư vấn khách hàng` từ Barber sang Manager + Thông báo thật (`community.module.ts`, `shop_detail_bottom_sheet.dart`, `barber_hub_page.dart`, `my_shop_page.dart`):**
  - Đổi nút trên chi tiết quán thành **`Chat với quán`** (trò chuyện trực tiếp với Chủ quán/Quản lý).
  - Bỏ mục `Tư vấn khách hàng` khỏi trang `Lịch` của role `BARBER` và chuyển sang trang `Quản lý` của role `MANAGER` (`GET /api/v1/chat/manager/rooms`).
  - Khi khách hàng nhắn tin cho quán (`POST /api/v1/chat/rooms/:roomId/messages`), hệ thống lưu thông báo thật (`NotificationType.CHAT_MESSAGE`) vào bảng `notifications` gửi về mục **Thông báo** của Quản lý quán (`shop.ownerId`), và khi Quản lý mời/thêm Barber (`POST /api/v1/barbers/invite`), Barber nhận được thông báo thật (`BARBER_INVITE`). Đã đồng bộ parser `RemoteApiDataSource.getMyNotifications()` đọc chuẩn `{ unreadCount, items }`.
- **5. Hiển thị thông báo Validate trực tiếp ngay dưới từng ô nhập liệu (`errorText`):**
  - Toàn bộ các ô nhập liệu trong `auth_page.dart` (Đăng nhập, Đăng ký, Quên mật khẩu, OTP), `register_shop_page.dart` (Đăng ký mở quán), `my_shop_page.dart` (Quản lý thông tin, Thêm/Sửa dịch vụ, Mời Barber, Sửa lương Barber), `shop_detail_bottom_sheet.dart` (Đánh giá quán), `group_chat_page.dart` (Chat với quán) và `profile_social_page.dart` (Sửa hồ sơ, Đăng/Sửa bài viết, Bình luận) đều hiển thị nội dung lỗi cụ thể ngay bên dưới ô nhập thông qua `InputDecoration.errorText`.
- **6. Thêm Role `ADMIN` + Tài khoản `admin@barbersmart.vn` + Duyệt mở quán (`Chờ duyệt`) & Xoá quán:**
  - Bổ sung `UserRole.ADMIN` trên cả Backend và Mobile, seed tài khoản **`admin@barbersmart.vn`** / mật khẩu **`123456`**.
  - Thanh điều hướng dưới cùng (`RoleBottomNavBar`) hiển thị nút nổi bật ở giữa là **`Admin`** (`Icons.admin_panel_settings_rounded`) dẫn tới `AdminHubPage` gồm 2 mục:
    - **Duyệt mở quán (Chờ duyệt):** Khi người dùng hoàn tất bước thanh toán QR 100.000đ đăng ký quán, quán được tạo ở trạng thái `isActive = false` (**"Chờ duyệt"**) và gửi thông báo thật cho Admin. Khi Admin bấm **Duyệt mở quán** (`PATCH /api/v1/shops/:id/approve`), quán chính thức kích hoạt (`isActive = true`), tài khoản chủ quán được nâng lên `MANAGER` và nhận thông báo duyệt thành công.
    - **Quản lý danh sách quán:** Cho phép Admin xem toàn bộ các quán đang hoạt động trên hệ thống và **Xoá quán** bất kỳ (`DELETE /api/v1/shops/:id/admin`, tự động hạ role chủ quán về `USER` và gửi thông báo).

### 9. Bản cập nhật v3.4 — Điều hướng Thông báo Chat, Lưu Session khi Reload, Căn chỉnh Ảnh (Crop/Zoom/Pan), Huy hiệu Icon theo Role & Fix Overflow 11px
- **1. Bấm vào thông báo tin nhắn mới của Manager mở thẳng `Tư vấn khách hàng` và vào đúng cuộc trò chuyện (`notifications_page.dart`, `app_router.dart`, `main_shell_page.dart`, `my_shop_page.dart`, `group_chat_page.dart`):**
  - Khi Manager bấm vào thông báo có tin nhắn mới từ khách hàng, ứng dụng tự động đánh dấu đã đọc, chuyển về tab **`Quản lý` (`tab=2`)**, mở màn hình **`Tư vấn khách hàng` (`_ManagerChatListScreen`)** và đẩy thẳng vào đúng phòng trò chuyện đó (`/chat/:roomId`). Khi bấm nút Quay lại từ phòng chat sẽ lùi về đúng danh sách `Tư vấn khách hàng`.
- **2. Lưu Session đăng nhập (`SessionStorageService`) giữ nguyên tài khoản khi Reload trình duyệt (F5) (`session_storage_service.dart`, `auth_repository_impl.dart`, `auth_cubit.dart`, `injection_container.dart`):**
  - Lưu bền vững `accessToken` và thông tin `UserEntity` vào `window.localStorage` (trên Web) và File JSON hệ thống (trên Mobile/Desktop). Khi bấm Reload (F5), ứng dụng khôi phục đồng bộ phiên đăng nhập ngay trước khi khởi tạo `GoRouter`, giữ nguyên trạng thái đăng nhập và tự động làm mới dữ liệu user từ Supabase ngầm. Chỉ khi người dùng chủ động bấm **`Đăng xuất`** thì session mới bị xoá.
- **3. Thêm bước Căn chỉnh ảnh (Crop & Pan/Zoom) sau khi chọn ảnh (`image_picker_widgets.dart`, `remote_api_datasource.dart`):**
  - Tích hợp hộp thoại `_ImageCropAdjustDialog` ngay sau khi chọn ảnh từ Thư viện / Camera:
    - **Avatar (`isCircularPreview == true`):** Khung cắt hình **Ô vuông (1:1)** kèm vòng tròn dẫn hướng.
    - **Background / Ảnh bìa (`isCircularPreview == false`):** Khung cắt **Hình chữ nhật ngang (16:9)** chuẩn mobile app.
    - Hỗ trợ kéo ảnh trực tiếp **Trái / Phải / Lên / Xuống**, phóng to / thu nhỏ bằng cảm ứng hoặc thanh trượt **Zoom (`0.8x` – `4.0x`)** và bộ nút điều hướng tinh chỉnh trước khi trích xuất ảnh PNG tải lên Cloudinary.
- **4. Huy hiệu Icon đại diện riêng cho từng Role ở góc Avatar & trên Trang cá nhân (`app_theme.dart`, `account_page.dart`, `profile_social_page.dart`, `shop_detail_bottom_sheet.dart`):**
  - Thiết lập `UserRoleBadgeX.roleIcon` với biểu tượng riêng cho từng vai trò:
    - `USER` (Khách hàng): `Icons.person_rounded`
    - `BARBER` (Thợ cắt tóc): `Icons.content_cut_rounded` (Cây kéo)
    - `MANAGER` (Quản lý quán): `Icons.storefront_rounded` (Cửa tiệm)
    - `ADMIN` (Quản trị viên): `Icons.admin_panel_settings_rounded` (Khiên Admin)
  - Hiển thị huy hiệu icon này ở góc dưới bên phải Avatar tại trang `Hồ Sơ` (`AccountPage`) và `Trang cá nhân` (`ProfileSocialPage`), đồng thời thay thế chữ `"Barber"` cạnh tên trên trang cá nhân & bài đăng bằng huy hiệu icon của role đó.
- **5. Khắc phục triệt để lỗi tràn ngang `RIGHT OVERFLOWED BY 11 PIXELS` (`admin_hub_page.dart`, `my_shop_page.dart`):**
  - Chuyển `Row` thống kê trên thẻ banner của `AdminHubPage` và `MyShopPage` sang `Wrap(spacing: 12, runSpacing: 4, ...)` để tự động xuống dòng mượt mà trên mọi kích thước màn hình nhỏ mà không bao giờ báo lỗi tràn pixel.

### 10. Bản cập nhật v3.5 — Tối giản Hộp thoại Crop Ảnh, Chọn & Chỉnh Vị trí Quán trên Bản đồ OSM, Ảnh QR SePay Thật, Trang Trạng thái Đăng ký Quán & Trang Chi tiết Lời mời Barber
- **1. Tối giản hộp thoại Căn chỉnh ảnh (`_ImageCropAdjustDialog` trong `image_picker_widgets.dart`):**
  - Xoá bỏ 4 nút điều hướng `Trái`, `Phải`, `Lên`, `Xuống` và đoạn hướng dẫn dài dòng phía trên khung lưới (vì người dùng kéo trực tiếp trong khung lưới).
  - Giữ lại thanh thu phóng (`-`, `Slider`, `+`) kèm **icon Đặt lại (`Icons.refresh_rounded`)** ngay cạnh và nút **`Xác nhận`** ngắn gọn.
- **2. Định vị Địa chỉ & Chỉnh Vị trí Quán trực tiếp trên Bản đồ khi Đăng ký quán + Hiển thị rõ Marker Vị trí của bạn (`location_service.dart`, `register_shop_page.dart`, `map_page.dart`, `shop_discovery_cubit.dart`):**
  - Tích hợp `LocationService.geocodeAddress()` gọi OpenStreetMap Nominatim API (kèm thuật toán bóc tách số nhà/ngõ thông minh để định vị chuẩn xác tên Phố/Phường/Quận tại Hà Đông & Hà Nội).
  - Ngay dưới ô nhập địa chỉ trong `RegisterShopPage`, tích hợp khung **Bản đồ tương tác `FlutterMap`**: tự động nhảy tới vị trí địa chỉ vừa nhập và cho phép người dùng **chạm trực tiếp lên bản đồ** để tinh chỉnh chính xác tọa độ quán (`latitude`, `longitude`) trước khi gửi duyệt.
  - Nâng cấp Marker vị trí của người dùng trên cả `MapPage` lẫn `RegisterShopPage` từ dấu chấm tròn đơn điệu thành **Marker Pin `"Vị trí của bạn"` (`Icons.person_pin_circle_rounded` + nhãn `"Vị trí của bạn"`)** rõ ràng và tự động lấy GPS thực tế ngay khi mở Bản đồ.
- **3. Hiển thị Ảnh Mã QR SePay Thật để quét thanh toán (`payments.module.ts`, `in_memory_database.dart`, `sepay_qr_dialog.dart`):**
  - Khắc phục lỗi `img.vietqr.io` trả về định dạng `image/svg+xml` khiến `Image.network` của Flutter Web rơi vào `errorBuilder`. Chuyển toàn bộ hàm tạo URL mã QR sang endpoint PNG chính thức của SePay (`https://qr.sepay.vn/img?bank=ICB&acc=101886339075&template=compact&amount=...&des=...`), hiển thị trực tiếp ảnh mã QR thật của tài khoản người dùng trên hộp thoại thanh toán.
- **4. Trang Trạng thái Hồ sơ Đăng ký Quán ("Đang chờ duyệt" / "Đã duyệt") & Xem lại thông tin quán đã điền (`account_page.dart`, `register_shop_page.dart`):**
  - Sau khi đăng ký quán và thanh toán xong (chuyển sang trạng thái `"Chờ duyệt"`) hoặc khi quán đã được duyệt (`"Đã duyệt"`, áp dụng cho cả Role `MANAGER`), mục **`Đăng ký quán`** tại trang `Hồ Sơ` sẽ hiển thị huy hiệu trạng thái (`Chờ duyệt` / `Đã duyệt`) và khi bấm vào sẽ mở **Trang Trạng thái Đăng ký Quán** (không hiện form nhập mới nữa).
  - Khi bấm vào thẻ trạng thái quán, màn hình mở rộng hiển thị đầy đủ **toàn bộ thông tin quán mà người dùng đã điền** (Ảnh bìa quán, Tên quán, Địa chỉ, Bản đồ vị trí quán, Số điện thoại, Giờ mở cửa - đóng cửa, Giới thiệu quán).
- **5. Mở Trang Chi tiết Lời mời làm Barber khi bấm vào Thông báo lời mời (`notifications_page.dart`, `social_entities.dart`, `barber_repository_impl.dart`):**
  - Sửa lỗi mất nút `Đồng ý` / `Từ chối` khi bấm xem thông báo (`isRead == true`). Giờ đây nút phản hồi chỉ ẩn khi người dùng thực sự đã phản hồi (`responded == true`), và khi bấm vào thông báo lời mời làm Barber sẽ mở sang **Trang Chi tiết Lời mời làm Barber (`_BarberInvitationDetailPage`)** có đầy đủ thông tin đãi ngộ kèm 2 nút **`Xác nhận`** và **`Từ chối`**.

### 11. Bản cập nhật v3.6 — Giữ Trạng thái & Thông tin Đăng ký Quán khi thoát ra vào lại, Thông báo thật & Danh sách Duyệt mở quán cho Admin, và Chuẩn hoá Validate SĐT 28 đầu số Việt Nam
- **1. Giữ nguyên trạng thái và thông tin đăng ký quán khi thoát ra vào lại (`payments.module.ts`, `shop_repository_impl.dart`, `register_shop_page.dart`, `account_page.dart`):**
  - Khắc phục lỗi `POST /api/v1/payments/sepay-webhook` trả về `401 Unauthorized` khi bấm `"Giả lập SePay bắn Webhook thành công"` trên App (do gửi `Bearer` token thay vì `Apikey`) và đồng bộ `getShopByOwnerId` trực tiếp từ Supabase (`GET /api/v1/shops/me/owned`).
  - Sau khi đăng ký quán xong, dù người dùng thoát ra vào lại hay F5 tải lại trang, mục **`Đăng ký quán`** luôn chỉ hiển thị **Trạng thái (`ĐANG CHỜ DUYỆT` / `ĐÃ DUYỆT`) kèm toàn bộ thông tin quán đã đăng ký** (`_showSubmittedDetails = true` mặc định).
  - Chỉ khi **Admin từ chối** (`DELETE /api/v1/shops/:id/admin`), hệ thống mới gửi thông báo bị từ chối cho người dùng, xoá hồ sơ quán chờ duyệt và mở lại form đăng ký quán như bình thường.
- **2. Thông báo thật cho Role `ADMIN` & Hiển thị ngay trong mục `Duyệt mở quán (Chờ duyệt)` (`payments.module.ts`, `admin_hub_page.dart`, `main_shell_page.dart`):**
  - Khi bất kỳ tài khoản nào hoàn tất thanh toán phí đăng ký mở quán, `PaymentsService.handleSepayWebhook` khởi tạo quán với `isActive: false` trong bảng `shops`, gửi thông báo thật (`NotificationType.SHOP_APPROVAL`: *"Yêu cầu duyệt mở quán mới"*) tới toàn bộ tài khoản `ADMIN` (`admin@barbersmart.vn`) và tự động làm mới danh sách **`Duyệt mở quán (Chờ duyệt)`** trên `AdminHubPage` (kể cả tự động khôi phục giao dịch `PAYSHOP792827` bạn vừa gửi trước đó).
- **3. Chuẩn hoá Validate Số điện thoại 10 chữ số theo 28 đầu số Việt Nam (`formatters.dart`, `auth_page.dart`, `register_shop_page.dart`, `my_shop_page.dart`, `auth_repository_impl.dart`, `auth.module.ts`, `payments.module.ts`, `shops.module.ts`):**
  - Thiết lập hàm dùng chung `AppFormatters.validateVietnamPhone` và `VN_PHONE_REGEX` bắt buộc 3 chữ số đầu phải thuộc 28 đầu số: `032, 033, 034, 035, 036, 037, 038, 039, 086, 096, 097, 098, 081, 082, 083, 084, 085, 088, 091, 094, 070, 076, 077, 078, 079, 089, 090, 093` và độ dài đúng **10 chữ số**.
  - Nếu nhập sai ở bất kỳ ô số điện thoại nào đều hiển thị thông báo **`"số điện thoại không đúng"`** ngay dưới ô nhập liệu.
- **4. Tự động giải phóng cổng `3000` chống lỗi `EADDRINUSE` khi khởi động / reload Backend (`backend/src/main.ts`):**
  - Bổ sung `freePortIfInUse(port)` + `listenWithRetry(app, port)` và `app.enableShutdownHooks()` trong `backend/src/main.ts`. Khi chạy lại Backend hoặc khi chế độ watch tự động khởi động lại mà tiến trình cũ vẫn đang chiếm cổng `3000`, hệ thống sẽ tự động thu hồi tiến trình cũ trên cổng `3000` và khởi chạy mượt mà (`HTTP 200 OK`).
- **5. Tối giản hóa UI chuẩn Mobile App Thực tế (Xoá bỏ các dòng chữ hướng dẫn rườm rà):**
  - Xoá hoàn toàn dòng chữ màu xanh *"Chạm vào ảnh để mở Trang cá nhân & Mạng xã hội"* dưới thông tin tài khoản trên trang `Hồ Sơ` (`AccountPage`).
  - Rút gọn các dòng subtitle và nhãn hướng dẫn thừa như *"• Bấm để xem chi tiết"*, *"• Bấm để xem trạng thái & thông tin đã đăng ký"*, *"(Chạm vào bản đồ để chỉnh)"*, *"(Chạm để xác nhận TT)"*, *"Bấm để xem thông tin quán bạn đã điền"* thành văn bản tự nhiên, tinh gọn và chuyên nghiệp chuẩn các ứng dụng di động hàng đầu hiện nay.

### 12. Bản cập nhật v4.0 — Diễn đàn Barber, Luồng Đăng ký Gói Quán -> QR SePay -> Điền Form -> Admin Duyệt/Gia hạn, Mã giảm giá Admin, Đánh giá sao thực tế, Xếp lịch theo Ca tự động & Định vị GPS thời gian thực
- **1. Đổi trang "Nổi bật" thành "Diễn đàn" (`highlights_page.dart`, `role_bottom_nav_bar.dart`, `main_shell_page.dart`, `community.module.ts`, `barbers.module.ts`, `seeder.module.ts`):**
  - Đổi tên tab điều hướng thành **`Diễn đàn`** (`Icons.forum_outlined` / `Icons.forum_rounded`).
  - Endpoint `GET /api/v1/posts/forum` và `GetForumPostsUseCase` chỉ lấy các bài đăng của tài khoản đang giữ vai trò **`BARBER`**, với điều kiện `post.createdAt >= barber.joinedAt`, sắp xếp từ mới nhất đến cũ nhất (`DESC`). Khi một người dùng đăng bài trước khi trở thành Barber, bài cũ không xuất hiện ở Diễn đàn (chỉ hiện các bài đăng từ thời điểm trở thành Barber trở đi).
- **2. Luồng Đăng ký Quán 3 bước mới (Chọn 1 trong 4 Gói -> Thanh toán QR SePay -> Điền Form -> Chờ Admin duyệt), Gia hạn & Tự động gỡ quán hết hạn (`register_shop_page.dart`, `my_shop_page.dart`, `payments.module.ts`, `shops.module.ts`, `app_enums.dart`):**
  - Thiết lập 4 gói `ShopPackagePlan`: **Thành viên 1 tháng (`500.000đ`)**, **Thành viên 1 năm (`5.000.000đ`)**, **Hợp tác 1 tháng (`300.000đ`)**, **Hợp tác 1 năm (`3.000.000đ`)** kèm bảng quyền lợi rõ ràng.
  - Bước 1 chọn gói & quét QR SePay thanh toán trước (`POST /api/v1/payments/register-shop-qr`). Thanh toán xong mở khoá Bước 2 (`GET /api/v1/payments/register-shop-credit`) để điền thông tin quán và bấm **Xác nhận & Gửi duyệt mở quán** (`POST /api/v1/shops/register-after-payment`), chuyển sang Bước 3 (**Chờ duyệt / Đã duyệt**).
  - Bỏ nút mua Nổi bật `1h/1d/3d` cũ trong `Quản lý thông tin` của Manager; thay bằng thẻ **Trạng thái gói quán hiện tại**, cảnh báo khi còn `<= 7 ngày` hết hạn, và danh sách **Gia hạn gói quán qua SePay** (`POST /api/v1/payments/renew-shop-qr`). Backend tự động gửi thông báo nhắc gia hạn và tự động gỡ quán quá hạn chưa gia hạn.
- **3. Quản trị Admin: "Thêm mã giảm giá" tự động áp dụng cho Gói Hợp tác & Xem đầy đủ Hồ sơ quán chờ duyệt (`admin_hub_page.dart`, `discounts.module.ts`, `shops.module.ts`):**
  - Thêm mục **`Thêm mã giảm giá`** trong `AdminHubPage` (`GET /api/v1/discounts`, `POST /api/v1/discounts/admin`, `DELETE /api/v1/discounts/:id`) với validate inline (`errorText`) và bộ chọn ngày/giờ bắt đầu – kết thúc. Chương trình giảm giá đang hiệu lực tự động áp dụng cho toàn bộ quán dùng **Gói Hợp tác** (hiển thị badge `-X%` & giá gạch ngang trên Trang chủ, Chi tiết quán, và tính trực tiếp khi Đặt lịch).
  - Nâng cấp danh sách **Duyệt mở quán (Chờ duyệt)** cho phép bấm vào hồ sơ để mở trang/sheet chi tiết đầy đủ toàn bộ thông tin đã nhập: ảnh bìa lớn, tên, địa chỉ, bản đồ OSM với pin vị trí, số điện thoại, giờ mở/đóng cửa, mô tả, tên gói, thông tin thanh toán SePay và tài khoản người đăng ký.
- **4. Ưu tiên Quán Nổi bật ở đầu Trang chủ & Bộ lọc Nổi bật (`home_page.dart`, `map_page.dart`, `shop_filter_bottom_sheet.dart`, `shop_discovery_cubit.dart`):**
  - Quán Gói Hợp tác / Nổi bật luôn được xếp ưu tiên lên đầu danh sách Trang chủ, gắn badge `Nổi bật` và badge `Giảm X%`.
  - Bổ sung thanh chọn nhanh **`Tất cả` / `Nổi bật`** trên Trang chủ và tuỳ chọn **`Chỉ hiện quán Nổi bật (Gói Hợp tác)`** trong `ShopFilterBottomSheet` (`GET /api/v1/shops/nearby?onlyHighlighted=true`).
- **5. Đánh giá sao trung bình thực tế từ khách hàng (`shops.module.ts`, `community.module.ts`, `shop_entity.dart`, `home_page.dart`, `shop_detail_bottom_sheet.dart`, `admin_hub_page.dart`):**
  - Đồng bộ tính điểm trung bình thực tế từ bảng `reviews` (`reviewCount == 0` -> `rating = 0`). Quán mới hoặc quán có `0` đánh giá sẽ ẩn hoàn toàn biểu tượng ngôi sao trên thẻ và tiêu đề quán (`shop.hasRating`).
- **6. Đặt lịch tự động theo Ca sáng / Ca chiều (`BookingShift`) & Fix lỗi Web `ListTile` (`booking_flow_page.dart`, `booking_bloc.dart`, `booking_slot_calculator.dart`, `bookings.module.ts`):**
  - Thay lưới giờ 15 phút bằng giao diện chọn **`Ca sáng`** (`giờ mở cửa -> 12:00`) và **`Ca chiều`** (`13:30 -> giờ đóng cửa`). Hệ thống tự động xếp khung giờ phục vụ cho từng khách và cộng khoảng nghỉ **5 phút** sau khách trước (hết chỗ trước giờ đóng ca sẽ khoá ca và báo lý do).
  - Bọc `CheckboxListTile` / `ListTile` bằng `Material` đúng chuẩn Material Design để loại bỏ hoàn toàn cảnh báo console trên Flutter Web.
- **7. Định vị GPS di chuyển theo thời gian thực (`location_service.dart`, `shop_discovery_cubit.dart`, `map_page.dart`):**
  - Bổ sung stream cập nhật vị trí liên tục (`Geolocator.getPositionStream`) giúp chấm xanh pin **`"Vị trí của bạn"`** tự động di chuyển và cập nhật khoảng cách trên `MapPage` theo thời gian thực.

### 13. Bản cập nhật v4.1 — Tối giản Trang chủ & Bộ lọc, Chấm xanh GPS thật kiểu Google Maps & Diễn đàn hiện thêm bài đăng Manager
- **Trang chủ (`home_page.dart`):** Bỏ nút định vị cạnh nút Filter; bỏ dòng `Chỉ quán Nổi bật` + `Xoá lọc` khi chọn tab `Nổi bật` (tab Nổi bật không còn tính là bộ lọc — `ShopDiscoveryState.hasActiveFilter` chỉ gồm Đánh giá & Khoảng cách).
- **Bộ lọc (`shop_filter_bottom_sheet.dart`):** Bỏ công tắc `Chỉ hiện quán Nổi bật (Gói Hợp tác)`; `Xoá lọc` giữ nguyên tab `Tất cả`/`Nổi bật` đang chọn.
- **Vị trí GPS thật (`location_service.dart`, `shop_discovery_cubit.dart`, `map_page.dart`, `register_shop_page.dart`):**
  - Lấy toạ độ độ chính xác cao `LocationAccuracy.best`, trên Web dùng `WebSettings(maximumAge: Duration.zero)` để không dùng vị trí cache cũ, đồng thời ghi nhận `accuracyMeters` (`gpsAccuracyMeters`) để kiểm tra sai số khi bấm nút thông tin bản đồ.
  - Vị trí của bạn hiển thị bằng **chấm xanh dương viền trắng + quầng mờ** như Google Maps (bỏ pin & nhãn "Vị trí của bạn").
  - Tự động giám sát bật/tắt định vị mỗi 3 giây: **tắt định vị / thu hồi quyền → ẩn chấm xanh ngay**, bật lại → tự lấy lại GPS và hiện chấm xanh. Bản đồ chỉ tự căn giữa khi vừa có GPS lần đầu hoặc khi bấm nút định vị (không giật bản đồ mỗi lần cập nhật).
  - Xoá hàm `setCustomUserLocation` (đặt vị trí giả) để chấm xanh luôn là vị trí GPS thật.
- **Diễn đàn (`community.module.ts`, `social_repository_impl.dart`, `highlights_page.dart`):** Mở rộng `GET /api/v1/posts/forum` và fallback offline để hiển thị thêm toàn bộ bài đăng của tài khoản giữ vai trò **`MANAGER`** (gắn kèm tên quán quản lý `authorShopName` và huy hiệu cửa tiệm), song song với bài đăng của **`BARBER`** từ thời điểm `joinedAt`.
- **Header (`barbersmart_header.dart`):** Nút tròn góc trên bên phải của `BarberSmartHeader` tự động lấy `user.avatarUrl` từ `AuthCubit` (hoặc `AppConstants.defaultAvatarUrl` nếu tài khoản chưa tải ảnh, kèm fallback về icon user mặc định khi chưa đăng nhập hoặc tải ảnh lỗi) để hiển thị ảnh đại diện thật của tài khoản đang đăng nhập trên toàn bộ các tab chính.

---

## 🚧 Đang làm dở
- Không có mục nào đang làm dở. Toàn bộ các hạng mục đến **v4.1** đã hoàn thiện, vượt qua `nest build`, kiểm thử API trực tiếp với Supabase PostgreSQL (`GET /posts/forum` trả về cả `BARBER` và `MANAGER`) và `dart analyze` (`No issues found!`).

---

## ⏳ Chưa làm (Tuỳ chọn mở rộng khi phát hành Production lên CH Play / App Store)
1. Thay `ngrokDomain` trong `mobile/lib/core/constants/app_constants.dart` (hoặc truyền `--dart-define=API_HOST=https://api.tenmiencuaban.com` khi build APK/AAB release) khi chuyển Backend từ máy cá nhân lên VPS/Cloud cố định.
2. Thêm file cấu hình native `android/app/google-services.json` nếu muốn nhận Push Notification FCM khi đóng hẳn app trên máy Android vật lý.

---

## ⏭️ Lệnh tiếp theo
Ở lần làm việc tiếp theo (ví dụ kiểm thử thanh toán VietQR SePay thực tế, đóng gói file `.apk` / `.aab` đăng CH Play, hoặc tinh chỉnh thêm nghiệp vụ), bạn chỉ cần copy câu lệnh sau gửi lại cho tôi:

> **"Hãy đọc file `progress_report.md` và `project_prompt.md`, kiểm tra trạng thái kết nối hiện tại của dự án BarberSmart và hỗ trợ tôi kiểm thử luồng đặt lịch / thanh toán SePay hoặc đóng gói bản cài đặt Android APK."**
