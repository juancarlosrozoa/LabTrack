import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product_with_stock.dart';
import '../../../data/remote/supabase_client.dart';
import '../../../data/repositories/supabase_inventory_repository.dart';
import '../../../data/sync/sync_service.dart';
import '../../auth/providers/lab_provider.dart';
import '../../inventory/providers/inventory_providers.dart';

// ── Count entry — one per product ────────────────────────

class CountEntry {
  final ProductWithStock item;
  final double?          counted;   // null = not yet counted

  const CountEntry({required this.item, this.counted});

  double get expected   => item.totalQuantity;
  double get difference => (counted ?? expected) - expected;
  bool   get hasCount   => counted != null;

  bool get hasDiscrepancy =>
      counted != null && (counted! - expected).abs() > 0.001;

  CountEntry withCount(double value) =>
      CountEntry(item: item, counted: value);
}

// ── Session state ─────────────────────────────────────────

enum CountSessionStatus { idle, inProgress, reviewing, completed }

class CountSession {
  final CountSessionStatus    status;
  final List<CountEntry>      entries;
  final DateTime?             startedAt;

  const CountSession({
    this.status   = CountSessionStatus.idle,
    this.entries  = const [],
    this.startedAt,
  });

  int get totalProducts  => entries.length;
  int get countedSoFar   => entries.where((e) => e.hasCount).length;
  int get remaining      => totalProducts - countedSoFar;
  bool get allCounted    => remaining == 0;

  List<CountEntry> get discrepancies =>
      entries.where((e) => e.hasDiscrepancy).toList();

  double get progress =>
      totalProducts == 0 ? 0 : countedSoFar / totalProducts;

  CountSession copyWith({
    CountSessionStatus? status,
    List<CountEntry>?   entries,
    DateTime?           startedAt,
  }) =>
      CountSession(
        status:    status    ?? this.status,
        entries:   entries   ?? this.entries,
        startedAt: startedAt ?? this.startedAt,
      );
}

// ── Notifier ──────────────────────────────────────────────

class WeeklyCountNotifier extends AsyncNotifier<CountSession> {
  @override
  FutureOr<CountSession> build() => const CountSession();

  /// Load all products and start a new session.
  Future<void> startSession() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final lab  = ref.read(selectedLabProvider);
      if (lab == null) throw Exception('No lab selected');

      final items = await ref.read(inventoryProvider.future);

      final entries = items
          .map((p) => CountEntry(item: p))
          .toList()
        ..sort((a, b) =>
            a.item.product.name.compareTo(b.item.product.name));

      return CountSession(
        status:    CountSessionStatus.inProgress,
        entries:   entries,
        startedAt: DateTime.now(),
      );
    });
  }

  /// Record the counted quantity for a product.
  void recordCount(String productId, double counted) {
    final session = state.value;
    if (session == null) return;

    final updated = session.entries.map((e) {
      if (e.item.product.id == productId) return e.withCount(counted);
      return e;
    }).toList();

    state = AsyncData(session.copyWith(entries: updated));
  }

  /// Move to the review step.
  void proceedToReview() {
    final session = state.value;
    if (session == null) return;
    state = AsyncData(
      session.copyWith(status: CountSessionStatus.reviewing),
    );
  }

  /// Approve all discrepancies — adjust lot quantities locally and remotely.
  Future<void> approveAdjustments() async {
    final session = state.value;
    if (session == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(inventoryRepositoryProvider)
          as SupabaseInventoryRepository;
      final sync = ref.read(syncServiceProvider);

      for (final entry in session.discrepancies) {
        final lot = entry.item.fefoLot;
        if (lot == null) continue;

        final delta  = entry.counted! - entry.expected;
        final newQty = (lot.quantity + delta).clamp(0.0, double.infinity);

        // 1. Update Drift locally (triggers inventoryProvider stream)
        await repo.db.inventoryDao.updateLotQuantity(lot.id, newQty);

        // 2. Push to Supabase directly so syncAll doesn't pull stale data
        await supabase.from('lots').update({
          'quantity':   newQty,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', lot.id);
      }

      // Sync remaining catalog/movements in background
      await sync.syncAll();

      return session.copyWith(status: CountSessionStatus.completed);
    });
  }

  void reset() => state = const AsyncData(CountSession());
}

final weeklyCountProvider =
    AsyncNotifierProvider<WeeklyCountNotifier, CountSession>(
        WeeklyCountNotifier.new);
