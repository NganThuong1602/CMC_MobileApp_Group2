import '../../core/utils/result.dart';
import '../entities/social_entities.dart';
import '../entities/user_entity.dart';

abstract class SocialRepository {
  Future<Result<UserEntity>> getPublicUserProfile(String userId);

  Future<Result<List<PostEntity>>> getFeedPosts({String? authorId});

  Future<Result<PostEntity>> createPost({
    required String authorId,
    required String content,
    required List<String> imageUrls,
  });

  Future<Result<PostEntity>> updatePost({
    required String postId,
    required String authorId,
    required String content,
    required List<String> imageUrls,
  });

  Future<Result<void>> deletePost({
    required String postId,
    required String authorId,
  });

  Future<Result<PostCommentEntity>> addPostComment({
    required String postId,
    required String authorId,
    required String content,
  });

  Future<Result<List<ReviewEntity>>> getShopReviews(String shopId);

  Future<Result<ReviewEntity>> addShopReview({
    required String shopId,
    required String userId,
    required int rating,
    required String comment,
  });

  Future<Result<ChatRoomEntity>> getOrCreateShopChatRoom({
    required String shopId,
    required String customerId,
  });

  Future<Result<List<ChatRoomEntity>>> getBarberShopChatRooms(String shopId);

  Future<Result<List<ChatRoomEntity>>> getManagerShopChatRooms(String shopId);

  Future<Result<ChatMessageEntity>> sendChatMessage({
    required String roomId,
    required String senderId,
    required String content,
  });

  Future<Result<List<AppNotificationEntity>>> getUserNotifications(
    String userId,
  );

  Future<Result<void>> markNotificationRead(String notificationId);
}

