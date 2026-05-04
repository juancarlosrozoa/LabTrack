import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_provider.dart';
import '../../auth/providers/lab_provider.dart';

// ── Period selector ───────────────────────────────────────

enum ConsumptionPeriod { days7, days30, days90 }

extension ConsumptionPeriodX on ConsumptionPeriod {
  int get days => switch (this) {
        ConsumptionPeriod.days7  => 7,
        ConsumptionPeriod.days30 => 30,
        ConsumptionPeriod.days90 => 90,
      };

  String get label => switch (this) {
        ConsumptionPeriod.days7  => 'Last 7 days',
        ConsumptionPeriod.days30 => 'Last 30 days',
        ConsumptionPeriod.days90 => 'Last 90 days',
      };
}

final consumptionPeriodProvider =
    StateProvider.autoDispose<ConsumptionPeriod>(
        (ref) => ConsumptionPeriod.days30);

// ── Data model ────────────────────────────────────────────

class ProductConsumption {
  final String productId;
  final String productName;
  final String unit;
  final double totalConsumed;
  final int    movementCount;

  const ProductConsumption({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.totalConsumed,
    required this.movementCount,
  });
}

// ── Provider ──────────────────────────────────────────────

final consumptionReportProvider =
    FutureProvider.autoDispose<List<ProductConsumption>>((ref) async {
  final lab    = ref.watch(selectedLabProvider);
  final period = ref.watch(consumptionPeriodProvider);
  if (lab == null) return [];

  final db   = ref.watch(databaseProvider);
  final from = DateTime.now().subtract(Duration(days: period.days));
  final to   = DateTime.now();

  final exits =
      await db.movementsDao.getExitMovementsByPeriod(lab.labId, from, to);

  final map =
      <String, ({String name, String unit, double qty, int count})>{};

  for (final m in exits) {
    final product = await db.inventoryDao.getProductById(m.productId);
    final name    = product?.name ?? m.productId;
    final unit    = product?.unit ?? '';
    final existing = map[m.productId];
    map[m.productId] = existing == null
        ? (name: name, unit: unit, qty: m.quantity, count: 1)
        : (
            name:  existing.name,
            unit:  existing.unit,
            qty:   existing.qty + m.quantity,
            count: existing.count + 1,
          );
  }

  return map.entries
      .map((e) => ProductConsumption(
            productId:     e.key,
            productName:   e.value.name,
            unit:          e.value.unit,
            totalConsumed: e.value.qty,
            movementCount: e.value.count,
          ))
      .toList()
    ..sort((a, b) => b.totalConsumed.compareTo(a.totalConsumed));
});
