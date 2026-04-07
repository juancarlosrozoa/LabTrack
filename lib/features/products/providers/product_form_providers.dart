import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/product.dart';
import '../../../data/repositories/supabase_inventory_repository.dart';
import '../../auth/providers/lab_provider.dart';

// ── Dropdown data for the form ────────────────────────────

final categoriesProvider = FutureProvider.autoDispose((ref) async {
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) return [];
  final repo = ref.watch(inventoryRepositoryProvider)
      as SupabaseInventoryRepository;
  return repo.db.inventoryDao.getCategories(lab.labId);
});

final locationsProvider = FutureProvider.autoDispose((ref) async {
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) return [];
  final repo = ref.watch(inventoryRepositoryProvider)
      as SupabaseInventoryRepository;
  return repo.db.inventoryDao.getLocations(lab.labId);
});

final suppliersProvider = FutureProvider.autoDispose((ref) async {
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) return [];
  final repo = ref.watch(inventoryRepositoryProvider)
      as SupabaseInventoryRepository;
  return repo.db.inventoryDao.getSuppliers(lab.labId);
});

// ── Save product notifier ─────────────────────────────────

class SaveProductNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> save(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(inventoryRepositoryProvider);
      if (product.id.isEmpty) {
        await repo.createProduct(
          product.copyWith(id: const Uuid().v4()),
        );
      } else {
        await repo.updateProduct(product);
      }
    });
  }

  Future<void> delete(String productId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(inventoryRepositoryProvider).deleteProduct(productId);
    });
  }
}

final saveProductProvider =
    AsyncNotifierProvider<SaveProductNotifier, void>(SaveProductNotifier.new);
