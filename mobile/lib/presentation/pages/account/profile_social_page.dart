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

/// Màn hình Trang cá nhân & Mạng xã hội thu nhỏ chuẩn Pixel-perfect theo Ảnh 8:
/// - Ảnh Cover lớn trên cùng + Avatar tròn đè lên mép dưới bên trái + Nút `Chỉnh sửa`.
/// - Đổi Avatar/Cover bằng cả 2 cách: Tải ảnh từ Thiết bị (Cloudinary) hoặc Nhập URL trực tiếp.
/// - Nút xanh lá full-width `Đăng bài mới` (chọn tối đa 5 ảnh từ Thiết bị -> Cloudinary hoặc URL).
/// - Feed bài viết với Role badge (`Khách hàng`), bố cục ảnh 2+3, nút `Bình luận`.
class ProfileSocialPage extends StatefulWidget {
  const ProfileSocialPage({super.key});

  @override
  State<ProfileSocialPage> createState() => _ProfileSocialPageState();
}

class _ProfileSocialPageState extends State<ProfileSocialPage> {
  List<PostEntity> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final res = await sl<SocialRepository>().getFeedPosts();
    if (mounted) {
      setState(() {
        _posts = res.data ?? [];
        _loading = false;
      });
    }
  }

  void _showEditProfileDialog(UserEntity user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    DateTime birthDate = user.birthDate ?? DateTime(1996, 8, 15);
    Gender gender = user.gender ?? Gender.male;
    String avatarUrl = user.avatarUrl ?? AppConstants.defaultAvatarUrl;
    String coverUrl = user.coverUrl ?? '';
    bool saving = false;

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
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
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
                      setModalState(() => saving = true);
                      await context.read<AuthCubit>().updateProfile(
                            fullName: nameCtrl.text,
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
                      _loadPosts();
                    },
              child: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog(UserEntity user) {
    final contentCtrl = TextEditingController();
    List<String> selectedUrls = [];
    bool posting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceWhite,
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
                const Text(
                  'Đăng bài viết mới (Tối đa 5 ảnh)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Khoe kiểu tóc mới hoặc chia sẻ trải nghiệm...',
                  ),
                ),
                const SizedBox(height: 12),
                MultiImagePickerField(
                  label: 'Ảnh đính kèm bài viết',
                  maxImages: AppConstants.maxPostImages,
                  initialUrls: selectedUrls,
                  onChanged: (urls) {
                    setModalState(() => selectedUrls = urls);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: posting
                        ? null
                        : () async {
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.dangerRed,
                                  content: Text(f.message),
                                ),
                              ),
                              onSuccess: (_) {
                                Navigator.pop(ctx);
                                _loadPosts();
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

  void _showCommentsSheet(PostEntity post, UserEntity currentUser) {
    final cmtCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (post.comments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Hãy là người đầu tiên bình luận bài viết này!',
                  style: TextStyle(color: AppTheme.textSecondary),
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(c.content),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cmtCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Viết bình luận...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    await sl<SocialRepository>().addPostComment(
                      postId: post.id,
                      authorId: currentUser.id,
                      content: cmtCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadPosts();
                  },
                  icon: const Icon(
                    Icons.send_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    final avatarUrl =
        (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty)
            ? user.avatarUrl!
            : AppConstants.defaultAvatarUrl;
    final dobText = user.birthDate != null
        ? AppFormatters.formatDateDdMmYyyy(user.birthDate!)
        : '15/08/1996';
    final genderText = user.gender?.label ?? 'Nam';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.surfaceWhite,
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _showEditProfileDialog(user),
                        child: SizedBox(
                          height: 175,
                          width: double.infinity,
                          child: Image.network(
                            (user.coverUrl != null &&
                                    user.coverUrl!.trim().isNotEmpty)
                                ? user.coverUrl!
                                : 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: const Color(0xFF1F2937)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
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
                          onTap: () => _showEditProfileDialog(user),
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: const Color(0xFFE5E7EB),
                                  backgroundImage: NetworkImage(avatarUrl),
                                  onBackgroundImageError: (_, __) {},
                                ),
                              ),
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 12,
                                    color: Colors.white,
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
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditProfileDialog(user),
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
                        label: const Text(
                          'Chỉnh sửa',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cake_outlined,
                                  size: 15,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Ngày sinh: $dobText',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.male_rounded,
                                  size: 16,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Giới tính: $genderText',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showCreatePostDialog(user),
                            icon: const Icon(Icons.edit_square, size: 18),
                            label: const Text('Đăng bài mới'),
                          ),
                        ),
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
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(14),
              sliver: SliverList.separated(
                itemCount: _posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (ctx, i) => _buildPostCard(_posts[i], user),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostEntity post, UserEntity currentUser) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryGreenLight,
                backgroundImage: post.authorAvatarUrl != null
                    ? NetworkImage(post.authorAvatarUrl!)
                    : null,
                child: post.authorAvatarUrl == null
                    ? const Icon(Icons.person, color: AppTheme.primaryGreen)
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreenLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.authorRole.label,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      AppFormatters.formatRelativeTime(post.createdAt),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.content,
              style: const TextStyle(fontSize: 13.5, height: 1.45),
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
                color: AppTheme.inputFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: AppTheme.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    post.comments.isEmpty
                        ? 'Bình luận'
                        : 'Bình luận (${post.comments.length})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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

