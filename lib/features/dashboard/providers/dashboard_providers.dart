import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product_with_stock.dart';
import '../../auth/providers/lab_provider.dart';
import '../../inventory/providers/inventory_providers.dart';

// ── Dashboard summary derived from inventory stream ───────

class DashboardSummary {
  final List<ProductWithStock> criticalStock;
  final List<ProductWithStock> reorderNeeded;
  final List<ProductWithStock> expiringSoon;
  final List<ProductWithStock> allProducts;

  const DashboardSummary({
    required this.criticalStock,
    required this.reorderNeeded,
    required this.expiringSoon,
    required this.allProducts,
  });

  int  get totalProducts => allProducts.length;
  int  get alertCount    => criticalStock.length + expiringSoon.length;
  bool get hasAlerts     => alertCount > 0;
}

final dashboardProvider =
    StreamProvider.autoDispose<DashboardSummary>((ref) async* {
  final lab = ref.watch(selectedLabProvider);

  if (lab == null) {
    yield const DashboardSummary(
      criticalStock: [],
      reorderNeeded: [],
      expiringSoon:  [],
      allProducts:   [],
    );
    return;
  }

  // Watch inventory — re-emits whenever lots/products change
  await for (final inventoryAsync
      in Stream.periodic(const Duration(seconds: 1))
          .asyncMap((_) => ref.read(inventoryProvider.future))
          .distinct()) {
    yield _buildSummary(inventoryAsync);
  }
});

// Immediate snapshot — used for the first render before the stream ticks
final dashboardSnapshotProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) {
    return const DashboardSummary(
      criticalStock: [],
      reorderNeeded: [],
      expiringSoon:  [],
      allProducts:   [],
    );
  }
  final items = await ref.watch(inventoryProvider.future);
  return _buildSummary(items);
});

DashboardSummary _buildSummary(List<ProductWithStock> items) {
  return DashboardSummary(
    criticalStock: items
        .where((p) =>
            p.stockStatus == StockStatus.critical ||
            p.stockStatus == StockStatus.outOfStock)
        .toList(),
    reorderNeeded: items
        .where((p) => p.stockStatus == StockStatus.reorder)
        .toList(),
    expiringSoon:  items.where((p) => p.hasExpiringSoon).toList(),
    allProducts:   items,
  );
}
