import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String labId;
  final String name;
  final String? barcode;
  final String? categoryId;
  final String unit;
  final double reorderPoint;
  final double minimumStock;
  final int estimatedDeliveryDays;
  final String? locationId;
  final String? supplierId;
  final bool isActive;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.labId,
    required this.name,
    this.barcode,
    this.categoryId,
    required this.unit,
    required this.reorderPoint,
    required this.minimumStock,
    required this.estimatedDeliveryDays,
    this.locationId,
    this.supplierId,
    this.isActive = true,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
