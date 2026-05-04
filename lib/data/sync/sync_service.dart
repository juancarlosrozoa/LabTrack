import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../local/database_provider.dart';
import '../remote/supabase_client.dart';
import '../../features/auth/providers/lab_provider.dart';

// ── Provider ──────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  final db  = ref.watch(databaseProvider);
  final lab = ref.watch(selectedLabProvider);
  return SyncService(db: db, labId: lab?.labId);
});

// ── Service ───────────────────────────────────────────────

class SyncService {
  SyncService({required this.db, required this.labId});

  final AppDatabase db;
  final String?     labId;

  /// Full sync: push unsynced local → remote, then pull remote → local.
  Future<void> syncAll() async {
    if (labId == null) return;
    if (!await _isOnline()) return;

    // Push first so Supabase triggers run before we pull updated data
    await _pushLocalProducts();
    await _pushUnsyncedMovements();
    await _pushCountSessions();

    await Future.wait([
      _pullCatalog(),   // categories, locations, suppliers
      _pullProducts(),
      _pullLots(),
      _pullMovements(),
      _pullCountSessions(),
    ]);
  }

  /// Push only — used right after registering a local movement.
  Future<void> pushPending() async {
    if (!await _isOnline()) return;
    await _pushUnsyncedMovements();
  }

  // ── Pull ────────────────────────────────────────────────

  Future<void> _pullCatalog() async {
    final results = await Future.wait([
      supabase.from('categories').select().eq('lab_id', labId!),
      supabase.from('locations').select().eq('lab_id', labId!),
      supabase.from('suppliers').select().eq('lab_id', labId!),
    ]);

    final cats  = results[0] as List;
    final locs  = results[1] as List;
    final sups  = results[2] as List;

    await db.inventoryDao.upsertAllCategories(
      cats.map(_rowToCategory).toList(),
    );
    await db.inventoryDao.upsertAllLocations(
      locs.map(_rowToLocation).toList(),
    );
    await db.inventoryDao.upsertAllSuppliers(
      sups.map(_rowToSupplier).toList(),
    );
  }

  Future<void> _pullProducts() async {
    final rows = await supabase
        .from('products')
        .select()
        .eq('lab_id', labId!)
        .eq('is_active', true) as List;

    await db.inventoryDao.upsertAllProducts(
      rows.map(_rowToProduct).toList(),
    );
  }

  Future<void> _pullLots() async {
    // Pull lots for all products in this lab via join
    final rows = await supabase
        .from('lots')
        .select('*, products!inner(lab_id)')
        .eq('products.lab_id', labId!) as List;

    await db.inventoryDao.upsertAllLots(
      rows.map(_rowToLot).toList(),
    );
  }

  Future<void> _pullMovements() async {
    final rows = await supabase
        .from('movements')
        .select()
        .eq('lab_id', labId!)
        .order('created_at', ascending: false)
        .limit(200) as List;

    await db.movementsDao.upsertAllMovements(
      rows.map(_rowToMovement).toList(),
    );
  }

  // ── Push ────────────────────────────────────────────────

  Future<void> _pushLocalProducts() async {
    final products = await db.inventoryDao.getProducts(labId!);
    if (products.isEmpty) return;

    final rows = products.map((p) => {
      'id':                      p.id,
      'lab_id':                  p.labId,
      'name':                    p.name,
      'barcode':                 p.barcode,
      'category_id':             p.categoryId,
      'unit':                    p.unit,
      'reorder_point':           p.reorderPoint,
      'minimum_stock':           p.minimumStock,
      'estimated_delivery_days': p.estimatedDeliveryDays,
      'default_location_id':     p.defaultLocationId,
      'supplier_id':             p.supplierId,
      'is_active':               p.isActive,
      'tracks_lots':             p.tracksLots,
      'direct_quantity':         p.directQuantity,
      'created_at':              p.createdAt.toIso8601String(),
      'updated_at':              p.updatedAt.toIso8601String(),
    }).toList();

    try {
      await supabase.from('products').upsert(rows);
    } catch (_) {
      // Leave for next sync if it fails
    }
  }

  Future<void> _pushUnsyncedMovements() async {
    final pending = await db.movementsDao.getUnsynced();
    if (pending.isEmpty) return;

    for (final m in pending) {
      try {
        await supabase.from('movements').upsert({
          'id':         m.id,
          'lab_id':     m.labId,
          'product_id': m.productId,
          'lot_id':     m.lotId,
          'type':       m.type,
          'quantity':   m.quantity,
          'reason':     m.reason,
          'area':       m.area,
          'project':    m.project,
          'user_id':    m.userId,
          'created_at': m.createdAt.toIso8601String(),
        });
        await db.movementsDao.markSynced(m.id);
      } catch (_) {
        // Leave as unsynced — will retry on next sync
      }
    }
  }

  // ── Count sessions ──────────────────────────────────────

