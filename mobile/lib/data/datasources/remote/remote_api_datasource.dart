import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/network/api_client.dart';
import '../../models/app_models.dart';

class ShopDetailBundle {
  final ShopModel shop;
  final List<ServiceModel> services;
  final List<BarberModel> barbers;
  final List<ReviewModel> reviews;

  const ShopDetailBundle({
    required this.shop,
    required this.services,
    required this.barbers,
    required this.reviews,
  });
}

/// Remote DataSource gọi RESTful API tới NestJS Backend (kết nối Supabase + Cloudinary + SePay).
class RemoteApiDataSource {
  final ApiClient apiClient;

  const RemoteApiDataSource(this.apiClient);

  void clearToken() {
    apiClient.setAccessToken(null);
  }

  // ==================== AUTH & PROFILE ====================
  Future<({UserModel user, String token})> login(
    String email,
    String password,
  ) async {
    final res = await apiClient.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final token = (map['accessToken'] ?? '').toString();
    final user = UserModel.fromJson(
      Map<String, dynamic>.from(map['user'] as Map),
    );
    apiClient.setAccessToken(token);
    return (user: user, token: token);
  }

  Future<String> requestRegisterOtp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    final res = await apiClient.dio.post(
      '/auth/register/request-otp',
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    return (map['message'] ?? 'Đã gửi mã OTP 6 số tới $email').toString();
  }

