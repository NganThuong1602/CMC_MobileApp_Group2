import '../../core/utils/result.dart';
import '../entities/social_entities.dart';
import '../repositories/social_repository.dart';

class GetFeedPostsUseCase {
  final SocialRepository repository;
  const GetFeedPostsUseCase(this.repository);

  Future<Result<List<PostEntity>>> call({String? authorId}) {
    return repository.getFeedPosts(authorId: authorId);
  }
}

class CreatePostUseCase {
  final SocialRepository repository;
  const CreatePostUseCase(this.repository);

  Future<Result<PostEntity>> call({
    required String authorId,
    required String content,
    required List<String> imageUrls,
  }) {
    return repository.createPost(
      authorId: authorId,
      content: content,
      imageUrls: imageUrls,
    );
  }
}

