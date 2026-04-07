import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/models/movement.dart' as model;
import '../../../data/sync/sync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/lab_provider.dart';

// ── Movement with product name ────────────────────────────

class MovementWithProduct {
  final Movement movement;
  final String   productName;

  const MovementWithProduct({
    required this.movement,
    required this.productName,
  });
}

// ── Movement list stream ───────────────────────────────────

final movementsProvider =
    StreamProvider.autoDispose<List<MovementWithProduct>>((ref) async* {
  final db  = ref.watch(databaseProvider);
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) return;

  await for (final movements in db.movementsDao.watchMovements(lab.labId)) {
    final withNames = <MovementWithProduct>[];
    for (final m in movements) {
      final product = await db.inventoryDao.getProductById(m.productId);
      withNames.add(MovementWithProduct(
        movement:    m,
        productName: product?.name ?? m.productId,
      ));
    }
    yield withNames;
  }
});

// ── Register movement notifier ────────────────────────────

class RegisterMovementNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> register({
    required String              productId,
    required String?             lotId,
    required model.MovementType  type,
    required double              quantity,
    String?                      reason,
    String?                      area,
    String?                      project,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db     = ref.read(databaseProvider);
      final lab    = ref.read(selectedLabProvider);
      final user   = ref.read(currentUserProvider);

      if (lab == null || user == null) {
        throw Exception('Not authenticated');
      }

      final movement = MovementsCompanion(
        id:        drift.Value(const Uuid().v4()),
        labId:     drift.Value(lab.labId),
        productId: drift.Value(productId),
        lotId:     drift.Value(lotId),
        type:      drift.Value(type.name),
        quantity:  drift.Value(quantity),
        reason:    drift.Value(reason),
        area:      drift.Value(area),
        project:   drift.Value(project),
        userId:    drift.Value(user.id),
        isSynced:  const drift.Value(false),
      );

      await db.movementsDao.insertMovement(movement);

      // Apply to lot quantity locally
      if (lotId != null) {
        final lots = await db.inventoryDao.getLotsByProduct(productId);
        final lot  = lots.where((l) => l.id == lotId).firstOrNull;
        if (lot != null) {
          double newQty = switch (type) {
            model.MovementType.entry      => lot.quantity + quantity,
            model.MovementType.exit       => lot.quantity - quantity,
            model.MovementType.adjustment => lot.quantity + quantity,
            model.MovementType.returnItem => lot.quantity + quantity,
          };
          if (newQty < 0) throw Exception('Insufficient stock in this lot');
          await db.inventoryDao.updateLotQuantity(lotId, newQty);
        }
      }

      // Push to Supabase in background
      await ref.read(syncServiceProvider).pushPending();
    });
  }
}

final registerMovementProvider =
    AsyncNotifierProvider<RegisterMovementNotifier, void>(
        RegisterMovementNotifier.new);
