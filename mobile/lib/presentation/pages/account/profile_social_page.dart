import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/social_entities.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../widgets/image_picker_widgets.dart';

/// Màn hình Trang cá nhân & Mạng xã hội theo từng tài khoản riêng biệt:
/// - Mỗi tài khoản (USER / MANAGER / BARBER) có trang cá nhân riêng hiển thị đúng thông tin và CHỈ các bài đăng của người đó (`getFeedPosts(authorId: profileUserId)`).
/// - Ở góc phải trên cùng của mỗi bài đăng thuộc tài khoản hiện tại có nút 3 chấm (`PopupMenuButton`) để Sửa bài đăng hoặc Xoá bài đăng.
/// - Hỗ trợ xem trang cá nhân của người khác khi truyền `targetUserId` (VD: chạm vào Barber trong chi tiết quán).
class ProfileSocialPage extends StatefulWidget {
  final String? targetUserId;

  const ProfileSocialPage({
    super.key,
    this.targetUserId,
  });

  @override
  State<ProfileSocialPage> createState() => _ProfileSocialPageState();
}

class _ProfileSocialPageState extends State<ProfileSocialPage> {
  List<PostEntity> _posts = [];
  UserEntity? _viewedUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileAndPosts();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileSocialPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetUserId != widget.targetUserId) {
      _loadProfileAndPosts();
    }
  }

  Future<void> _loadProfileAndPosts() async {
    if (!mounted) return;
    final currentUser = context.read<AuthCubit>().state.user;
    if (currentUser == null) return;

    setState(() => _loading = true);

    final targetId =
        (widget.targetUserId != null && widget.targetUserId!.trim().isNotEmpty)
            ? widget.targetUserId!.trim()
            : currentUser.id;

    UserEntity? profileOwner = currentUser;
    if (targetId != currentUser.id) {
      final profileRes =
          await sl<SocialRepository>().getPublicUserProfile(targetId);
      profileOwner = profileRes.data ?? currentUser;
    }

    final postsRes =
        await sl<SocialRepository>().getFeedPosts(authorId: targetId);
    if (!mounted) return;
    setState(() {
      _viewedUser = profileOwner;
      _posts = postsRes.data ?? [];
      _loading = false;
    });
  }

  void _showEditProfileDialog(UserEntity user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    DateTime birthDate = user.birthDate ?? DateTime(1996, 8, 15);
    Gender gender = user.gender ?? Gender.male;
    String avatarUrl = user.avatarUrl ?? AppConstants.defaultAvatarUrl;
    String coverUrl = user.coverUrl ?? '';
    bool saving = false;
    String? nameError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Chỉnh sửa trang cá nhân'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleImagePickerField(
                    label: 'Ảnh đại diện (Avatar)',
                    initialUrl: avatarUrl,
                    isCircularPreview: true,
                    onChanged: (url) => avatarUrl = url,
                  ),
                  const SizedBox(height: 12),
                  SingleImagePickerField(
                    label: 'Ảnh bìa (Cover)',
                    initialUrl: coverUrl,
                    isCircularPreview: false,
                    onChanged: (url) => coverUrl = url,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (_) {
                      if (nameError != null) {
                        setModalState(() => nameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Họ và tên *',
                      errorText: nameError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Gender>(
                    initialValue: gender,
                    decoration: const InputDecoration(labelText: 'Giới tính'),
                    items: Gender.values
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(g.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => gender = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: birthDate,
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() => birthDate = picked);
                        }
                      },
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(
                        'Ngày sinh: ${AppFormatters.formatDateDdMmYyyy(birthDate)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().length < 2) {
                        setModalState(
                          () => nameError = 'Họ và tên phải có ít nhất 2 ký tự',
                        );
                        return;
                      }
                      setModalState(() => saving = true);
                      await context.read<AuthCubit>().updateProfile(
                            fullName: nameCtrl.text.trim(),
                            birthDate: birthDate,
                            gender: gender,
                            avatarUrl: avatarUrl.trim().isNotEmpty
                                ? avatarUrl.trim()
                                : AppConstants.defaultAvatarUrl,
                            coverUrl: coverUrl.trim().isNotEmpty
                                ? coverUrl.trim()
                                : null,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadProfileAndPosts();
                    },
              child: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog(UserEntity user) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final contentCtrl = TextEditingController();
    List<String> selectedUrls = [];
    bool posting = false;
    String? contentError;

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
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đăng bài viết mới (Tối đa 5 ảnh)',
                  style: tt.dialogTitle,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  onChanged: (_) {
                    if (contentError != null) {
                      setModalState(() => contentError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Khoe kiểu tóc mới hoặc chia sẻ trải nghiệm...',
                    errorText: contentError,
                  ),
                ),
                const SizedBox(height: 12),
                MultiImagePickerField(
                  label: 'Ảnh đính kèm bài viết',
                  maxImages: AppConstants.maxPostImages,
                  initialUrls: selectedUrls,
                  onChanged: (urls) {
                    setModalState(() {
                      selectedUrls = urls;
                      if (urls.isNotEmpty) contentError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: posting
                        ? null
                        : () async {
                            if (contentCtrl.text.trim().isEmpty &&
                                selectedUrls.isEmpty) {
                              setModalState(
                                () => contentError =
                                    'Vui lòng nhập nội dung bài viết hoặc chọn ít nhất 1 ảnh',
                              );
                              return;
                            }
                            setModalState(() => posting = true);
                            final res = await sl<SocialRepository>().createPost(
                              authorId: user.id,
                              content: contentCtrl.text,
                              imageUrls: selectedUrls,
                            );
                            if (!ctx.mounted) return;
                            setModalState(() => posting = false);
                            res.fold(
                              onFailure: (f) =>
                                  setModalState(() => contentError = f.message),
                              onSuccess: (_) {
                                Navigator.pop(ctx);
                                _loadProfileAndPosts();
                              },
                            );
                          },
                    child: Text(posting ? 'Đang đăng bài...' : 'Đăng bài ngay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPostDialog(PostEntity post, UserEntity currentUser) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final contentCtrl = TextEditingController(text: post.content);
    List<String> selectedUrls = List<String>.from(post.imageUrls);
    bool saving = false;
    String? contentError;

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
            18,
            18,
            18,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chỉnh sửa bài đăng',
                  style: tt.dialogTitle,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  onChanged: (_) {
                    if (contentError != null) {
                      setModalState(() => contentError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Nhập nội dung bài viết...',
                    errorText: contentError,
                  ),
                ),
                const SizedBox(height: 12),
                MultiImagePickerField(
                  label: 'Ảnh đính kèm bài viết (Tối đa 5 ảnh)',
                  maxImages: AppConstants.maxPostImages,
                  initialUrls: selectedUrls,
                  onChanged: (urls) {
                    setModalState(() {
                      selectedUrls = urls;
                      if (urls.isNotEmpty) contentError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (contentCtrl.text.trim().isEmpty &&
                                    selectedUrls.isEmpty) {
                                  setModalState(
                                    () => contentError =
                                        'Bài đăng cần có nội dung hoặc ít nhất 1 ảnh',
                                  );
                                  return;
                                }
                                setModalState(() => saving = true);
                                final res =
                                    await sl<SocialRepository>().updatePost(
                                  postId: post.id,
                                  authorId: currentUser.id,
                                  content: contentCtrl.text,
                                  imageUrls: selectedUrls,
                                );
                                if (!ctx.mounted) return;
                                setModalState(() => saving = false);
                                res.fold(
                                  onFailure: (f) => setModalState(
                                    () => contentError = f.message,
                                  ),
                                  onSuccess: (_) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: cs.primary,
                                        content: const Text(
                                          'Đã cập nhật bài đăng thành công!',
                                        ),
                                      ),
                                    );
                                    _loadProfileAndPosts();
                                  },
                                );
                              },
                        child: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(
    PostEntity post,
    UserEntity currentUser,
  ) async {
    final cs = context.colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá bài đăng?'),
        content: const Text(
          'Bạn có chắc chắn muốn xoá bài đăng này khỏi trang cá nhân không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá bài'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final res = await sl<SocialRepository>().deletePost(
      postId: post.id,
      authorId: currentUser.id,
    );
    if (!mounted) return;
    res.fold(
      onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: cs.error, content: Text(f.message)),
      ),
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: const Text('Đã xoá bài đăng thành công!'),
          ),
        );
        _loadProfileAndPosts();
      },
    );
  }

  void _showCommentsSheet(PostEntity post, UserEntity currentUser) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final cmtCtrl = TextEditingController();
    String? cmtError;

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
                    onPressed: () async {
                      if (cmtCtrl.text.trim().isEmpty) {
                        setModalState(
                          () => cmtError = 'Vui lòng nhập nội dung bình luận',
                        );
                        return;
                      }
                      await sl<SocialRepository>().addPostComment(
                        postId: post.id,
                        authorId: currentUser.id,
                        content: cmtCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadProfileAndPosts();
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
    final currentUser = context.watch<AuthCubit>().state.user;

    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isOwnProfile = widget.targetUserId == null ||
        widget.targetUserId!.trim().isEmpty ||
        widget.targetUserId!.trim() == currentUser.id;
    final profileUser = isOwnProfile
        ? currentUser
        : (_viewedUser ?? currentUser);

    final avatarUrl = (profileUser.avatarUrl != null &&
            profileUser.avatarUrl!.trim().isNotEmpty)
        ? profileUser.avatarUrl!
        : AppConstants.defaultAvatarUrl;
    final dobText = profileUser.birthDate != null
        ? AppFormatters.formatDateDdMmYyyy(profileUser.birthDate!)
        : '15/08/1996';
    final genderText = profileUser.gender?.label ?? 'Nam';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: cs.surface,
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: isOwnProfile
                            ? () => _showEditProfileDialog(currentUser)
                            : null,
                        child: SizedBox(
                          height: 175,
                          width: double.infinity,
                          child: Image.network(
                            (profileUser.coverUrl != null &&
                                    profileUser.coverUrl!.trim().isNotEmpty)
                                ? profileUser.coverUrl!
                                : 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: cs.inverseSurface),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: CircleAvatar(
                          backgroundColor: cs.scrim,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: cs.onInverseSurface,
                            ),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/');
                              }
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: -36,
                        child: GestureDetector(
                          onTap: isOwnProfile
                              ? () => _showEditProfileDialog(currentUser)
                              : null,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  backgroundImage: NetworkImage(avatarUrl),
                                  onBackgroundImageError: (_, __) {},
                                ),
                              ),
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Tooltip(
                                  message: profileUser.role.label,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: cs.surface,
                                        width: 2.2,
                                      ),
                                    ),
                                    child: Icon(
                                      profileUser.role.roleIcon,
                                      size: 14,
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: isOwnProfile
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  _showEditProfileDialog(currentUser),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: Text(
                                'Chỉnh sửa',
                                style: tt.bodySmallPrimary,
                              ),
                            )
                          : const SizedBox(height: 36),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profileUser.fullName,
                                style: tt.pageTitle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: profileUser.role.label,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  profileUser.role.roleIcon,
                                  size: 15,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cake_outlined,
                                  size: 15,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Ngày sinh: $dobText',
                                  style: tt.bodySmallMuted,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.male_rounded,
                                  size: 16,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Giới tính: $genderText',
                                  style: tt.bodySmallMuted,
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isOwnProfile) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showCreatePostDialog(currentUser),
                              icon: const Icon(Icons.edit_square, size: 18),
                              label: const Text('Đăng bài mới'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dynamic_feed_outlined,
                        size: 42,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isOwnProfile
                            ? 'Bạn chưa có bài đăng nào trên trang cá nhân.\nHãy bấm "Đăng bài mới" để chia sẻ khoảnh khắc đầu tiên!'
                            : '${profileUser.fullName} chưa có bài đăng nào.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(14),
              sliver: SliverList.separated(
                itemCount: _posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (ctx, i) =>
                    _buildPostCard(ctx, _posts[i], currentUser),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    PostEntity post,
    UserEntity currentUser,
  ) {
    final cs = context.colorScheme;
    final tt = context.appTextStyles;
    final appColors = context.appColors;
    final isPostOwner = post.authorId == currentUser.id;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
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
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              post.authorRole.roleIcon,
                              size: 13,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      AppFormatters.formatRelativeTime(post.createdAt),
                      style: tt.captionMuted,
                    ),
                  ],
                ),
              ),
              if (isPostOwner)
                PopupMenuButton<String>(
                  tooltip: 'Tuỳ chọn bài đăng',
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditPostDialog(post, currentUser);
                    } else if (action == 'delete') {
                      _confirmDeletePost(post, currentUser);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 10),
                          Text('Chỉnh sửa bài đăng', style: tt.bodyPrimary),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: cs.error,
                          ),
                          const SizedBox(width: 10),
                          Text('Xoá bài đăng', style: tt.bodySmallDanger),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
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
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showCommentsSheet(post, currentUser),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
      ),
    );
  }

  /// Bố cục ảnh 2 trên + 3 dưới chuẩn như Ảnh 8 (tối đa 5 ảnh)
  Widget _buildCollageGrid(List<String> urls) {
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          urls.first,
          height: 190,
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
