import 'package:equatable/equatable.dart';

class PaymentTransactionEntity extends Equatable {
  final String id;
  final String userId;
  final String type; // REGISTER_SHOP | BUY_HIGHLIGHT | BOOKING_PAYMENT
  final int amount;
  final String paymentCode;
  final String transferContent;
  final String qrImageUrl;
  final String status; // PENDING | SUCCESS
  final String? referenceId;

  const PaymentTransactionEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.paymentCode,
    required this.transferContent,
    required this.qrImageUrl,
    required this.status,
    this.referenceId,
  });

  bool get isSuccess => status.toUpperCase() == 'SUCCESS';

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        amount,
        paymentCode,
        transferContent,
        qrImageUrl,
        status,
        referenceId,
      ];
}

