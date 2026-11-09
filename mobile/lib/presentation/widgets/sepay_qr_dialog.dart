import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/injection_container.dart';
import '../../core/network/socket_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/payment_transaction_entity.dart';
import '../../domain/repositories/shop_repository.dart';

/// Dialog hiển thị mã VietQR động tích hợp SePay Webhook + Socket.IO Realtime:
/// - Tự động đóng và trả về `true` ngay lập tức khi nhận sự kiện Socket.IO `payment.success`.
/// - Toàn bộ màu sắc & kiểu chữ kế thừa tự động từ [AppTheme].
class SepayQrDialog extends StatefulWidget {
  final String title;
  final PaymentTransactionEntity transaction;

  const SepayQrDialog({
    super.key,
    required this.title,
    required this.transaction,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required PaymentTransactionEntity transaction,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SepayQrDialog(title: title, transaction: transaction),
    );
    return res ?? false;
  }

  @override
  State<SepayQrDialog> createState() => _SepayQrDialogState();
}

class _SepayQrDialogState extends State<SepayQrDialog> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _simulating = false;

  @override
  void initState() {
    super.initState();
    _sub = sl<SocketService>().onPaymentSuccess.listen((event) {
      final code = (event['paymentCode'] ?? '').toString();
      if (code.isEmpty || code == widget.transaction.paymentCode) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _simulateWebhook() async {
    setState(() => _simulating = true);
    await sl<ShopRepository>().simulateSePayWebhook(
      widget.transaction.paymentCode,
    );
    if (mounted) {
      setState(() => _simulating = false);
    }
  }

  String get _resolvedQrImageUrl {
    final raw = widget.transaction.qrImageUrl.trim();
    if (raw.isNotEmpty && !raw.contains('img.vietqr.io')) {
      return raw;
    }
    final encodedDes = Uri.encodeComponent(widget.transaction.transferContent);
    return 'https://qr.sepay.vn/img?bank=${AppConstants.sepayBankCode}&acc=${AppConstants.platformBankAccount}&template=compact&amount=${widget.transaction.amount}&des=$encodedDes';
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.appTextStyles;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: ts.dialogTitle,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _resolvedQrImageUrl,
                      height: 220,
                      width: 220,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        width: 200,
                        color: cs.surface,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 110,
                              color: cs.primary,
                            ),
                            Text(
                              'VietQR SePay Dynamic',
                              style: ts.captionStrong,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppFormatters.formatVnd(widget.transaction.amount),
                    style: ts.priceLargePrimary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppConstants.platformBankName} • ${AppConstants.platformBankAccount}',
                    style: ts.bodySmallMuted,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Nội dung CK: ${widget.transaction.transferContent}',
                      style: ts.bodySmallPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Đang lắng nghe SePay Webhook qua Socket.IO...',
                    style: ts.captionMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _simulating ? null : _simulateWebhook,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: Text(
                  _simulating
                      ? 'Đang xử lý Webhook...'
                      : 'Giả lập SePay bắn Webhook thành công',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
