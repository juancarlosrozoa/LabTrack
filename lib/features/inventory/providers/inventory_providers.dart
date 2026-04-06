import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product_with_stock.dart';
import '../../../data/repositories/supabase_inventory_repository.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/providers/lab_provider.dart';

// ── Raw stream of products + lots combined ────────────────

final inventoryProvider =
    StreamProvider.autoDispose<List<ProductWithStock>>((ref) async* {
  final lab  = ref.watch(selectedLabProvider);
  final repo = ref.watch(inventoryRepositoryProvider)
      as SupabaseInventoryRepository;

  if (lab == null) {
    yield [];
    return;
  }

  // Kick off a background sync when provider is first watched
  ref.read(syncServiceProvider).syncAll();

  await for (final products in repo.watchProducts(lab.labId)) {
    final withStock = <ProductWithStock>[];

    for (final product in products) {
      final lots = await repo.getLotsByProduct(product.id);
      final total = lots.fold(0.0, (sum, l) => sum + l.quantity);
      withStock.add(ProductWithStock(
        product:       product,
        totalQuantity: total,
        lots:          lots,
      ));
    }

    yield withStock;
  }
});

// ── Search filter ─────────────────────────────────────────

final inventorySearchProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredInventoryProvider =
    Provider.autoDispose<AsyncValue<List<ProductWithStock>>>((ref) {
  final query    = ref.watch(inventorySearchProvider).toLowerCase().trim();
  final async    = ref.watch(inventoryProvider);

  return async.whenData((items) {
    if (query.isEmpty) return items;
    return items
        .where((p) =>
            p.product.name.toLowerCase().contains(query) ||
            (p.product.barcode?.toLowerCase().contains(query) ?? false))
        .toList();
  });
});

// ── Single product detail ─────────────────────────────────

final productDetailProvider = StreamProvider.autoDispose
    .family<ProductWithStock?, String>((ref, productId) async* {
  final repo = ref.watch(inventoryRepositoryProvider)
      as SupabaseInventoryRepository;

  await for (final lots in repo.watchLotsByProduct(productId)) {
    final products = await repo.getProducts('');
    final product  = products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      yield null;
      return;
    }
    final total = lots.fold(0.0, (sum, l) => sum + l.quantity);
    yield ProductWithStock(product: product, totalQuantity: total, lots: lots);
  }
});
