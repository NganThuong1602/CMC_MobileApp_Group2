# YÊU CẦU DỰ ÁN: BARBERSMART - ỨNG DỤNG ĐẶT LỊCH CẮT TÓC (FULLSTACK & FLUTTER)
Tôi cần bạn đóng vai trò là một Senior Fullstack & Flutter Developer. Nhiệm vụ của bạn là xây dựng hoàn chỉnh toàn bộ dự án BarberSmart (từ Backend, Database đến Mobile App) dựa trên tài liệu yêu cầu và các hình ảnh UI Design đính kèm.

## 📌 QUY TRÌNH LÀM VIỆC & QUẢN LÝ TIẾN ĐỘ (DÀNH CHO AI ASSISTANT)
Dự án này rất lớn, chắc chắn sẽ vượt quá giới hạn token của một lần phản hồi. Bạn PHẢI tuân thủ nghiêm ngặt quy trình làm việc sau:

1. **Khởi tạo Workspace:** Tạo file `project_prompt.md` lưu toàn bộ nội dung này làm gốc. Tạo file `progress_report.md` để theo dõi tiến độ.
2. **Clarification First:** Nếu có bất kỳ logic nào bị thiếu hoặc mơ hồ, PHẢI HỎI LẠI tôi trước khi code. Không tự đoán logic.
3. **Cơ chế Checkpoint:** Khi sắp hết context window hoặc quota, bạn phải dừng ở state an toàn, không cắt dở code. Sau đó cập nhật `progress_report.md` với các mục:
   - ✅ Đã xong: (Tên file, chức năng).
   - 🚧 Đang làm dở: (Logic/UI chưa hoàn thiện).
   - ⏳ Chưa làm: (Các tính năng còn lại).
   - ⏭️ Lệnh tiếp theo: (Viết sẵn 1 câu prompt để tôi copy gửi lại cho bạn code tiếp ở lượt sau).
4. **Đọc hình ảnh (Vision):** Tôi đã đính kèm các ảnh UI (từ màn 1 đến màn 10). Bạn phải phân tích kỹ màu sắc (tông xanh lá chủ đạo `#00A859`), typography, layout, border-radius, padding để code UI chuẩn Pixel-perfect.

---

## 🛠 CÔNG NGHỆ & KIẾN TRÚC TỔNG THỂ
- **Mobile App:** Flutter, Dart. Kiến trúc Clean Architecture (Data, Domain, Presentation).
- **Quản lý State:** `flutter_bloc`.
- **Dependency Injection:** `get_it`.
- **API Client:** `dio`.
- **Routing:** `go_router`.
- **Backend:** NestJS (Thiết kế RESTful API + WebSocket).
- **Database:** PostgreSQL (lưu trữ trên Supabase). Dùng Prisma ORM hoặc TypeORM.
- **Realtime Chat:** Socket.IO + NestJS.
- **Push Notifications:** Firebase Cloud Messaging (FCM).
- **Lưu trữ file/ảnh:** Cloudinary.
- **Xác thực (OTP):** Nodemailer (gửi Email OTP thực tế qua Gmail).
- **Bản đồ:** `flutter_map` kết hợp dữ liệu OpenStreetMap (OSM) (Không dùng Google Maps).
- **Thanh toán:** Tích hợp SePay Webhook kết hợp mã VietQR động để tự động hóa trạng thái nạp tiền/mua gói.

---

## 🎨 HỆ THỐNG DESIGN SYSTEM (DỰA TRÊN ẢNH ĐÍNH KÈM)
- **Màu sắc:**
  - Primary: Xanh lá cây đậm (Khoảng `#00A859` - xem logo và các nút bấm).
  - Background: Trắng (`#FFFFFF`) và xám nhạt (`#F5F5F5`) cho nền app.
  - Text: Đen nhạt (`#333333`) và Xám (`#888888`) cho subtitle.
