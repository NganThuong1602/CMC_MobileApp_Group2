import 'package:equatable/equatable.dart';
import '../../core/enums/app_enums.dart';

class PostCommentEntity extends Equatable {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  const PostCommentEntity({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, postId, authorId, content, createdAt];
}

class PostEntity extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final UserRole authorRole;
  final String? authorAvatarUrl;
  final String content;
  final List<String> imageUrls; // Tối đa 5 ảnh (Cloudinary)
  final List<PostCommentEntity> comments;
  final DateTime createdAt;

  const PostEntity({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    this.authorAvatarUrl,
    required this.content,
    required this.imageUrls,
    required this.comments,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        authorId,
        content,
        imageUrls,
        comments,
        createdAt,
      ];
}

class ReviewEntity extends Equatable {
  final String id;
  final String shopId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const ReviewEntity({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, shopId, userId, rating, comment, createdAt];
}

class ChatMessageEntity extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final UserRole senderRole;
  final String content;
  final DateTime createdAt;

  const ChatMessageEntity({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, roomId, senderId, content, createdAt];
}

class ChatRoomEntity extends Equatable {
  final String id;
  final String shopId;
  final String shopName;
  final String customerId;
  final String customerName;
  final List<ChatMessageEntity> messages;

  const ChatRoomEntity({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.customerId,
    required this.customerName,
    required this.messages,
  });

  @override
  List<Object?> get props => [id, shopId, customerId, messages];
}

class AppNotificationEntity extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final String? targetShopId;
  final String? targetBarberId;
  final String? targetRoomId;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  const AppNotificationEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.targetShopId,
    this.targetBarberId,
    this.targetRoomId,
    this.payload,
    required this.createdAt,
  });

  AppNotificationEntity copyWith({
    bool? isRead,
    Map<String, dynamic>? payload,
  }) {
    return AppNotificationEntity(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      targetShopId: targetShopId,
      targetBarberId: targetBarberId,
      targetRoomId: targetRoomId,
      payload: payload ?? this.payload,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        type,
        isRead,
        targetRoomId,
        createdAt,
      ];
}

