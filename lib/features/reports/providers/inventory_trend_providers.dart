import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../data/local/database_provider.dart';
import '../../auth/providers/lab_provider.dart';

// ── Data models ───────────────────────────────────────────

class ProductTrendRow {
  final String        productName;
  final String        unit;

  /// Quantities ordered oldest → newest. Null = product not counted that session.
  final List<double?> quantities;

  /// counted[oldest] - counted[newest]. Positive = consumed, negative = added.
  final double? inferredConsumption;

  const ProductTrendRow({
    required this.productName,
    required this.unit,
    required this.quantities,
    required this.inferredConsumption,
  });
}

class InventoryTrendData {
  /// Session dates ordered oldest → newest.
  final List<DateTime>        sessionDates;
  final List<ProductTrendRow> products;

  const InventoryTrendData({
    required this.sessionDates,
    required this.products,
  });

  bool get isEmpty => products.isEmpty;
}

// ── Provider ──────────────────────────────────────────────

final inventoryTrendProvider =
    FutureProvider.autoDispose<InventoryTrendData?>((ref) async {
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) return null;

  final db       = ref.watch(databaseProvider);
  final sessions = await db.countSessionDao.getSessionsForLab(lab.labId);
  if (sessions.isEmpty) return null;

  // Last 4 sessions, display oldest → newest
  final recent = sessions.take(4).toList().reversed.toList();

  // Load items per session
  final sessionItems = <String, List<InventoryCountSessionItem>>{};
  for (final s in recent) {
    sessionItems[s.id] =
        await db.countSessionDao.getItemsForSession(s.id);
  }

  // Collect all unique products across all sessions
  final productMeta = <String, ({String name, String unit})>{};
  for (final items in sessionItems.values) {
    for (final item in items) {
      productMeta[item.productId] =
          (name: item.productName, unit: item.unit);
    }
  }

  final rows = productMeta.entries.map((entry) {
    final quantities = recent.map((s) {
      final match = (sessionItems[s.id] ?? [])
          .where((i) => i.productId == entry.key)
          .firstOrNull;
      return match?.counted;
    }).toList();

    final nonNull = quantities.whereType<double>().toList();
    final consumption =
        nonNull.length >= 2 ? nonNull.first - nonNull.last : null;

    return ProductTrendRow(
      productName:         entry.value.name,
      unit:                entry.value.unit,
      quantities:          quantities,
      inferredConsumption: consumption,
    );
  }).toList()
    ..sort((a, b) => a.productName.compareTo(b.productName));

  return InventoryTrendData(
    sessionDates: recent.map((s) => s.countedAt).toList(),
    products:     rows,
  );
});
