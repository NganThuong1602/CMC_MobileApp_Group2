import 'package:equatable/equatable.dart';

class ServiceEntity extends Equatable {
  final String id;
  final String shopId;
  final String name;
  final int price;
  final int durationMinutes;
  final String? imageUrl;

  const ServiceEntity({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, shopId, name, price, durationMinutes, imageUrl];
}

