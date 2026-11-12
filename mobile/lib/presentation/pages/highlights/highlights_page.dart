import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/shop_discovery/shop_discovery_cubit.dart';
import '../../widgets/barbersmart_header.dart';

/// Màn hình Diễn đàn (đổi từ "Nổi bật"):
/// - Hiển thị bài đăng từ Barber (từ thời điểm được nhận vào quán `joinedAt`) và Chủ quán (role `MANAGER`).
/// - Sắp xếp theo thời gian mới nhất (`createdAt DESC`).
/// - Cho phép xem trang cá nhân của Barber / Chủ quán và bình luận trực tiếp trên bài đăng.
class HighlightsPage extends StatefulWidget {
  final VoidCallback onNavigateToMapTab;

  const HighlightsPage({
    super.key,
    required this.onNavigateToMapTab,
  });

  @override
  State<HighlightsPage> createState() => _HighlightsPageState();
}

class _HighlightsPageState extends State<HighlightsPage> {
  List<PostEntity> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadForumPosts();
  }

  Future<void> _loadForumPosts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await sl<SocialRepository>().getForumPosts();
    if (!mounted) return;
    setState(() {
      _posts = res.data ?? [];
      _loading = false;
    });
  }

  Future<void> _refreshAll(String? userId) async {
    await Future.wait([
      _loadForumPosts(),
      context.read<ShopDiscoveryCubit>().loadAll(userId: userId),
    ]);
  }

  void _showCommentsSheet(PostEntity post, UserEntity currentUser) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final cmtCtrl = TextEditingController();
    String? cmtError;
    bool sending = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bình luận (${post.comments.length})',
                style: tt.dialogTitle,
              ),
              const SizedBox(height: 10),
              if (post.comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Hãy là người đầu tiên bình luận bài viết này!',
                    style: tt.bodyMuted,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: post.comments.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final c = post.comments[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${c.authorName} (${c.authorRole.label})',
                          style: tt.bodyStrong,
                        ),
                        subtitle: Text(c.content),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: cmtCtrl,
                      onChanged: (_) {
                        if (cmtError != null) {
                          setModalState(() => cmtError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
                        errorText: cmtError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: sending
                        ? null
                        : () async {
                            if (cmtCtrl.text.trim().isEmpty) {
                              setModalState(
                                () =>
                                    cmtError = 'Vui lòng nhập nội dung bình luận',
                              );
                              return;
                            }
                            setModalState(() => sending = true);
                            await sl<SocialRepository>().addPostComment(
                              postId: post.id,
                              authorId: currentUser.id,
                              content: cmtCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadForumPosts();
                          },
                    icon: Icon(
                      Icons.send_rounded,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final user = context.watch<AuthCubit>().state.user;

    return BlocBuilder<ShopDiscoveryCubit, ShopDiscoveryState>(
      builder: (context, discoveryState) {
        return Column(
          children: [
            BarberSmartHeader(
              unreadCount: discoveryState.unreadNotificationCount,
              onNotificationTap: () async {
                await context.push('/notifications');
                if (context.mounted) {
                  _refreshAll(user?.id);
                }
              },
              onProfileSocialTap: () async {
                await context.push('/profile-social');
                if (context.mounted) _loadForumPosts();
              },
            ),
            Container(
              width: double.infinity,
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.forum_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diễn đàn BarberSmart',
                      style: tt.sectionTitle,
                    ),
                  ),
                  Text(
                    'Mới nhất',
                    style: tt.badgePrimary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && _posts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: cs.primary,
                      onRefresh: () => _refreshAll(user?.id),
                      child: _posts.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 90),
                                Icon(
                                  Icons.dynamic_feed_outlined,
                                  size: 46,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                  ),
                                  child: Text(
                                    'Chưa có bài đăng nào từ các Barber hoặc Chủ quán trên Diễn đàn.',
                                    textAlign: TextAlign.center,
                                    style: tt.bodyMuted,
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: _posts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (ctx, i) => _buildForumPostCard(
                                ctx,
                                _posts[i],
                                user,
                              ),
                            ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildForumPostCard(
    BuildContext context,
    PostEntity post,
    UserEntity? currentUser,
  ) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              await context.push('/profile-social?userId=${post.authorId}');
              if (context.mounted) _loadForumPosts();
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: post.authorAvatarUrl != null
                      ? NetworkImage(post.authorAvatarUrl!)
                      : null,
                  child: post.authorAvatarUrl == null
                      ? Icon(Icons.person, color: cs.primary)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: tt.cardTitle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: post.authorRole.label,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                post.authorRole.roleIcon,
                                size: 12,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (post.authorShopName != null &&
                              post.authorShopName!.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                post.authorShopName!,
                                style: tt.badgeSecondary,
                              ),
                            ),
                          Text(
                            AppFormatters.formatRelativeTime(post.createdAt),
                            style: tt.captionMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.content,
              style: tt.bodyRegular,
            ),
          ],
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildCollageGrid(post.imageUrls),
          ],
          if (currentUser != null) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showCommentsSheet(post, currentUser),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: cs.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      post.comments.isEmpty
                          ? 'Bình luận'
                          : 'Bình luận (${post.comments.length})',
                      style: tt.bodySmallStrong,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollageGrid(List<String> urls) {
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          urls.first,
          height: 195,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    final topRow = urls.take(2).toList();
    final bottomRow = urls.skip(2).take(3).toList();

    return Column(
      children: [
        Row(
          children: topRow
              .map(
                (u) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        u,
                        height: 155,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (bottomRow.isNotEmpty)
          Row(
            children: bottomRow
                .map(
                  (u) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          u,
                          height: 105,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
