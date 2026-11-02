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
/// - Không cần chờ Admin hay chủ quán duyệt tay!
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceWhite,
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
                    color: AppTheme.primaryGreenLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
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
                color: AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E6ED)),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.transaction.qrImageUrl,
                      height: 220,
                      width: 220,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        width: 200,
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 110,
                              color: AppTheme.primaryGreen,
                            ),
                            Text(
                              'VietQR SePay Dynamic',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppFormatters.formatVnd(widget.transaction.amount),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '${AppConstants.platformBankName} • ${AppConstants.platformBankAccount}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Nội dung CK: ${widget.transaction.transferContent}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Đang lắng nghe SePay Webhook qua Socket.IO...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
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