- **Typography:** Font chữ không chân, gọn gàng, hiện đại (khuyên dùng Inter hoặc Roboto).
- **Components:**
  - `TextFormField`: Nền xám nhạt, không viền (hoặc viền rất mờ), bo góc khoảng 12px. Có icon prefix (email, lock, phone).
  - `Button`: Đổ màu Solid Primary, bo góc 12px, chữ trắng in đậm.
  - `Card`: Bo góc 16px, có shadow rất mờ và nhẹ, tạo cảm giác nổi.
  - `Bottom Navigation Bar`: Nền trắng. Tab đang chọn có màu xanh Primary, tab không chọn màu xám. Đặc biệt Role Manager và Barber có Floating Action Button (FAB) nằm chìm giữa thanh nav (lồi lên trên).

---

## 🚀 TÍNH NĂNG CHI TIẾT & UI THEO TỪNG MÀN HÌNH

### 1. HỆ THỐNG XÁC THỰC (Tham khảo Ảnh 1 & 2)
- **Màn hình Đăng nhập (Ảnh 1):** Header có Logo cái kéo và text "BARBERSMART". 2 Tab chuyển đổi Đăng nhập/Đăng ký. Form gồm Email, Mật khẩu (có icon mắt xem pass), Text "Quên mật khẩu?", Nút "Đăng nhập" to.
- **Màn hình Đăng ký (Ảnh 2):** Form gồm: Họ tên, Email xác thực, Số điện thoại, Mật khẩu, Nhập lại mật khẩu. Text cảnh báo điều khoản. Nút "Đăng ký".
- **Luồng OTP:** Bấm đăng ký -> Gọi API NestJS dùng Nodemailer gửi OTP 6 số về Email -> Chuyển sang màn nhập OTP -> Nhập đúng thì tạo user với role mặc định là `USER`.

### 2. GIAO DIỆN CHUNG & PHÂN QUYỀN (BOTTOM NAV)
- **Role Khách hàng (User):** 4 Tab: `Trang chủ`, `Bản đồ`, `Nổi bật`, `Hồ sơ`.
- **Role Quản lý (Manager - Ảnh 9):** 5 Tab. Ở giữa là nút FAB to lồi lên màu xanh lá, icon Cửa hàng, text `Quản lý`.
- **Role Barber (Ảnh 10):** 5 Tab. Ở giữa là nút FAB to lồi lên màu xanh lá, icon Lịch, text `Lịch`.

### 3. TÍNH NĂNG CHI TIẾT THEO ROLE: NGƯỜI DÙNG (USER)
Tất cả Role đều có tính năng này.
- **Trang chủ (Ảnh 3):**
  - Header: Text `BARBERSMART`, chuông thông báo (có badge đỏ đếm số), Avatar user. Thanh tìm kiếm & icon filter.
  - Body: Danh sách Card quán lân cận. Mỗi Card gồm: Ảnh bìa to, Tên quán, Badge Rating Sao góc phải trên, Khoảng cách (Icon location), Giờ mở cửa (Icon clock), Số điện thoại (Icon phone).
- **Màn hình Bản đồ (Ảnh 5):**
  - Dùng `flutter_map` (OSM).
  - Nền map. Các Marker màu xanh lá icon Cái kéo, bên dưới marker có hộp text nền trắng bo góc ghi Tên quán.
  - Thanh tìm kiếm đè lên map ở trên cùng.
- **Chi tiết quán - Bottom Sheet (Ảnh 4):**
  - Vuốt từ dưới lên. Có thanh kéo (drag handle).
  - Ảnh avatar quán, Tên, Địa chỉ, Giờ mở cửa, Nút "Chỉ đường" (viền xanh, chữ xanh).
  - Nút "Chat với barber" (Solid xanh). Tích hợp Socket.IO tạo Group Chat với tất cả thợ của quán.
  - Tab view: `Thông tin`, `Dịch vụ`, `Hình ảnh`, `Barber`, `Đánh giá`. (Có mô tả ngắn hiển thị bên dưới).
- **Trang Nổi Bật (Ảnh 6):**
  - Danh sách dạng list các quán mua gói nổi bật. Card ảnh to phủ toàn bộ, gradient đen dưới đáy. Tên quán màu trắng nổi lên. Góc phải dưới có nút "Đặt lịch" màu xanh lá.
