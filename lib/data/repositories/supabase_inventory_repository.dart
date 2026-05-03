import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import '../local/database_provider.dart';
import '../models/product.dart' as model;
import '../models/lot.dart' as model;
import '../remote/supabase_client.dart';
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
    await db.inventoryDao.upsertProduct(_productToCompanion(product));
    await supabase.from('products').upsert(_productToMap(product));
    unawaited(sync.syncAll());
    return product;
  }

  @override
  Future<model.Product> updateProduct(model.Product product) async {
    await db.inventoryDao.upsertProduct(_productToCompanion(product));
    await supabase.from('products').upsert(_productToMap(product));
    unawaited(sync.syncAll());
    return product;
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final existing = await db.inventoryDao.getProductById(productId);
    if (existing == null) return;
    await db.inventoryDao.softDeleteProduct(productId);
    await supabase
        .from('products')
        .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', productId);
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
        tracksLots:            row.tracksLots,
        directQuantity:        row.directQuantity,
        createdAt:             row.createdAt,
      );

  Map<String, dynamic> _productToMap(model.Product p) => {
        'id':                      p.id.isNotEmpty ? p.id : const Uuid().v4(),
        'lab_id':                  p.labId,
        'name':                    p.name,
        'barcode':                 p.barcode,
        'category_id':             p.categoryId,
        'unit':                    p.unit,
        'reorder_point':           p.reorderPoint,
        'minimum_stock':           p.minimumStock,
        'estimated_delivery_days': p.estimatedDeliveryDays,
        'default_location_id':     p.locationId,
        'supplier_id':             p.supplierId,
        'is_active':               p.isActive,
        'tracks_lots':             p.tracksLots,
        'direct_quantity':         p.directQuantity,
        'created_at':              p.createdAt.toIso8601String(),
        'updated_at':              DateTime.now().toIso8601String(),
      };

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
        tracksLots:            Value(p.tracksLots),
        directQuantity:        Value(p.directQuantity),
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
