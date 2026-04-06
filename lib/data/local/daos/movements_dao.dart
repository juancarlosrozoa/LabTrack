import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'movements_dao.g.dart';

@DriftAccessor(tables: [Movements])
class MovementsDao extends DatabaseAccessor<AppDatabase>
    with _$MovementsDaoMixin {
  MovementsDao(super.db);

  /// Reactive stream of movements for a lab, newest first.
  Stream<List<Movement>> watchMovements(String labId, {int limit = 50}) =>
      (select(movements)
            ..where((m) => m.labId.equals(labId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
            ..limit(limit))
          .watch();

  Future<List<Movement>> getMovements(String labId, {int limit = 50}) =>
      (select(movements)
            ..where((m) => m.labId.equals(labId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
            ..limit(limit))
          .get();

  /// Movements not yet pushed to Supabase.
  Future<List<Movement>> getUnsynced() =>
      (select(movements)..where((m) => m.isSynced.equals(false))).get();

  Future<void> insertMovement(MovementsCompanion movement) =>
      into(movements).insert(movement);

  /// Marks a movement as synced after successful Supabase upload.
  Future<void> markSynced(String movementId) =>
      (update(movements)..where((m) => m.id.equals(movementId))).write(
        MovementsCompanion(
          isSynced: const Value(true),
          syncedAt: Value(DateTime.now()),
        ),
      );

  Future<void> upsertAllMovements(List<MovementsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(movements, rows));
}
