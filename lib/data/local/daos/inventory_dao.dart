import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'inventory_dao.g.dart';

@DriftAccessor(tables: [Products, Lots, Categories, Locations, Suppliers, StorageConditions])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  // ── Products ───────────────────────────────────────────

  /// Reactive stream of all active products for a lab, ordered by name.
  Stream<List<Product>> watchProducts(String labId) => (select(products)
        ..where((p) => p.labId.equals(labId) & p.isActive.equals(true))
        ..orderBy([(p) => OrderingTerm.asc(p.name)]))
      .watch();

  Future<List<Product>> getProducts(String labId) => (select(products)
        ..where((p) => p.labId.equals(labId) & p.isActive.equals(true))
        ..orderBy([(p) => OrderingTerm.asc(p.name)]))
      .get();

  Future<Product?> getProductByBarcode(String barcode) =>
      (select(products)..where((p) => p.barcode.equals(barcode)))
          .getSingleOrNull();

  Future<Product?> getProductById(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<void> upsertProduct(ProductsCompanion product) =>
      into(products).insertOnConflictUpdate(product);

  Future<void> upsertAllProducts(List<ProductsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(products, rows));

  // ── Lots ───────────────────────────────────────────────

  /// Reactive stream of lots for a product, FEFO order (earliest expiry first).
  Stream<List<Lot>> watchLotsByProduct(String productId) =>
      (select(lots)
            ..where((l) => l.productId.equals(productId))
            ..orderBy([(l) => OrderingTerm.asc(l.expirationDate)]))
          .watch();

  Future<List<Lot>> getLotsByProduct(String productId) =>
      (select(lots)
            ..where((l) => l.productId.equals(productId))
            ..orderBy([(l) => OrderingTerm.asc(l.expirationDate)]))
          .get();

  /// Lots expiring within [withinDays] days across the whole lab.
  Future<List<Lot>> getExpiringSoon(String labId, {int withinDays = 90}) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays));
    final labProducts = await getProducts(labId);
    final productIds = labProducts.map((p) => p.id).toList();
    if (productIds.isEmpty) return [];

    return (select(lots)
          ..where(
            (l) =>
                l.productId.isIn(productIds) &
                l.expirationDate.isSmallerOrEqualValue(cutoff) &
                l.quantity.isBiggerThanValue(0),
          )
          ..orderBy([(l) => OrderingTerm.asc(l.expirationDate)]))
        .get();
  }

  /// Reactive stream of active products joined with their lots.
  /// Emits whenever either the products or lots table changes.
  Stream<List<({Product product, List<Lot> lots})>> watchProductsWithLots(
      String labId) {
    return (select(products)
          ..where((p) => p.labId.equals(labId) & p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .join([leftOuterJoin(lots, lots.productId.equalsExp(products.id))])
        .watch()
        .map((rows) {
          final productOrder = <String>[];
          final productMap   = <String, Product>{};
          final lotsMap      = <String, List<Lot>>{};

          for (final row in rows) {
            final product = row.readTable(products);
            final lot     = row.readTableOrNull(lots);
            if (!productMap.containsKey(product.id)) {
              productOrder.add(product.id);
              productMap[product.id] = product;
            }
            if (lot != null) {
              lotsMap.putIfAbsent(product.id, () => []).add(lot);
            }
          }

          return productOrder
              .map((id) => (
                    product: productMap[id]!,
                    lots:    lotsMap[id] ?? <Lot>[],
                  ))
              .toList();
        });
  }

  Future<void> upsertLot(LotsCompanion lot) =>
      into(lots).insertOnConflictUpdate(lot);

  Future<void> upsertAllLots(List<LotsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(lots, rows));

  /// Updates lot quantity directly (called after applying a local movement).
  Future<void> updateLotQuantity(String lotId, double newQuantity) =>
      (update(lots)..where((l) => l.id.equals(lotId))).write(
        LotsCompanion(
          quantity:  Value(newQuantity),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateDirectQuantity(String productId, double newQuantity) =>
      (update(products)..where((p) => p.id.equals(productId))).write(
        ProductsCompanion(
          directQuantity: Value(newQuantity),
          updatedAt:      Value(DateTime.now()),
        ),
      );

  Future<void> softDeleteProduct(String productId) =>
      (update(products)..where((p) => p.id.equals(productId))).write(
        ProductsCompanion(
          isActive:  const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ── Total stock per product ────────────────────────────

  Future<double> getTotalStock(String productId) async {
    final lotList = await getLotsByProduct(productId);
    return lotList.fold<double>(0.0, (sum, l) => sum + l.quantity);
  }

  /// Returns products at or below their reorder point.
  Future<List<Product>> getRestockNeeded(String labId) async {
    final all = await getProducts(labId);
    final result = <Product>[];
    for (final p in all) {
      final stock = await getTotalStock(p.id);
      if (stock <= p.reorderPoint) result.add(p);
    }
    return result;
  }

  // ── Storage Conditions ─────────────────────────────────

  Future<List<StorageCondition>> getStorageConditions(String labId) =>
      (select(storageConditions)
            ..where((s) => s.labId.equals(labId))
            ..orderBy([(s) => OrderingTerm.asc(s.name)]))
          .get();

  Future<void> upsertStorageCondition(StorageConditionsCompanion row) =>
      into(storageConditions).insertOnConflictUpdate(row);

  Future<void> deleteStorageConditionById(String id) =>
      (delete(storageConditions)..where((s) => s.id.equals(id))).go();

  // ── Categories ─────────────────────────────────────────

  Future<List<Category>> getCategories(String labId) =>
      (select(categories)
            ..where((c) => c.labId.equals(labId))
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .get();

  Future<void> upsertAllCategories(List<CategoriesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(categories, rows));

  Future<void> upsertCategory(CategoriesCompanion row) =>
      into(categories).insertOnConflictUpdate(row);

  Future<void> deleteCategoryById(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  // ── Locations ──────────────────────────────────────────

  Future<List<Location>> getLocations(String labId) =>
      (select(locations)
            ..where((l) => l.labId.equals(labId))
            ..orderBy([(l) => OrderingTerm.asc(l.name)]))
          .get();

  Future<void> upsertAllLocations(List<LocationsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(locations, rows));

  Future<void> upsertLocation(LocationsCompanion row) =>
      into(locations).insertOnConflictUpdate(row);

  Future<void> deleteLocationById(String id) =>
      (delete(locations)..where((l) => l.id.equals(id))).go();

  // ── Suppliers ──────────────────────────────────────────

  Future<List<Supplier>> getSuppliers(String labId) =>
      (select(suppliers)
            ..where((s) => s.labId.equals(labId))
            ..orderBy([(s) => OrderingTerm.asc(s.name)]))
          .get();

  Future<void> upsertAllSuppliers(List<SuppliersCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(suppliers, rows));

  Future<void> upsertSupplier(SuppliersCompanion row) =>
      into(suppliers).insertOnConflictUpdate(row);

  Future<void> deleteSupplierById(String id) =>
      (delete(suppliers)..where((s) => s.id.equals(id))).go();
}
