import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables.dart';

part 'count_session_dao.g.dart';

@DriftAccessor(tables: [InventoryCountSessions, InventoryCountSessionItems])
class CountSessionDao extends DatabaseAccessor<AppDatabase>
    with _$CountSessionDaoMixin {
  CountSessionDao(super.db);

  Future<void> saveSession({
    required String labId,
    required DateTime countedAt,
    required int totalCounted,
    required int discrepancyCount,
    required List<({
      String productId,
      String productName,
      String unit,
      double expected,
      double counted,
    })> items,
  }) async {
    final sessionId = const Uuid().v4();

    await into(inventoryCountSessions).insert(
      InventoryCountSessionsCompanion(
        id:               Value(sessionId),
        labId:            Value(labId),
        countedAt:        Value(countedAt),
        totalCounted:     Value(totalCounted),
        discrepancyCount: Value(discrepancyCount),
      ),
    );

    if (items.isEmpty) return;

    await batch((b) => b.insertAll(
          inventoryCountSessionItems,
          items
              .map((i) => InventoryCountSessionItemsCompanion(
                    id:          Value(const Uuid().v4()),
                    sessionId:   Value(sessionId),
                    productId:   Value(i.productId),
                    productName: Value(i.productName),
                    unit:        Value(i.unit),
                    expected:    Value(i.expected),
                    counted:     Value(i.counted),
                  ))
              .toList(),
        ));
  }

  Future<List<InventoryCountSession>> getSessionsForLab(String labId) =>
      (select(inventoryCountSessions)
            ..where((s) => s.labId.equals(labId))
            ..orderBy([(s) => OrderingTerm.desc(s.countedAt)]))
          .get();

  Future<List<InventoryCountSessionItem>> getItemsForSession(
          String sessionId) =>
      (select(inventoryCountSessionItems)
            ..where((i) => i.sessionId.equals(sessionId))
            ..orderBy([(i) => OrderingTerm.asc(i.productName)]))
          .get();

  Future<void> batchUpsertSessions(
          List<InventoryCountSessionsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(inventoryCountSessions, rows));

  Future<void> batchUpsertSessionItems(
          List<InventoryCountSessionItemsCompanion> rows) =>
      batch((b) =>
          b.insertAllOnConflictUpdate(inventoryCountSessionItems, rows));
}
