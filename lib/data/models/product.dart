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

  Product copyWith({
    String?   id,
    String?   labId,
    String?   name,
    String?   barcode,
    String?   categoryId,
    String?   unit,
    double?   reorderPoint,
    double?   minimumStock,
    int?      estimatedDeliveryDays,
    String?   locationId,
    String?   supplierId,
    bool?     isActive,
    DateTime? createdAt,
  }) =>
      Product(
        id:                    id                    ?? this.id,
        labId:                 labId                 ?? this.labId,
        name:                  name                  ?? this.name,
        barcode:               barcode               ?? this.barcode,
        categoryId:            categoryId            ?? this.categoryId,
        unit:                  unit                  ?? this.unit,
        reorderPoint:          reorderPoint          ?? this.reorderPoint,
        minimumStock:          minimumStock          ?? this.minimumStock,
        estimatedDeliveryDays: estimatedDeliveryDays ?? this.estimatedDeliveryDays,
        locationId:            locationId            ?? this.locationId,
        supplierId:            supplierId            ?? this.supplierId,
        isActive:              isActive              ?? this.isActive,
        createdAt:             createdAt             ?? this.createdAt,
      );

  @override
  List<Object?> get props => [id];
}
