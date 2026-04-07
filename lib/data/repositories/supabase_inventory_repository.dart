import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import '../local/database_provider.dart';
import '../models/product.dart' as model;
import '../models/lot.dart' as model;
import '../sync/sync_service.dart';
import 'inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return SupabaseInventoryRepository(
    db:   ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  );
});

class SupabaseInventoryRepository implements InventoryRepository {
  SupabaseInventoryRepository({required this.db, required this.sync});

  final AppDatabase db;
  final SyncService  sync;

  // ── Products ───────────────────────────────────────────

  @override
  Future<List<model.Product>> getProducts(String labId) async {
    final rows = await db.inventoryDao.getProducts(labId);
    return rows.map(productFromRow).toList();
  }

  @override
  Future<model.Product?> getProductByBarcode(String barcode) async {
    final row = await db.inventoryDao.getProductByBarcode(barcode);
    return row == null ? null : productFromRow(row);
  }

  @override
  Future<model.Product> createProduct(model.Product product) async {
    final companion = _productToCompanion(product);
    await db.inventoryDao.upsertProduct(companion);
    unawaited(sync.syncAll());
    return product;
  }

  @override
  Future<model.Product> updateProduct(model.Product product) async {
    final companion = _productToCompanion(product);
    await db.inventoryDao.upsertProduct(companion);
    unawaited(sync.syncAll());
    return product;
  }

  @override
  Future<void> deleteProduct(String productId) async {
    // Soft-delete: mark as inactive locally + push to Supabase
    final existing = await db.inventoryDao.getProductById(productId);
    if (existing == null) return;
    await db.inventoryDao.upsertProduct(
      ProductsCompanion(
        id:        Value(productId),
        isActive:  const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    unawaited(sync.syncAll());
  }

  // ── Lots ───────────────────────────────────────────────

  @override
  Future<List<model.Lot>> getLotsByProduct(String productId) async {
    final rows = await db.inventoryDao.getLotsByProduct(productId);
    return rows.map(lotFromRow).toList();
  }

  @override
  Future<model.Lot> createLot(model.Lot lot) async {
    await db.inventoryDao.upsertLot(_lotToCompanion(lot));
    unawaited(sync.syncAll());
    return lot;
  }

  @override
  Future<model.Lot> updateLot(model.Lot lot) async {
    await db.inventoryDao.upsertLot(_lotToCompanion(lot));
    unawaited(sync.syncAll());
    return lot;
  }

  // ── Queries ────────────────────────────────────────────

  @override
  Future<List<model.Product>> getRestockNeeded(String labId) async {
    final rows = await db.inventoryDao.getRestockNeeded(labId);
    return rows.map(productFromRow).toList();
  }

  @override
  Future<List<model.Lot>> getExpiringSoon(
    String labId, {
    int withinDays = 90,
  }) async {
    final rows = await db.inventoryDao.getExpiringSoon(
      labId,
      withinDays: withinDays,
    );
    return rows.map(lotFromRow).toList();
  }

  // ── Reactive streams (bonus — used directly by UI providers) ──

  Stream<List<model.Product>> watchProducts(String labId) =>
      db.inventoryDao
          .watchProducts(labId)
          .map((rows) => rows.map(productFromRow).toList());

  Stream<List<model.Lot>> watchLotsByProduct(String productId) =>
      db.inventoryDao
          .watchLotsByProduct(productId)
          .map((rows) => rows.map(lotFromRow).toList());

  // ── Mappers ────────────────────────────────────────────

  model.Product productFromRow(Product row) => model.Product(
        id:                    row.id,
        labId:                 row.labId,
        name:                  row.name,
        barcode:               row.barcode,
        categoryId:            row.categoryId,
        unit:                  row.unit,
        reorderPoint:          row.reorderPoint,
        minimumStock:          row.minimumStock,
        estimatedDeliveryDays: row.estimatedDeliveryDays,
        locationId:            row.defaultLocationId,
        supplierId:            row.supplierId,
        isActive:              row.isActive,
        createdAt:             row.createdAt,
      );

  ProductsCompanion _productToCompanion(model.Product p) => ProductsCompanion(
        id:                    Value(p.id.isNotEmpty ? p.id : const Uuid().v4()),
        labId:                 Value(p.labId),
        name:                  Value(p.name),
        barcode:               Value(p.barcode),
        categoryId:            Value(p.categoryId),
        unit:                  Value(p.unit),
        reorderPoint:          Value(p.reorderPoint),
        minimumStock:          Value(p.minimumStock),
        estimatedDeliveryDays: Value(p.estimatedDeliveryDays),
        defaultLocationId:     Value(p.locationId),
        supplierId:            Value(p.supplierId),
        isActive:              Value(p.isActive),
        createdAt:             Value(p.createdAt),
        updatedAt:             Value(DateTime.now()),
      );

  model.Lot lotFromRow(Lot row) => model.Lot(
        id:             row.id,
        productId:      row.productId,
        lotNumber:      row.lotNumber,
        quantity:       row.quantity,
        expirationDate: row.expirationDate,
        locationId:     row.locationId,
        createdAt:      row.createdAt,
      );

  LotsCompanion _lotToCompanion(model.Lot l) => LotsCompanion(
        id:             Value(l.id.isNotEmpty ? l.id : const Uuid().v4()),
        productId:      Value(l.productId),
        lotNumber:      Value(l.lotNumber),
        quantity:       Value(l.quantity),
        expirationDate: Value(l.expirationDate),
        locationId:     Value(l.locationId),
        createdAt:      Value(l.createdAt),
        updatedAt:      Value(DateTime.now()),
      );
}

// ignore: non_constant_identifier_names
void unawaited(Future<void> future) {
  future.ignore();
}