- **Luồng Đặt Lịch (Core Logic Complex):**
  - Chọn Barber -> Chọn nhiều Dịch vụ -> App tự tính Tổng thời gian (VD: 50p).
  - Màn Chọn Giờ: Thanh ngang chọn ngày. Bên dưới là timeline khối liên tục chia làm 2 hàng ngang: **Ca sáng (08:30 - 11:30)** và **Ca chiều (14:00 - 20:30)**.
  - **Logic Chặn tràn giờ:** Dựa vào tổng thời gian dịch vụ, nếu user chọn mốc giờ mà bị lấn qua `11:30` hoặc `20:30`, slot đó sẽ bị Disable (Khóa) không cho chọn ngay từ đầu. Slot đã có người đặt sẽ chuyển màu xám.
  - Thanh toán tại quán hoặc QR Code.
- **Tài khoản (Ảnh 7):**
  - Khối thông tin: Avatar tròn to, Tên, Badge "Thành viên thân thiết".
  - List Menu (dạng card trắng chứa list item): Thông báo, Lịch đã đặt (Cho phép Hủy lịch), Đăng ký quán (để lên đời Manager).
  - Nút Đăng xuất chữ đỏ.
- **Trang cá nhân / Mạng xã hội thu nhỏ (Ảnh 8):**
  - Ảnh Cover to trên cùng. Avatar đè lên đường viền cover. Nút "Chỉnh sửa".
  - Thông tin: Tên, Ngày sinh, Giới tính.
  - Nút "Đăng bài mới" to màu xanh.
  - Feed: Hiển thị bài viết (Avatar, Tên, Role badge, thời gian, Text, Grid ảnh tối đa 5 ảnh lưu Cloudinary). Nút Bình luận.

### 4. LUỒNG THANH TOÁN TỰ ĐỘNG BẰNG SEPAY
- Áp dụng cho: **Đăng ký Quán (100k)** và **Mua gói Nổi bật (20k/50k/90k)**.
- Khi thực hiện, NestJS tạo 1 mã VietQR động chứa sẵn Số tiền + Nội dung chuyển khoản định danh (Ví dụ: `PAY SHOP 12345`).
- Người dùng quét mã trả tiền. SePay bắt biến động số dư -> Bắn Webhook về NestJS. NestJS đổi trạng thái -> Dùng Socket.IO đẩy event về App báo thành công lập tức. KHÔNG CHỜ DUYỆT TAY.

### 5. TÍNH NĂNG ROLE: QUẢN LÝ QUÁN (Ảnh 9)
- Một Manager CHỈ sở hữu tối đa 1 quán. Manager KHÔNG được tự làm Barber.
- **UI (Ảnh 9):** Ảnh cover quán, Tên, Giờ, SĐT. Các nút menu dạng list bo góc: `Quản lý thông tin`, `Quản lý barber`, `Doanh thu và lương`. Nút FAB `Quản lý` ở Bottom Nav.
- **Nghiệp vụ:** Tìm Username mời làm Barber. Nếu Barber đã thuộc quán khác -> Báo lỗi. Nhập lương cứng. Mua gói nổi bật.

### 6. TÍNH NĂNG ROLE: BARBER (Ảnh 10)
- **UI (Ảnh 10):** Có badge xanh `ĐANG HOẠT ĐỘNG` trên ảnh bìa. Menu: `Xem Lịch`, `Tư vấn khách hàng`, `Thu nhập`. Nút FAB `Lịch` ở Bottom Nav.
- **Nghiệp vụ:**
  - Màn Xem lịch: Dạng heatmap/calendar.
  - Ấn vào khách hàng -> Có nút "Xác nhận đã thanh toán". Chỉ khi Barber bấm nút này thì trạng thái Booking mới đổi thành `COMPLETED`, quán mới được cộng doanh thu và Barber mới được tính hoa hồng (10%).

---

