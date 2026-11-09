import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';
import '../../core/error/failures.dart';
import '../../core/network/socket_service.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/social_entities.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/social_repository.dart';
import '../datasources/local/in_memory_database.dart';
import '../datasources/remote/remote_api_datasource.dart';

class SocialRepositoryImpl implements SocialRepository {
  final InMemoryDatabase db;
  final RemoteApiDataSource remote;
  final SocketService socketService;

  const SocialRepositoryImpl({
    required this.db,
    required this.remote,
    required this.socketService,
  });

  String _extractDioError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return msg is List ? msg.first.toString() : msg.toString();
    }
    return fallback;
  }

  @override
  Future<Result<UserEntity>> getPublicUserProfile(String userId) async {
    try {
      final remoteUser = await remote.getPublicUserProfile(userId);
      final idx = db.users.indexWhere((u) => u.id == remoteUser.id);
      if (idx == -1) {
        db.users.add(remoteUser);
      } else {
        db.users[idx] = remoteUser;
      }
      return Result.success(remoteUser);
    } catch (_) {}

    final idx = db.users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      return Result.success(db.users[idx]);
    }
    if (db.currentUser != null && db.currentUser!.id == userId) {
      return Result.success(db.currentUser!);
    }
    return Result.failure(
      const ValidationFailure('Không tìm thấy thông tin trang cá nhân'),
    );
  }

  @override
  Future<Result<List<PostEntity>>> getFeedPosts({String? authorId}) async {
    try {
      final remotePosts = await remote.getFeedPosts(authorId: authorId);
      for (final p in remotePosts) {
        final idx = db.posts.indexWhere((x) => x.id == p.id);
        if (idx == -1) {
          db.posts.add(p);
        } else {
          db.posts[idx] = p;
        }
      }
      final filteredRemote = authorId == null
          ? remotePosts
          : remotePosts.where((p) => p.authorId == authorId).toList();
      return Result.success(filteredRemote);
    } catch (_) {}

    final list = authorId == null
        ? List<PostEntity>.from(db.posts)
        : db.posts.where((p) => p.authorId == authorId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Result.success(list);
  }

  @override
  Future<Result<PostEntity>> createPost({
    required String authorId,
    required String content,
    required List<String> imageUrls,
  }) async {
    if (content.trim().isEmpty && imageUrls.isEmpty) {
      return Result.failure(
        const ValidationFailure('Vui lòng nhập nội dung hoặc đính kèm ảnh'),
      );
    }
    if (imageUrls.length > AppConstants.maxPostImages) {
      return Result.failure(
        const ValidationFailure(
          'Mỗi bài viết chỉ được đính kèm tối đa 5 ảnh!',
        ),
      );
    }

    final cleanUrls = imageUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(AppConstants.maxPostImages)
        .toList();

    try {
      final createdRemote = await remote.createPost(
        caption: content.trim(),
        imageUrls: cleanUrls,
      );
      db.posts.insert(0, createdRemote);
      return Result.success(createdRemote);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể đăng bài viết mới'),
          ),
        );
      }
    } catch (_) {}

    final uIdx = db.users.indexWhere((u) => u.id == authorId);
    final author = uIdx != -1 ? db.users[uIdx] : db.currentUser;
    if (author == null) {
      return Result.failure(const AuthFailure('Tài khoản không hợp lệ'));
    }

    final post = PostEntity(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      authorId: author.id,
      authorName: author.fullName,
      authorRole: author.role,
      authorAvatarUrl: author.avatarUrl,
      content: content.trim(),
      imageUrls: cleanUrls,
      comments: const [],
      createdAt: DateTime.now(),
    );
    db.posts.insert(0, post);
    return Result.success(post);
  }

  @override
  Future<Result<PostEntity>> updatePost({
    required String postId,
    required String authorId,
    required String content,
    required List<String> imageUrls,
  }) async {
    if (content.trim().isEmpty && imageUrls.isEmpty) {
      return Result.failure(
        const ValidationFailure('Vui lòng nhập nội dung hoặc đính kèm ảnh'),
      );
    }
    if (imageUrls.length > AppConstants.maxPostImages) {
      return Result.failure(
        const ValidationFailure(
          'Mỗi bài viết chỉ được đính kèm tối đa 5 ảnh!',
        ),
      );
    }

    final cleanUrls = imageUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(AppConstants.maxPostImages)
        .toList();

    try {
      final updatedRemote = await remote.updatePost(
        postId: postId,
        caption: content.trim(),
        imageUrls: cleanUrls,
      );
      final idx = db.posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        db.posts[idx] = updatedRemote;
      } else {
        db.posts.insert(0, updatedRemote);
      }
      return Result.success(updatedRemote);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(
            _extractDioError(e, 'Không thể chỉnh sửa bài viết'),
          ),
        );
      }
    } catch (_) {}

    final pIdx = db.posts.indexWhere((p) => p.id == postId);
    if (pIdx == -1) {
      return Result.failure(
        const ValidationFailure('Không tìm thấy bài viết cần chỉnh sửa'),
      );
    }
    final oldPost = db.posts[pIdx];
    if (oldPost.authorId != authorId) {
      return Result.failure(
        const ValidationFailure('Bạn chỉ có thể chỉnh sửa bài viết của mình'),
      );
    }

    final updated = PostEntity(
      id: oldPost.id,
      authorId: oldPost.authorId,
      authorName: oldPost.authorName,
      authorRole: oldPost.authorRole,
      authorAvatarUrl: oldPost.authorAvatarUrl,
      content: content.trim(),
      imageUrls: cleanUrls,
      comments: oldPost.comments,
      createdAt: oldPost.createdAt,
    );
    db.posts[pIdx] = updated;
    return Result.success(updated);
  }

  @override
  Future<Result<void>> deletePost({
    required String postId,
    required String authorId,
  }) async {
    try {
      await remote.deletePost(postId);
      db.posts.removeWhere((p) => p.id == postId);
      return Result.success(null);
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(
          ValidationFailure(_extractDioError(e, 'Không thể xoá bài viết')),
        );
      }
    } catch (_) {}

    final pIdx = db.posts.indexWhere((p) => p.id == postId);
    if (pIdx != -1 && db.posts[pIdx].authorId != authorId) {
      return Result.failure(
        const ValidationFailure('Bạn chỉ có thể xoá bài viết của mình'),
      );
    }
    db.posts.removeWhere((p) => p.id == postId);
    return Result.success(null);
  }

  @override
  Future<Result<PostCommentEntity>> addPostComment({
    required String postId,
    required String authorId,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      return Result.failure(
        const ValidationFailure('Nội dung bình luận không được để trống'),
      );
    }

    try {
      final createdRemote = await remote.addPostComment(
        postId: postId,
        content: content.trim(),
      );
      return Result.success(createdRemote);
    } catch (_) {}

    final pIdx = db.posts.indexWhere((p) => p.id == postId);
    final uIdx = db.users.indexWhere((u) => u.id == authorId);
    if (pIdx == -1 || uIdx == -1) {
      return Result.failure(
        const ValidationFailure('Không tìm thấy bài viết hoặc tài khoản'),
      );
    }

    final user = db.users[uIdx];
    final post = db.posts[pIdx];
    final comment = PostCommentEntity(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      authorId: user.id,
      authorName: user.fullName,
      authorRole: user.role,
      authorAvatarUrl: user.avatarUrl,
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    db.posts[pIdx] = PostEntity(
      id: post.id,
      authorId: post.authorId,
      authorName: post.authorName,
      authorRole: post.authorRole,
      authorAvatarUrl: post.authorAvatarUrl,
      content: post.content,
      imageUrls: post.imageUrls,
      comments: [...post.comments, comment],
      createdAt: post.createdAt,
    );
    return Result.success(comment);
  }

  @override
  Future<Result<List<ReviewEntity>>> getShopReviews(String shopId) async {
    try {
      final remoteList = await remote.getShopReviews(shopId);
      return Result.success(remoteList);
    } catch (_) {}

    final list = db.reviews.where((r) => r.shopId == shopId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Result.success(list);
  }

  @override
  Future<Result<ReviewEntity>> addShopReview({
    required String shopId,
    required String userId,
    required int rating,
    required String comment,
  }) async {
    try {
      final createdRemote = await remote.addShopReview(
        shopId: shopId,
        rating: rating.clamp(1, 5),
        comment: comment.trim(),
      );
      db.reviews.insert(0, createdRemote);
      return Result.success(createdRemote);
    } catch (_) {}

    final uIdx = db.users.indexWhere((u) => u.id == userId);
    final sIdx = db.shops.indexWhere((s) => s.id == shopId);
    if (uIdx == -1 || sIdx == -1) {
      return Result.failure(const ValidationFailure('Thông tin không hợp lệ'));
    }

    final user = db.users[uIdx];
    final rev = ReviewEntity(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      userId: user.id,
      userName: user.fullName,
      userAvatarUrl: user.avatarUrl,
      rating: rating.clamp(1, 5),
      comment: comment.trim(),
      createdAt: DateTime.now(),
    );
    db.reviews.insert(0, rev);

    final shopReviews = db.reviews.where((r) => r.shopId == shopId).toList();
    final avg = shopReviews.fold<int>(0, (s, r) => s + r.rating) /
        shopReviews.length;
    db.shops[sIdx] = db.shops[sIdx].copyWith(
      rating: double.parse(avg.toStringAsFixed(1)),
      reviewCount: shopReviews.length,
    );

    return Result.success(rev);
  }

  @override
  Future<Result<ChatRoomEntity>> getOrCreateShopChatRoom({
    required String shopId,
    required String customerId,
  }) async {
    try {
      final roomMap = await remote.openShopChat(shopId);
      final roomId = (roomMap['id'] ?? '').toString();
      final msgMaps = await remote.getRoomMessages(roomId);
      final msgs = msgMaps.map((m) {
        return ChatMessageEntity(
          id: (m['id'] ?? '').toString(),
          roomId: roomId,
          senderId: (m['senderId'] ?? '').toString(),
          senderName: (m['senderName'] ?? 'Thành viên').toString(),
          senderRole: UserRole.fromApi(m['senderRole']?.toString()),
          content: (m['content'] ?? '').toString(),
          createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
              DateTime.now(),
        );
      }).toList();

      final room = ChatRoomEntity(
        id: roomId,
        shopId: shopId,
        shopName: (roomMap['shop']?['name'] ?? 'Barber Shop').toString(),
        customerId: customerId,
        customerName:
            (roomMap['customer']?['fullName'] ?? 'Khách hàng').toString(),
        messages: msgs,
      );
      db.chatRooms.removeWhere((r) => r.id == room.id);
      db.chatRooms.add(room);
      socketService.joinChatRoom(room.id);
      return Result.success(room);
    } catch (_) {}

    final idx = db.chatRooms.indexWhere(
      (r) => r.shopId == shopId && r.customerId == customerId,
    );
    if (idx != -1) {
      socketService.joinChatRoom(db.chatRooms[idx].id);
      return Result.success(db.chatRooms[idx]);
    }

    final sIdx = db.shops.indexWhere((s) => s.id == shopId);
    final uIdx = db.users.indexWhere((u) => u.id == customerId);
    final shopName = sIdx != -1 ? db.shops[sIdx].name : 'Barber Shop';
    final customerName = uIdx != -1 ? db.users[uIdx].fullName : 'Khách hàng';

    final room = ChatRoomEntity(
      id: 'room_${shopId}_$customerId',
      shopId: shopId,
      shopName: shopName,
      customerId: customerId,
      customerName: customerName,
      messages: const [],
    );
    db.chatRooms.add(room);
    socketService.joinChatRoom(room.id);
    return Result.success(room);
  }

  @override
  Future<Result<List<ChatRoomEntity>>> getBarberShopChatRooms(
    String shopId,
  ) async {
    try {
      final rawRooms = await remote.getBarberChatRooms();
      final rooms = <ChatRoomEntity>[];
      for (final m in rawRooms) {
        final roomId = (m['id'] ?? '').toString();
        final msgMaps = await remote.getRoomMessages(roomId);
        final msgs = msgMaps.map((msg) {
          return ChatMessageEntity(
            id: (msg['id'] ?? '').toString(),
            roomId: roomId,
            senderId: (msg['senderId'] ?? '').toString(),
            senderName: (msg['senderName'] ?? 'Thành viên').toString(),
            senderRole: UserRole.fromApi(msg['senderRole']?.toString()),
            content: (msg['content'] ?? '').toString(),
            createdAt: DateTime.tryParse((msg['createdAt'] ?? '').toString()) ??
                DateTime.now(),
          );
        }).toList();
        final r = ChatRoomEntity(
          id: roomId,
          shopId: (m['shopId'] ?? shopId).toString(),
          shopName: (m['shop']?['name'] ?? 'Barber Shop').toString(),
          customerId: (m['customerId'] ?? '').toString(),
          customerName:
              (m['customer']?['fullName'] ?? 'Khách hàng').toString(),
          messages: msgs,
        );
        db.chatRooms.removeWhere((x) => x.id == r.id);
        db.chatRooms.add(r);
        rooms.add(r);
      }
      return Result.success(rooms);
    } catch (_) {}

    final list = db.chatRooms.where((r) => r.shopId == shopId).toList();
    return Result.success(list);
  }

  @override
  Future<Result<List<ChatRoomEntity>>> getManagerShopChatRooms(
    String shopId,
  ) async {
    try {
      final rawRooms = await remote.getManagerChatRooms();
      final rooms = <ChatRoomEntity>[];
      for (final m in rawRooms) {
        final roomId = (m['id'] ?? '').toString();
        final msgMaps = await remote.getRoomMessages(roomId);
        final msgs = msgMaps.map((msg) {
          return ChatMessageEntity(
            id: (msg['id'] ?? '').toString(),
            roomId: roomId,
            senderId: (msg['senderId'] ?? '').toString(),
            senderName: (msg['senderName'] ?? 'Thành viên').toString(),
            senderRole: UserRole.fromApi(msg['senderRole']?.toString()),
            content: (msg['content'] ?? '').toString(),
            createdAt: DateTime.tryParse((msg['createdAt'] ?? '').toString()) ??
                DateTime.now(),
          );
        }).toList();
        final r = ChatRoomEntity(
          id: roomId,
          shopId: (m['shopId'] ?? shopId).toString(),
          shopName: (m['shop']?['name'] ?? 'Barber Shop').toString(),
          customerId: (m['customerId'] ?? '').toString(),
          customerName:
              (m['customer']?['fullName'] ?? 'Khách hàng').toString(),
          messages: msgs,
        );
        db.chatRooms.removeWhere((x) => x.id == r.id);
        db.chatRooms.add(r);
        rooms.add(r);
      }
      return Result.success(rooms);
    } catch (_) {}

    final list = db.chatRooms.where((r) => r.shopId == shopId).toList();
    return Result.success(list);
  }

  @override
  Future<Result<ChatMessageEntity>> sendChatMessage({
    required String roomId,
    required String senderId,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      return Result.failure(
        const ValidationFailure('Tin nhắn không được để trống'),
      );
    }

    try {
      final remoteMsgMap = await remote.sendChatMessageRest(
        roomId: roomId,
        content: content.trim(),
      );
      final msg = ChatMessageEntity(
        id: (remoteMsgMap['id'] ?? '').toString(),
        roomId: roomId,
        senderId: (remoteMsgMap['senderId'] ?? senderId).toString(),
        senderName: (remoteMsgMap['senderName'] ?? 'Thành viên').toString(),
        senderRole: UserRole.fromApi(remoteMsgMap['senderRole']?.toString()),
        content: (remoteMsgMap['content'] ?? content.trim()).toString(),
        createdAt:
            DateTime.tryParse((remoteMsgMap['createdAt'] ?? '').toString()) ??
                DateTime.now(),
      );
      final rIdx = db.chatRooms.indexWhere((r) => r.id == roomId);
      if (rIdx != -1) {
        final room = db.chatRooms[rIdx];
        db.chatRooms[rIdx] = ChatRoomEntity(
          id: room.id,
          shopId: room.shopId,
          shopName: room.shopName,
          customerId: room.customerId,
          customerName: room.customerName,
          messages: [...room.messages, msg],
        );
      }
      return Result.success(msg);
    } catch (_) {}

    final uIdx = db.users.indexWhere((u) => u.id == senderId);
    final sender = uIdx != -1 ? db.users[uIdx] : db.currentUser;
    if (sender == null) {
      return Result.failure(const ValidationFailure('Tài khoản không hợp lệ'));
    }

    final msg = ChatMessageEntity(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: sender.id,
      senderName: sender.fullName,
      senderRole: sender.role,
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    final rIdx = db.chatRooms.indexWhere((r) => r.id == roomId);
    if (rIdx != -1) {
      final room = db.chatRooms[rIdx];
      db.chatRooms[rIdx] = ChatRoomEntity(
        id: room.id,
        shopId: room.shopId,
        shopName: room.shopName,
        customerId: room.customerId,
        customerName: room.customerName,
        messages: [...room.messages, msg],
      );
      final shopIdx = db.shops.indexWhere((s) => s.id == room.shopId);
      if (shopIdx != -1) {
        final shop = db.shops[shopIdx];
        if (sender.id != shop.ownerId) {
          db.notifications.insert(
            0,
            AppNotificationEntity(
              id: 'notif_chat_${DateTime.now().millisecondsSinceEpoch}',
              userId: shop.ownerId,
              title: 'Tin nhắn mới từ khách hàng ${sender.fullName}',
              body: content.trim(),
              type: NotificationType.chatMessage,
              targetShopId: shop.id,
              createdAt: DateTime.now(),
            ),
          );
        } else if (sender.id != room.customerId) {
          db.notifications.insert(
            0,
            AppNotificationEntity(
              id: 'notif_chat_${DateTime.now().millisecondsSinceEpoch}',
              userId: room.customerId,
              title: 'Phản hồi từ quán ${shop.name}',
              body: content.trim(),
              type: NotificationType.chatMessage,
              targetShopId: shop.id,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    }

    socketService.sendChatMessage(
      roomId: roomId,
      senderId: senderId,
      content: content.trim(),
    );

    return Result.success(msg);
  }

  @override
  Future<Result<List<AppNotificationEntity>>> getUserNotifications(
    String userId,
  ) async {
    try {
      final remoteNotifs = await remote.getMyNotifications();
      return Result.success(remoteNotifs);
    } catch (_) {}

    final list =
        db.notifications.where((n) => n.userId == userId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Result.success(list);
  }

  @override
  Future<Result<void>> markNotificationRead(String notificationId) async {
    try {
      await remote.markNotificationRead(notificationId);
    } catch (_) {}
    final idx = db.notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      db.notifications[idx] = db.notifications[idx].copyWith(isRead: true);
    }
    return Result.success(null);
  }
}