  Future<void> _pushCountSessions() async {
    final sessions = await db.countSessionDao.getSessionsForLab(labId!);
    if (sessions.isEmpty) return;

    try {
      await supabase.from('count_sessions').upsert(
        sessions.map((s) => {
          'id':                s.id,
          'lab_id':            s.labId,
          'counted_at':        s.countedAt.toIso8601String(),
          'total_counted':     s.totalCounted,
          'discrepancy_count': s.discrepancyCount,
        }).toList(),
      );

      for (final s in sessions) {
        final items = await db.countSessionDao.getItemsForSession(s.id);
        if (items.isEmpty) continue;
        await supabase.from('count_session_items').upsert(
          items.map((i) => {
            'id':           i.id,
            'session_id':   i.sessionId,
            'product_id':   i.productId,
            'product_name': i.productName,
            'unit':         i.unit,
            'expected':     i.expected,
            'counted':      i.counted,
          }).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _pullCountSessions() async {
    final sessionRows = await supabase
        .from('count_sessions')
        .select()
        .eq('lab_id', labId!)
        .order('counted_at', ascending: false)
        .limit(100) as List;

    if (sessionRows.isEmpty) return;

    await db.countSessionDao.batchUpsertSessions(
      sessionRows.map(_rowToCountSession).toList(),
    );

    for (final row in sessionRows) {
      final sessionId = row['id'] as String;
      final itemRows  = await supabase
          .from('count_session_items')
          .select()
          .eq('session_id', sessionId) as List;

      if (itemRows.isEmpty) continue;
      await db.countSessionDao.batchUpsertSessionItems(
        itemRows.map(_rowToCountSessionItem).toList(),
      );
    }
  }

  InventoryCountSessionsCompanion _rowToCountSession(dynamic row) =>
      InventoryCountSessionsCompanion(
        id:               Value(row['id'] as String),
        labId:            Value(row['lab_id'] as String),
        countedAt:        Value(DateTime.parse(row['counted_at'] as String)),
        totalCounted:     Value(row['total_counted'] as int),
        discrepancyCount: Value(row['discrepancy_count'] as int),
      );

  InventoryCountSessionItemsCompanion _rowToCountSessionItem(dynamic row) =>
      InventoryCountSessionItemsCompanion(
        id:          Value(row['id'] as String),
        sessionId:   Value(row['session_id'] as String),
        productId:   Value(row['product_id'] as String),
        productName: Value(row['product_name'] as String),
        unit:        Value(row['unit'] as String),
        expected:    Value((row['expected'] as num).toDouble()),
        counted:     Value((row['counted'] as num).toDouble()),
      );

  // ── Connectivity ────────────────────────────────────────

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  // ── Row mappers ─────────────────────────────────────────

  CategoriesCompanion _rowToCategory(dynamic row) => CategoriesCompanion(
        id:        Value(row['id'] as String),
        labId:     Value(row['lab_id'] as String),
        name:      Value(row['name'] as String),
        createdAt: Value(DateTime.parse(row['created_at'] as String)),
      );

  LocationsCompanion _rowToLocation(dynamic row) => LocationsCompanion(
        id:                 Value(row['id'] as String),
        labId:              Value(row['lab_id'] as String),
        name:               Value(row['name'] as String),
        storageConditionId: Value(row['storage_condition_id'] as String?),
        createdAt:          Value(DateTime.parse(row['created_at'] as String)),
      );

  SuppliersCompanion _rowToSupplier(dynamic row) => SuppliersCompanion(
        id:           Value(row['id'] as String),
        labId:        Value(row['lab_id'] as String),
        name:         Value(row['name'] as String),
        contactEmail: Value(row['contact_email'] as String?),
        contactPhone: Value(row['contact_phone'] as String?),
        createdAt:    Value(DateTime.parse(row['created_at'] as String)),
      );

  ProductsCompanion _rowToProduct(dynamic row) => ProductsCompanion(
        id:                    Value(row['id'] as String),
        labId:                 Value(row['lab_id'] as String),
        name:                  Value(row['name'] as String),
        barcode:               Value(row['barcode'] as String?),
        categoryId:            Value(row['category_id'] as String?),
        unit:                  Value(row['unit'] as String),
        reorderPoint:          Value((row['reorder_point'] as num).toDouble()),
        minimumStock:          Value((row['minimum_stock'] as num).toDouble()),
        estimatedDeliveryDays: Value(row['estimated_delivery_days'] as int),
        defaultLocationId:     Value(row['default_location_id'] as String?),
        supplierId:            Value(row['supplier_id'] as String?),
        isActive:              Value(row['is_active'] as bool),
        tracksLots:            Value(row['tracks_lots'] as bool? ?? true),
        directQuantity:        Value((row['direct_quantity'] as num?)?.toDouble() ?? 0.0),
        createdAt:             Value(DateTime.parse(row['created_at'] as String)),
        updatedAt:             Value(DateTime.parse(row['updated_at'] as String)),
      );

  LotsCompanion _rowToLot(dynamic row) => LotsCompanion(
        id:             Value(row['id'] as String),
        productId:      Value(row['product_id'] as String),
        lotNumber:      Value(row['lot_number'] as String),
        quantity:       Value((row['quantity'] as num).toDouble()),
        expirationDate: Value(DateTime.parse(row['expiration_date'] as String)),
        locationId:     Value(row['location_id'] as String?),
        createdAt:      Value(DateTime.parse(row['created_at'] as String)),
        updatedAt:      Value(DateTime.parse(row['updated_at'] as String)),
      );

  MovementsCompanion _rowToMovement(dynamic row) => MovementsCompanion(
        id:        Value(row['id'] as String),
        labId:     Value(row['lab_id'] as String),
        productId: Value(row['product_id'] as String),
        lotId:     Value(row['lot_id'] as String?),
        type:      Value(row['type'] as String),
        quantity:  Value((row['quantity'] as num).toDouble()),
        reason:    Value(row['reason'] as String?),
        area:      Value(row['area'] as String?),
        project:   Value(row['project'] as String?),
        userId:    Value(row['user_id'] as String),
        createdAt: Value(DateTime.parse(row['created_at'] as String)),
        isSynced:  const Value(true), // came from remote → already synced
      );
}

// ── Connectivity watcher provider ─────────────────────────

/// Emits a sync whenever the device comes back online.
final connectivitySyncProvider = StreamProvider.autoDispose<void>((ref) async* {
  await for (final result in Connectivity().onConnectivityChanged) {
    if (result.any((r) => r != ConnectivityResult.none)) {
      await ref.read(syncServiceProvider).syncAll();
      yield null;
    }
  }
});
