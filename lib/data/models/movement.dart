import 'package:equatable/equatable.dart';

enum MovementType { entry, exit, adjustment, returnItem }

class Movement extends Equatable {
  final String id;
  final String labId;
  final String productId;
  final String? lotId;
  final MovementType type;
  final double quantity;
  final String? reason;
  final String? area;
  final String? project;
  final String userId;
  final DateTime createdAt;

  const Movement({
    required this.id,
    required this.labId,
    required this.productId,
    this.lotId,
    required this.type,
    required this.quantity,
    this.reason,
    this.area,
    this.project,
    required this.userId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