## 🎯 THỨ TỰ THỰC THI (ACTION PLAN)
1. **Thiết lập:** Khởi tạo `project_prompt.md` và `progress_report.md`.
2. **Backend & DB:** Thiết kế Schema PostgreSQL (`User`, `Shop`, `Barber`, `Service`, `Booking`, `Post`, `Transaction`, `FCM_Token`...). Khởi tạo NestJS project, setup TypeORM/Prisma.
3. **App Base:** Khởi tạo Flutter project, setup Clean Architecture folders, routing (`go_router`), DI (`get_it`), State (`flutter_bloc`), theme màu sắc theo chuẩn UI.
4. **Tính năng:** Triển khai tuần tự `Auth` -> `Dynamic Navigation` -> `Home/Map` -> `Detail` -> `Core Booking Logic` -> `Management`.


---

## ✅ CÁC QUYẾT ĐỊNH ĐÃ CHỐT (CLARIFICATION CONFIRMED)
1. **Cấu trúc Monorepo & ORM:** Tách thành 2 thư mục độc lập ở gốc repository:
   - `mobile/`: Ứng dụng Flutter (Clean Architecture, `flutter_bloc`, `get_it`, `dio`, `go_router`, `flutter_map` OSM, `socket_io_client`).
   - `backend/`: Server NestJS kết nối PostgreSQL (Supabase) sử dụng **TypeORM**.
2. **Logic chia Slot Đặt lịch:**
   - Bước nhảy giữa các mốc giờ: **15 phút** (`08:30, 08:45, 09:00...`).
   - Khung giờ: Giới hạn đầu-cuối linh hoạt theo giờ mở/đóng cửa riêng của từng quán, nhưng vẫn giữ khoảng nghỉ trưa cố định `11:30 - 14:00` (Ca sáng: `openTime -> 11:30`, Ca chiều: `14:00 -> closeTime`).
   - Chặn tràn giờ: Mốc giờ nào mà `start + totalDuration` vượt quá `11:30` (ca sáng) hoặc vượt quá `closeTime` (ca chiều), hoặc chồng lấn lên lịch đã đặt thì bị Disable ngay từ đầu.
3. **Định danh Auth & Mời Barber:**
   - Giữ nguyên form Đăng ký chuẩn theo **Ảnh 2** (`Họ tên`, `Email xác thực`, `Số điện thoại`, `Mật khẩu`, `Nhập lại mật khẩu` — không có trường `Username`).
   - Quản lý quán tìm kiếm người dùng để mời làm Barber thông qua **Email hoặc Số điện thoại**. Nếu người đó đã thuộc quán khác hoặc đang là Manager thì báo lỗi.
4. **Thanh toán QR qua SePay & Hủy lịch:**
   - Cả 3 luồng: **Đăng ký Quán (100k)**, **Mua gói Nổi bật (20k/50k/90k)** và **Đặt lịch bằng QR Code** đều tạo mã VietQR động tích hợp **SePay Webhook + Socket.IO**.
   - Riêng **Đặt lịch bằng QR Code**: Ngay khi SePay bắn Webhook báo quét mã thành công, trạng thái Booking tự động chuyển luôn sang `COMPLETED` (`isPaid = true`), cộng doanh thu cho quán & hoa hồng `10%` cho Barber và bắn Socket.IO về App.
   - Với **Thanh toán tại quán**: Chỉ khi Barber bấm nút `"Xác nhận đã thanh toán"` trên lịch thì Booking mới chuyển sang `COMPLETED` và cộng doanh thu/hoa hồng.
   - Khách hàng được phép **Hủy lịch** đối với các lịch chưa `COMPLETED`.


---

## 🚀 CẬP NHẬT v3: YÊU CẦU KỸ THUẬT MỚI & FIX BUG (FIX BUGS, VỊ TRÍ & SEED DATA)

### 📌 QUY TRÌNH LÀM VIỆC & NGUYÊN TẮC TỰ TEST (SELF-TESTING)
- **Khởi tạo/Cập nhật Workspace:** Đọc kỹ toàn bộ prompt, cập nhật `project_prompt.md` và `progress_report.md`.
- **Nguyên tắc Tự Test (Self-Testing):** Bất cứ khi nào viết xong hoặc sửa xong một chức năng (đặc biệt là Routing và Upload ảnh), PHẢI tự rà soát lại logic code để đảm bảo không dính các lỗi cơ bản (như trắng màn hình) trước khi báo cáo hoàn thành.
- **Cơ chế Checkpoint:** Khi sắp hết quota/context, dừng ở state an toàn, không cắt dở code. Cập nhật tiến độ vào `progress_report.md` và đưa ra chỉ dẫn cho lượt chat tiếp theo.

