import 'package:equatable/equatable.dart';

enum AlertType { criticalStock, reorderPoint, expiringSoon, outOfStock }

class Alert extends Equatable {
  final String id;
  final String labId;
  final String productId;
  final AlertType type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const Alert({
    required this.id,
    required this.labId,
    required this.productId,
    required this.type,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