  Future<({UserModel user, String token})> verifyRegisterOtp(
    String email,
    String otpCode,
  ) async {
    final res = await apiClient.dio.post(
      '/auth/register/verify-otp',
      data: {'email': email, 'otpCode': otpCode},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final token = (map['accessToken'] ?? '').toString();
    final user = UserModel.fromJson(
      Map<String, dynamic>.from(map['user'] as Map),
    );
    apiClient.setAccessToken(token);
    return (user: user, token: token);
  }

  Future<String> requestForgotPasswordOtp(String email) async {
    final res = await apiClient.dio.post(
      '/auth/forgot-password/request-otp',
      data: {'email': email},
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    return (map['message'] ?? 'Đã gửi mã OTP đặt lại mật khẩu').toString();
  }

  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    await apiClient.dio.post(
      '/auth/forgot-password/reset',
      data: {
        'email': email,
        'otpCode': otpCode,
        'newPassword': newPassword,
      },
    );
  }

  Future<UserModel> getMe() async {
    final res = await apiClient.dio.get('/auth/me');
    return UserModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<UserModel> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? coverUrl,
    DateTime? birthDate,
    Gender? gender,
  }) async {
    String? apiGender;
    if (gender != null) {
      apiGender = switch (gender) {
        Gender.male => 'MALE',
        Gender.female => 'FEMALE',
        Gender.other => 'OTHER',
      };
    }
    String? apiBirth;
    if (birthDate != null) {
      apiBirth =
          '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    }

    final res = await apiClient.dio.patch(
      '/auth/profile',
      data: {
        if (fullName != null) 'fullName': fullName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (apiBirth != null) 'birthDate': apiBirth,
        if (apiGender != null) 'gender': apiGender,
      },
    );
    return UserModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  // ==================== CLOUDINARY UPLOAD ====================
  /// Tải tối đa 5 ảnh chọn từ thiết bị (Web / Android / iOS) lên NestJS -> Cloudinary.
  Future<List<String>> uploadImages(List<XFile> files) async {
    final multipartFiles = <MultipartFile>[];
    for (int i = 0; i < files.length; i++) {
      final bytes = await files[i].readAsBytes();
      final rawName = files[i].name.trim();
      final filename = rawName.isNotEmpty ? rawName : 'barbersmart_$i.jpg';
      multipartFiles.add(
        MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      );
    }

    final formData = FormData();
    for (final mf in multipartFiles) {
      formData.files.add(MapEntry('files', mf));
    }
    final res = await apiClient.dio.post(
      '/upload/images',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final urls = (map['urls'] as List?)?.map((e) => e.toString()).toList() ?? [];
    return urls;
  }

  /// Tải 1 ảnh đã qua bước căn chỉnh (Crop Bytes) lên NestJS -> Cloudinary.
  Future<String?> uploadImageBytes(
    List<int> bytes, {
    String filename = 'barbersmart_cropped.png',
  }) async {
    final formData = FormData.fromMap({
      'files': [
        MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      ],
    });
    final res = await apiClient.dio.post(
      '/upload/images',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    final urls =
        (map['urls'] as List?)?.map((e) => e.toString()).toList() ?? [];
    return urls.isNotEmpty ? urls.first : null;
  }

  // ==================== SHOPS & PAYMENTS ====================
  Future<List<ShopModel>> getNearbyShops({
    double? lat,
    double? lng,
    String? search,
    double? minRating,
  }) async {
    final res = await apiClient.dio.get(
      '/shops/nearby',
      queryParameters: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (search != null && search.isNotEmpty) 'search': search,
        if (minRating != null) 'minRating': minRating,
      },
    );
    final list = res.data as List;
    return list
        .map((e) => ShopModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ShopModel>> getHighlightedShops() async {
    final res = await apiClient.dio.get('/shops/highlights');
    final list = res.data as List;
    return list
        .map((e) => ShopModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ShopDetailBundle> getShopDetail(String shopId) async {
    final res = await apiClient.dio.get('/shops/$shopId');
    return _parseShopDetailMap(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ShopDetailBundle?> getMyOwnedShop() async {
    final res = await apiClient.dio.get('/shops/me/owned');
    if (res.data == null || res.data == '') return null;
    if (res.data is! Map) return null;
    return _parseShopDetailMap(Map<String, dynamic>.from(res.data as Map));
  }

  ShopDetailBundle _parseShopDetailMap(Map<String, dynamic> map) {
    final shop = ShopModel.fromJson(map);
    final services = (map['services'] as List?)
            ?.whereType<Map>()
            .map((m) => ServiceModel.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        const <ServiceModel>[];
    final barbers = (map['barbers'] as List?)
            ?.whereType<Map>()
            .map(
              (m) => BarberModel.fromJson(
                Map<String, dynamic>.from(m),
                fallbackShopId: shop.id,
              ),
            )
            .toList() ??
        const <BarberModel>[];
    final reviews = (map['reviews'] as List?)
            ?.whereType<Map>()
            .map(
              (m) => ReviewModel.fromJson(
                Map<String, dynamic>.from(m),
                fallbackShopId: shop.id,
              ),
            )
            .toList() ??
        const <ReviewModel>[];

    return ShopDetailBundle(
      shop: shop,
      services: services,
      barbers: barbers,
      reviews: reviews,
    );
  }

  Future<ShopModel> updateShop(
    String shopId,
    Map<String, dynamic> payload,
  ) async {
    final res = await apiClient.dio.patch('/shops/$shopId', data: payload);
    return ShopModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ServiceModel> createShopService({
    required String shopId,
    required String name,
    required int price,
    required int durationMinutes,
  }) async {
    final res = await apiClient.dio.post(
      '/shops/$shopId/services',
      data: {
        'name': name,
        'price': price,
        'durationMinutes': durationMinutes,
      },
    );
    return ServiceModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ServiceModel> updateShopService({
    required String serviceId,
    required String name,
    required int price,
    required int durationMinutes,
  }) async {
    final res = await apiClient.dio.patch(
      '/shops/services/$serviceId',
      data: {
        'name': name,
        'price': price,
        'durationMinutes': durationMinutes,
      },
    );
    return ServiceModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteShopService(String serviceId) async {
    await apiClient.dio.delete('/shops/services/$serviceId');
  }

  Future<Map<String, dynamic>> getShopPayroll(String shopId) async {
    final res = await apiClient.dio.get('/shops/$shopId/payroll');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<PaymentTransactionModel> createRegisterShopQr(
    Map<String, dynamic> dto,
  ) async {
    final res = await apiClient.dio.post('/payments/register-shop-qr', data: dto);
    return PaymentTransactionModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<PaymentTransactionModel> createHighlightQr(String plan) async {
    final res = await apiClient.dio.post(
      '/payments/highlight-qr',
      data: {'plan': plan},
    );
    return PaymentTransactionModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<PaymentTransactionModel> createBookingQr(String bookingId) async {
    final res = await apiClient.dio.post(
      '/payments/booking-qr',
      data: {'bookingId': bookingId},
    );
    return PaymentTransactionModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<PaymentTransactionModel> triggerSePayWebhook({
    required String transferContent,
    required int amount,
  }) async {
    final res = await apiClient.dio.post(
      '/payments/sepay-webhook',
      data: {
        'content': transferContent,
        'transferAmount': amount,
        'transferType': 'in',
        'simulated': true,
      },
    );
    final map = Map<String, dynamic>.from(res.data as Map);
    return PaymentTransactionModel.fromJson(map);
  }

  // ==================== BOOKINGS ====================
  Future<Map<String, dynamic>> getAvailableSlots({
    required String shopId,
    required String barberId,
    required String dateStr,
    required int durationMinutes,
  }) async {
    final res = await apiClient.dio.get(
      '/bookings/slots',
      queryParameters: {
        'shopId': shopId,
        'barberId': barberId,
        'date': dateStr,
        'durationMinutes': durationMinutes,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<BookingModel> createBooking({
    required String shopId,
    required String barberId,
    required List<String> serviceIds,
    required String bookingDate,
    required int startMinutes,
    required String paymentMethod,
  }) async {
    final res = await apiClient.dio.post(
      '/bookings',
      data: {
        'shopId': shopId,
        'barberId': barberId,
        'serviceIds': serviceIds,
        'bookingDate': bookingDate,
        'startMinutes': startMinutes,
        'paymentMethod': paymentMethod,
      },
    );
    return BookingModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<BookingModel>> getMyBookings() async {
    final res = await apiClient.dio.get('/bookings/me');
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => BookingModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<BookingModel> cancelBooking(String bookingId) async {
    final res = await apiClient.dio.patch('/bookings/$bookingId/cancel');
    return BookingModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<BookingModel> confirmBookingPaid(String bookingId) async {
    final res = await apiClient.dio.post('/bookings/$bookingId/confirm-paid');
    return BookingModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  // ==================== BARBERS ====================
  Future<Map<String, dynamic>> getMyBarberIncome() async {
    final res = await apiClient.dio.get('/barbers/me/income');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getMyBarberHeatmap(int year, int month) async {
    final res = await apiClient.dio.get(
      '/barbers/me/heatmap',
      queryParameters: {'year': year, 'month': month},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<BookingModel>> getMyBarberTimeline(String dateStr) async {
    final res = await apiClient.dio.get(
      '/barbers/me/timeline',
      queryParameters: {'date': dateStr},
    );
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => BookingModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<UserModel>> searchBarberCandidates(String query) async {
    final res = await apiClient.dio.get(
      '/barbers/search-candidates',
      queryParameters: {'q': query},
    );
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => UserModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> inviteBarber(String emailOrPhone, {int? baseSalary}) async {
    await apiClient.dio.post(
      '/barbers/invite',
      data: {
        'emailOrPhone': emailOrPhone,
        if (baseSalary != null) 'baseSalary': baseSalary,
      },
    );
  }

  Future<void> removeBarber(String barberId) async {
    await apiClient.dio.delete('/barbers/$barberId');
  }

  Future<List<ShopModel>> getAdminPendingShops() async {
    final res = await apiClient.dio.get('/shops/admin/pending');
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => ShopModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<ShopModel>> getAdminActiveShops() async {
    final res = await apiClient.dio.get('/shops/admin/all');
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => ShopModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<ShopModel> approveShopByAdmin(String shopId) async {
    final res = await apiClient.dio.patch('/shops/$shopId/approve');
    return ShopModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteShopByAdmin(String shopId) async {
    await apiClient.dio.delete('/shops/$shopId/admin');
  }

  Future<void> respondBarberInvitation(
    String notificationId,
    bool accept,
  ) async {
    await apiClient.dio.post(
      '/barbers/invitations/$notificationId/respond',
      data: {'accept': accept},
    );
  }

  Future<void> updateBarberSalary(String barberId, int baseSalary) async {
    await apiClient.dio.patch(
      '/barbers/$barberId/salary',
      data: {'baseSalary': baseSalary},
    );
  }

  // ==================== SOCIAL / COMMUNITY / NOTIFICATIONS ====================
  Future<UserModel> getPublicUserProfile(String userId) async {
    final res = await apiClient.dio.get('/users/$userId/public-profile');
    return UserModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<PostModel>> getFeedPosts({String? authorId}) async {
    final res = await apiClient.dio.get(
      authorId == null ? '/posts' : '/posts/user/$authorId',
    );
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => PostModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<PostModel> createPost({
    required String caption,
    required List<String> imageUrls,
  }) async {
    final res = await apiClient.dio.post(
      '/posts',
      data: {
        'caption': caption,
        'imageUrls': imageUrls,
      },
    );
    return PostModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PostModel> updatePost({
    required String postId,
    required String caption,
    required List<String> imageUrls,
  }) async {
    final res = await apiClient.dio.patch(
      '/posts/$postId',
      data: {
        'caption': caption,
        'imageUrls': imageUrls,
      },
    );
    return PostModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deletePost(String postId) async {
    await apiClient.dio.delete('/posts/$postId');
  }

  Future<PostCommentModel> addPostComment({
    required String postId,
    required String content,
  }) async {
    final res = await apiClient.dio.post(
      '/posts/$postId/comments',
      data: {'content': content},
    );
    return PostCommentModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
      fallbackPostId: postId,
    );
  }

  Future<List<ReviewModel>> getShopReviews(String shopId) async {
    final res = await apiClient.dio.get('/shops/$shopId/reviews');
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map(
          (m) => ReviewModel.fromJson(
            Map<String, dynamic>.from(m),
            fallbackShopId: shopId,
          ),
        )
        .toList();
  }

  Future<ReviewModel> addShopReview({
    required String shopId,
    required int rating,
    required String comment,
  }) async {
    final res = await apiClient.dio.post(
      '/shops/$shopId/reviews',
      data: {'rating': rating, 'comment': comment},
    );
    return ReviewModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
      fallbackShopId: shopId,
    );
  }

  Future<Map<String, dynamic>> openShopChat(String shopId) async {
    final res = await apiClient.dio.post('/chat/shops/$shopId/open');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> getBarberChatRooms() async {
    final res = await apiClient.dio.get('/chat/barber/rooms');
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getManagerChatRooms() async {
    final res = await apiClient.dio.get('/chat/manager/rooms');
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getRoomMessages(String roomId) async {
    final res = await apiClient.dio.get('/chat/rooms/$roomId/messages');
    final list = res.data as List;
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<Map<String, dynamic>> sendChatMessageRest({
    required String roomId,
    required String content,
  }) async {
    final res = await apiClient.dio.post(
      '/chat/rooms/$roomId/messages',
      data: {'content': content},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<AppNotificationModel>> getMyNotifications() async {
    final res = await apiClient.dio.get('/notifications');
    final rawList = (res.data is Map
            ? (res.data as Map)['items']
            : res.data) as List? ??
        const [];
    return rawList
        .whereType<Map>()
        .map((m) => AppNotificationModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await apiClient.dio.patch('/notifications/$notificationId/read');
  }
}
