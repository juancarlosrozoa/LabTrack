import 'package:equatable/equatable.dart';

import 'product.dart';
import 'lot.dart';

enum StockStatus { ok, reorder, critical, outOfStock }

extension StockStatusX on StockStatus {
  String get label => switch (this) {
        StockStatus.ok         => 'OK',
        StockStatus.reorder    => 'Reorder',
        StockStatus.critical   => 'Critical',
        StockStatus.outOfStock => 'Out of Stock',
      };
}

class ProductWithStock extends Equatable {
  final Product     product;
  final double      totalQuantity;
  final List<Lot>   lots;

  const ProductWithStock({
    required this.product,
    required this.totalQuantity,
    required this.lots,
  });

  StockStatus get stockStatus {
    if (totalQuantity <= 0)                          return StockStatus.outOfStock;
    if (totalQuantity <= product.minimumStock)       return StockStatus.critical;
    if (totalQuantity <= product.reorderPoint)       return StockStatus.reorder;
    return StockStatus.ok;
  }

  /// Nearest expiring lot with quantity > 0 (FEFO)
  Lot? get nextExpiring {
    final active = lots.where((l) => l.quantity > 0).toList()
      ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
    return active.isEmpty ? null : active.first;
  }

  Lot? get fefoLot => nextExpiring;

  int? get daysUntilNextExpiry {
    final lot = fefoLot;
    if (lot == null) return null;
    return lot.expirationDate.difference(DateTime.now()).inDays;
  }

  bool get hasExpiringSoon =>
      daysUntilNextExpiry != null && daysUntilNextExpiry! <= 30;

  @override
  List<Object?> get props => [product.id, totalQuantity];
}