### 1. Fix Lỗi Trắng Màn Hình Khi Đăng Xuất (Logout Bug)
- **Hiện trạng:** Khi user bấm "Đăng xuất" ở màn Tài khoản, màn hình bị trắng xóa (Blank Screen).
- **Yêu cầu xử lý:** Đây là lỗi do cấu hình `go_router` và State Management. Khi bấm Đăng xuất, phải dọn dẹp sạch Token/Session cục bộ, kích hoạt event để `AuthCubit` chuyển về state Unauthenticated. Tại cấp độ Router, phải lắng nghe state này để redirect thẳng về trang `/login`. Tuyệt đối không dùng `Navigator.pop()` dẫn đến việc văng khỏi stack gây trắng màn hình.

### 2. Xử Lý Hình Ảnh & Upload (Profile, Bài Viết, Quán)
- Tích hợp thư viện `image_picker` vào Flutter.
- Ở tất cả các form liên quan đến ảnh (Đổi Avatar/Cover, Đăng bài viết mới, Đăng ký quán / Chỉnh sửa quán), người dùng phải có **2 lựa chọn**:
  1. **Tải ảnh lên từ Thiết bị (Gallery/Camera)**
  2. **Nhập URL ảnh trực tiếp**
- File ảnh chọn từ thiết bị phải được đẩy lên Backend NestJS (`POST /api/v1/upload/images`) để upload thẳng lên **Cloudinary**, sau đó lưu URL trả về vào **Supabase**.

### 3. Vị Trí Thật & Bản Đồ Thật (Real GPS & Map)
- Khi mở app, tích hợp thư viện `geolocator` để hiển thị popup xin quyền truy cập vị trí thật của người dùng.
- Lấy Kinh độ & Vĩ độ thực tế của device truyền vào `flutter_map` (dùng dữ liệu OpenStreetMap - OSM). Bản đồ phải center ngay tại vị trí thật của người dùng.
- Các marker (Quán cắt tóc) phải hiển thị khoảng cách (`km`) tính từ vị trí thật của user đến tọa độ của quán.

### 4. Database Seeding (Khởi tạo Dữ liệu Mẫu & Tọa độ Vạn Phúc - Hà Đông)
- Viết Seeder chạy tự động trong `onModuleInit` của NestJS (và hỗ trợ chạy độc lập) để tự động bơm dữ liệu mẫu vào Supabase ngay khi khởi động server, không để DB trống:
  - **Tạo ~5 Quán cắt tóc (Shop):** Mỗi quán gắn với 1 tài khoản Manager thực. **ĐẶC BIỆT CHÚ Ý:** Tọa độ (`latitude`, `longitude`) và Địa chỉ của 5 quán này bắt buộc xoay quanh khu vực **Vạn Phúc, Hà Đông, Hà Nội** (`~20.976xxx, 105.772xxx`).
  - **Tạo Barber:** Mỗi quán sở hữu từ 3-5 Barber (Mỗi Barber có user account thực trong DB, gắn Role `BARBER`, mapping với ID của quán).
  - **Hình ảnh mẫu:** Gắn sẵn các URL ảnh thật (Unsplash/Pexels) cho Avatar, Background của tất cả Quán và User này.
  - **Avatar mặc định:** Trong DB, bất kỳ ai mới tạo tài khoản mà chưa up ảnh được set avatar mặc định là URL ảnh xám trống (tương tự avatar mặc định của Facebook).
  - **Gói Nổi Bật (Highlights):** Chủ động seed data cho 2-3 Quán trong số 5 quán trên có bản ghi `"Đã mua gói Nổi bật"` với thời hạn hết hạn là **100 ngày tới**. Tab `"Nổi bật"` trên App query ra đúng các quán này từ DB.
