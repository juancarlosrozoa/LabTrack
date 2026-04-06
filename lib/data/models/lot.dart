import 'package:equatable/equatable.dart';

class Lot extends Equatable {
  final String id;
  final String productId;
  final String lotNumber;
  final double quantity;
  final DateTime expirationDate;
  final String? locationId;
  final DateTime createdAt;

  const Lot({
    required this.id,
    required this.productId,
    required this.lotNumber,
    required this.quantity,
    required this.expirationDate,
    this.locationId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
