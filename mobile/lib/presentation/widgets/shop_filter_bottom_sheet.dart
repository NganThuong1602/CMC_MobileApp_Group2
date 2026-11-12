import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/shop_discovery/shop_discovery_cubit.dart';

/// Bottom Sheet bộ lọc dùng chung cho cả Trang chủ và Bản đồ:
/// - Lọc theo mức đánh giá sao (Tất cả, Từ 4.0⭐, 4.5⭐, 4.8⭐, 4.9⭐)
/// - Lọc theo khoảng cách bằng thanh trượt từ 1km -> 20km (lọc các quán từ 0 km đến mức thanh trượt đang chọn)
/// - Cuối bảng có 2 nút hành động rõ ràng: "Xoá lọc" và "Tìm kiếm"
/// Toàn bộ màu sắc & kiểu chữ kế thừa tự động từ [AppTheme].
class ShopFilterBottomSheet extends StatefulWidget {
  final double? initialMinRating;
  final double? initialMaxDistanceKm;
  final ValueChanged<({double? minRating, double? maxDistanceKm})> onApply;
  final VoidCallback onClear;

  const ShopFilterBottomSheet({
    super.key,
    required this.initialMinRating,
    required this.initialMaxDistanceKm,
    required this.onApply,
    required this.onClear,
  });

  static Future<void> show(
    BuildContext context, {
    String? userId,
  }) async {
    final cubit = context.read<ShopDiscoveryCubit>();
    final current = cubit.state;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => ShopFilterBottomSheet(
        initialMinRating: current.minRatingFilter,
        initialMaxDistanceKm: current.maxDistanceKmFilter,
        onApply: (result) {
          cubit.applyFilters(
            minRating: result.minRating,
            maxDistanceKm: result.maxDistanceKm,
            userId: userId,
          );
        },
        onClear: () {
          cubit.clearFilters(userId: userId);
        },
      ),
    );
  }

  @override
  State<ShopFilterBottomSheet> createState() => _ShopFilterBottomSheetState();
}

class _ShopFilterBottomSheetState extends State<ShopFilterBottomSheet> {
  double? _selectedRating;
  late double _sliderDistanceKm;

  static const List<(String, double?)> _ratingOptions = [
    ('Tất cả', null),
    ('Từ 4.0 ⭐', 4.0),
    ('Từ 4.5 ⭐', 4.5),
    ('Từ 4.8 ⭐', 4.8),
    ('Từ 4.9 ⭐', 4.9),
  ];

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialMinRating;
    _sliderDistanceKm =
        (widget.initialMaxDistanceKm ?? 20.0).clamp(1.0, 20.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.appTextStyles;
    final kmLabel = _sliderDistanceKm.round();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: cs.primary,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bộ lọc tiệm cắt tóc',
                      style: ts.dialogTitle,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(
                '1. Lọc theo đánh giá',
                style: ts.cardTitle,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ratingOptions.map((opt) {
                  final (label, val) = opt;
                  final isSelected = _selectedRating == val;
                  return ChoiceChip(
                    label: Text(
                      label,
                      style: isSelected ? ts.bodySmallOnPrimary : ts.bodySmallStrong,
                    ),
                    selected: isSelected,
                    selectedColor: cs.primary,
                    backgroundColor: cs.surfaceContainer,
                    checkmarkColor: cs.onPrimary,
                    onSelected: (_) {
                      setState(() => _selectedRating = val);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '2. Khoảng cách tối đa',
                      style: ts.cardTitle,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '0 km – $kmLabel km',
                      style: ts.bodySmallPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.primaryContainer,
                  thumbColor: cs.primary,
                  overlayColor: cs.primaryContainer,
                  valueIndicatorColor: cs.primary,
                  valueIndicatorTextStyle: ts.captionOnPrimary,
                ),
                child: Slider(
                  value: _sliderDistanceKm,
                  min: 1.0,
                  max: 20.0,
                  divisions: 19,
                  label: '0 – $kmLabel km',
                  onChanged: (val) {
                    setState(() => _sliderDistanceKm = val.roundToDouble());
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1 km',
                      style: ts.captionMuted,
                    ),
                    Text(
                      'Lọc các quán từ 0 km đến mức đang chọn',
                      style: ts.captionMuted,
                    ),
                    Text(
                      '20 km',
                      style: ts.captionMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onClear();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                      label: Text(
                        'Xoá lọc',
                        style: ts.buttonLabelDanger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.onApply((
                          minRating: _selectedRating,
                          maxDistanceKm: _sliderDistanceKm.roundToDouble(),
                        ));
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: Text(
                        'Tìm kiếm',
                        style: ts.buttonLabel,
                      ),
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
}
