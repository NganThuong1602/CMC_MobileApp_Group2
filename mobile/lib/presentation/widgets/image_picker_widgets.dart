import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/di/injection_container.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/remote/remote_api_datasource.dart';

String _extractUploadError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return msg is List ? msg.join(', ') : msg.toString();
    }
    return 'Không thể kết nối Backend để tải ảnh lên Cloudinary (${error.type.name})';
  }
  return error.toString();
}

/// Widget chọn 1 ảnh duy nhất (dùng cho Avatar, Ảnh bìa Profile, Ảnh bìa Quán):
/// Hỗ trợ song song 2 lựa chọn:
/// 1. Tải ảnh từ Thiết bị (Thư viện / Camera) -> gửi lên NestJS -> Cloudinary -> trả về HTTPS URL.
/// 2. Nhập trực tiếp URL ảnh (https://...).
class SingleImagePickerField extends StatefulWidget {
  final String label;
  final String? initialUrl;
  final ValueChanged<String> onChanged;
  final bool isCircularPreview;
  final String? hintText;

  const SingleImagePickerField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialUrl,
    this.isCircularPreview = false,
    this.hintText,
  });

  @override
  State<SingleImagePickerField> createState() => _SingleImagePickerFieldState();
}

class _SingleImagePickerFieldState extends State<SingleImagePickerField> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _urlCtrl;
  bool _uploading = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = (widget.initialUrl ?? '').trim();
    _urlCtrl = TextEditingController(text: _currentUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploading = true);
      final urls = await sl<RemoteApiDataSource>().uploadImages([picked]);
      if (!mounted) return;

      if (urls.isNotEmpty) {
        final uploadedUrl = urls.first;
        setState(() {
          _currentUrl = uploadedUrl;
          _urlCtrl.text = uploadedUrl;
          _uploading = false;
        });
        widget.onChanged(uploadedUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text('Tải ảnh lên Cloudinary thành công!'),
          ),
        );
      } else {
        setState(() => _uploading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text(_extractUploadError(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _currentUrl.startsWith('http');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isCircularPreview)
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.primaryGreenLight,
                    backgroundImage:
                        hasPreview ? NetworkImage(_currentUrl) : null,
                    onBackgroundImageError: hasPreview ? (_, __) {} : null,
                    child: !hasPreview
                        ? const Icon(
                            Icons.person_outline_rounded,
                            size: 34,
                            color: AppTheme.primaryGreen,
                          )
                        : null,
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 112,
                      width: double.infinity,
                      color: AppTheme.primaryGreenLight,
                      child: hasPreview
                          ? Image.network(
                              _currentUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 32,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: AppTheme.primaryGreen,
                                size: 34,
                              ),
                            ),
                    ),
                  ),
                if (_uploading)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => _pickAndUpload(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 17),
                  label: const Text(
                    'Thư viện',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => _pickAndUpload(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 17),
                  label: const Text(
                    'Camera',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            onChanged: (val) {
              final trimmed = val.trim();
              setState(() => _currentUrl = trimmed);
              widget.onChanged(trimmed);
            },
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              fillColor: AppTheme.surfaceWhite,
              isDense: true,
              hintText:
                  widget.hintText ?? 'Hoặc dán URL ảnh trực tiếp (https://...)',
              prefixIcon: const Icon(Icons.link_rounded, size: 18),
              suffixIcon: _currentUrl.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _urlCtrl.clear();
                        setState(() => _currentUrl = '');
                        widget.onChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget chọn nhiều ảnh (dùng cho Đăng bài viết mới tối đa 5 ảnh & Bộ sưu tập ảnh Quán):
/// Hỗ trợ song song 2 lựa chọn:
/// 1. Chọn nhiều ảnh từ Thư viện / Chụp Camera -> Upload lên Cloudinary qua NestJS.
/// 2. Nhập trực tiếp URL ảnh rồi bấm "Thêm".
class MultiImagePickerField extends StatefulWidget {
  final String label;
  final List<String> initialUrls;
  final int maxImages;
  final ValueChanged<List<String>> onChanged;

  const MultiImagePickerField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialUrls = const [],
    this.maxImages = 5,
  });

  @override
  State<MultiImagePickerField> createState() => _MultiImagePickerFieldState();
}

class _MultiImagePickerFieldState extends State<MultiImagePickerField> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _directUrlCtrl = TextEditingController();
  late List<String> _urls;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _urls = List<String>.from(widget.initialUrls);
  }

  @override
  void dispose() {
    _directUrlCtrl.dispose();
    super.dispose();
  }

  int get _remaining => math.max(0, widget.maxImages - _urls.length);

  Future<void> _pickGalleryMulti() async {
    if (_remaining <= 0) return;
    try {
      final pickedList = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (pickedList.isEmpty || !mounted) return;

      final allowedCount = math.min(_remaining, 5);
      final batch = pickedList.take(allowedCount).toList();

      setState(() => _uploading = true);
      final uploadedUrls = await sl<RemoteApiDataSource>().uploadImages(batch);
      if (!mounted) return;

      setState(() {
        _urls = [..._urls, ...uploadedUrls].take(widget.maxImages).toList();
        _uploading = false;
      });
      widget.onChanged(List<String>.unmodifiable(_urls));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text(_extractUploadError(e)),
        ),
      );
    }
  }

  Future<void> _pickCameraSingle() async {
    if (_remaining <= 0) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploading = true);
      final uploadedUrls =
          await sl<RemoteApiDataSource>().uploadImages([picked]);
      if (!mounted) return;

      setState(() {
        _urls = [..._urls, ...uploadedUrls].take(widget.maxImages).toList();
        _uploading = false;
      });
      widget.onChanged(List<String>.unmodifiable(_urls));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text(_extractUploadError(e)),
        ),
      );
    }
  }

  void _addDirectUrl() {
    final raw = _directUrlCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text('URL ảnh phải bắt đầu bằng http:// hoặc https://'),
        ),
      );
      return;
    }
    if (_urls.length >= widget.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text('Chỉ được đính kèm tối đa ${widget.maxImages} ảnh'),
        ),
      );
      return;
    }
    setState(() {
      _urls = [..._urls, raw];
      _directUrlCtrl.clear();
    });
    widget.onChanged(List<String>.unmodifiable(_urls));
  }

  void _removeAt(int index) {
    setState(() {
      _urls = List<String>.from(_urls)..removeAt(index);
    });
    widget.onChanged(List<String>.unmodifiable(_urls));
  }

  @override
  Widget build(BuildContext context) {
    final canAddMore = _urls.length < widget.maxImages && !_uploading;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.label} (${_urls.length}/${widget.maxImages})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_uploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGreen,
                  ),
                ),
            ],
          ),
          if (_urls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _urls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, idx) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _urls[idx],
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 76,
                          height: 76,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: GestureDetector(
                        onTap: () => _removeAt(idx),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canAddMore ? _pickGalleryMulti : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 17),
                  label: const Text(
                    'Từ Thiết bị',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canAddMore ? _pickCameraSingle : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 17),
                  label: const Text(
                    'Chụp Camera',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _directUrlCtrl,
                  enabled: canAddMore,
                  onSubmitted: (_) => _addDirectUrl(),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    fillColor: AppTheme.surfaceWhite,
                    isDense: true,
                    hintText: 'Hoặc nhập URL ảnh trực tiếp (https://...)',
                    prefixIcon: Icon(Icons.link_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: canAddMore ? _addDirectUrl : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Thêm', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
