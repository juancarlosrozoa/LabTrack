import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/remote/supabase_client.dart';
import '../../auth/providers/lab_provider.dart';

// ── Alert Config ──────────────────────────────────────────

class AlertConfig {
  final List<int> expiryAlertDays;
  final bool      reorderNotifications;
  final bool      criticalStockNotifications;

  const AlertConfig({
    required this.expiryAlertDays,
    required this.reorderNotifications,
    required this.criticalStockNotifications,
  });

  factory AlertConfig.defaults() => const AlertConfig(
        expiryAlertDays:            [30, 60, 90],
        reorderNotifications:       true,
        criticalStockNotifications: true,
      );

  factory AlertConfig.fromJson(Map<String, dynamic> json) => AlertConfig(
        expiryAlertDays: (json['expiry_alert_days'] as List)
            .map((e) => e as int)
            .toList(),
        reorderNotifications:
            json['reorder_notifications'] as bool? ?? true,
        criticalStockNotifications:
            json['critical_stock_notifications'] as bool? ?? true,
      );

  AlertConfig copyWith({
    List<int>? expiryAlertDays,
    bool?      reorderNotifications,
    bool?      criticalStockNotifications,
  }) =>
      AlertConfig(
        expiryAlertDays:            expiryAlertDays ?? this.expiryAlertDays,
        reorderNotifications:       reorderNotifications ?? this.reorderNotifications,
        criticalStockNotifications: criticalStockNotifications ?? this.criticalStockNotifications,
      );
}

final alertConfigProvider =
    AsyncNotifierProvider.autoDispose<AlertConfigNotifier, AlertConfig>(
        AlertConfigNotifier.new);

class AlertConfigNotifier extends AutoDisposeAsyncNotifier<AlertConfig> {
  @override
  Future<AlertConfig> build() async {
    final lab = ref.watch(selectedLabProvider);
    if (lab == null) return AlertConfig.defaults();

    final row = await supabase
        .from('alert_config')
        .select()
        .eq('lab_id', lab.labId)
        .isFilter('product_id', null)
        .maybeSingle();

    return row == null
        ? AlertConfig.defaults()
        : AlertConfig.fromJson(row);
  }

  Future<void> save(AlertConfig config) async {
    final lab = ref.read(selectedLabProvider);
    if (lab == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('alert_config').upsert(
        {
          'lab_id':                       lab.labId,
          'product_id':                   null,
          'expiry_alert_days':            config.expiryAlertDays,
          'reorder_notifications':        config.reorderNotifications,
          'critical_stock_notifications': config.criticalStockNotifications,
        },
        onConflict: 'lab_id,product_id',
      );
      return config;
    });
  }
}

// ── Suppliers ─────────────────────────────────────────────

class SupplierItem {
  final String  id;
  final String  name;
  final String? email;
  final String? phone;

  const SupplierItem({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });
}

final settingsSuppliersProvider =
    AsyncNotifierProvider.autoDispose<SuppliersNotifier, List<SupplierItem>>(
        SuppliersNotifier.new);

class SuppliersNotifier
    extends AutoDisposeAsyncNotifier<List<SupplierItem>> {
  AppDatabase get _db  => ref.read(databaseProvider);
  String?     get _lab => ref.read(selectedLabProvider)?.labId;

  @override
  Future<List<SupplierItem>> build() async {
    final lab = ref.watch(selectedLabProvider);
    if (lab == null) return [];

    final rows = await _db.inventoryDao.getSuppliers(lab.labId);
    return rows
        .map((r) => SupplierItem(
              id:    r.id,
              name:  r.name,
              email: r.contactEmail,
              phone: r.contactPhone,
            ))
        .toList();
  }

  Future<void> save(SupplierItem item) async {
    final labId = _lab;
    if (labId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Push to Supabase
      await supabase.from('suppliers').upsert({
        'id':            item.id,
        'lab_id':        labId,
        'name':          item.name,
        'contact_email': item.email,
        'contact_phone': item.phone,
      });

      // Write to Drift
      await _db.inventoryDao.upsertSupplier(SuppliersCompanion(
        id:           Value(item.id),
        labId:        Value(labId),
        name:         Value(item.name),
        contactEmail: Value(item.email),
        contactPhone: Value(item.phone),
        createdAt:    Value(DateTime.now()),
      ));

      return await _reload(labId);
    });
  }

  Future<void> delete(String supplierId) async {
    final labId = _lab;
    if (labId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('suppliers').delete().eq('id', supplierId);
      await _db.inventoryDao.deleteSupplierById(supplierId);
      return await _reload(labId);
    });
  }

  Future<List<SupplierItem>> _reload(String labId) async {
    final rows = await _db.inventoryDao.getSuppliers(labId);
    return rows
        .map((r) => SupplierItem(
              id:    r.id,
              name:  r.name,
              email: r.contactEmail,
              phone: r.contactPhone,
            ))
        .toList();
  }
}

// ── Storage Conditions ────────────────────────────────────

class StorageConditionItem {
  final String  id;
  final String  name;
  final double? tempMin;
  final double? tempMax;
  final double? humidityMax;
  final bool    lightSensitive;

  const StorageConditionItem({
    required this.id,
    required this.name,
    this.tempMin,
    this.tempMax,
    this.humidityMax,
    this.lightSensitive = false,
  });
}

final settingsStorageConditionsProvider = AsyncNotifierProvider.autoDispose<
    StorageConditionsNotifier,
    List<StorageConditionItem>>(StorageConditionsNotifier.new);

class StorageConditionsNotifier
    extends AutoDisposeAsyncNotifier<List<StorageConditionItem>> {
  AppDatabase get _db  => ref.read(databaseProvider);
  String?     get _lab => ref.read(selectedLabProvider)?.labId;

  @override
  Future<List<StorageConditionItem>> build() async {
    final lab = ref.watch(selectedLabProvider);
    if (lab == null) return [];
    return await _reload(lab.labId);
  }

  Future<void> save(StorageConditionItem item) async {
    final labId = _lab;
    if (labId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('storage_conditions').upsert({
        'id':              item.id,
        'lab_id':          labId,
        'name':            item.name,
        'temp_min':        item.tempMin,
        'temp_max':        item.tempMax,
        'humidity_max':    item.humidityMax,
        'light_sensitive': item.lightSensitive,
      });
      await _db.inventoryDao.upsertStorageCondition(
        StorageConditionsCompanion(
          id:             Value(item.id),
          labId:          Value(labId),
          name:           Value(item.name),
          tempMin:        Value(item.tempMin),
          tempMax:        Value(item.tempMax),
          humidityMax:    Value(item.humidityMax),
          lightSensitive: Value(item.lightSensitive),
          createdAt:      Value(DateTime.now()),
        ),
      );
      return await _reload(labId);
    });
  }

  Future<void> delete(String id) async {
    final labId = _lab;
    if (labId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('storage_conditions').delete().eq('id', id);
      await _db.inventoryDao.deleteStorageConditionById(id);
      return await _reload(labId);
    });
  }

  Future<List<StorageConditionItem>> _reload(String labId) async {
    final rows = await _db.inventoryDao.getStorageConditions(labId);
    return rows
        .map((r) => StorageConditionItem(
              id:             r.id,
              name:           r.name,
              tempMin:        r.tempMin,
              tempMax:        r.tempMax,
              humidityMax:    r.humidityMax,
              lightSensitive: r.lightSensitive,
            ))
        .toList();
  }
}

// ── Categories ────────────────────────────────────────────

class CategoryItem {
  final String id;
  final String name;
  const CategoryItem({required this.id, required this.name});
}

final settingsCategoriesProvider =
    AsyncNotifierProvider.autoDispose<CategoriesNotifier, List<CategoryItem>>(
        CategoriesNotifier.new);

class CategoriesNotifier
    extends AutoDisposeAsyncNotifier<List<CategoryItem>> {
  AppDatabase get _db  => ref.read(databaseProvider);
  String?     get _lab => ref.read(selectedLabProvider)?.labId;

  @override
  Future<List<CategoryItem>> build() async {
    final lab = ref.watch(selectedLabProvider);
    if (lab == null) return [];
    return await _reload(lab.labId);
  }

  Future<void> save(CategoryItem item) async {
    final labId = _lab;
    if (labId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('categories').upsert({
        'id':     item.id,
        'lab_id': labId,
        'name':   item.name,
      });
      await _db.inventoryDao.upsertCategory(CategoriesCompanion(
        id:        Value(item.id),
        labId:     Value(labId),
        name:      Value(item.name),
        createdAt: Value(DateTime.now()),
      ));
      return await _reload(labId);
    });
  }

  Future<void> delete(String categoryId) async {
    final labId = _lab;
    if (labId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('categories').delete().eq('id', categoryId);
      await _db.inventoryDao.deleteCategoryById(categoryId);
      return await _reload(labId);
    });
  }

  Future<List<CategoryItem>> _reload(String labId) async {
    final rows = await _db.inventoryDao.getCategories(labId);
    return rows.map((r) => CategoryItem(id: r.id, name: r.name)).toList();
  }
}

// ── Locations ─────────────────────────────────────────────

class LocationItem {
  final String id;
  final String name;
  const LocationItem({required this.id, required this.name});
}

final settingsLocationsProvider =
    AsyncNotifierProvider.autoDispose<LocationsNotifier, List<LocationItem>>(
        LocationsNotifier.new);

class LocationsNotifier
    extends AutoDisposeAsyncNotifier<List<LocationItem>> {
  AppDatabase get _db  => ref.read(databaseProvider);
  String?     get _lab => ref.read(selectedLabProvider)?.labId;

  @override
  Future<List<LocationItem>> build() async {
    final lab = ref.watch(selectedLabProvider);
    if (lab == null) return [];
    return await _reload(lab.labId);
  }

  Future<void> save(LocationItem item) async {
    final labId = _lab;
    if (labId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('locations').upsert({
        'id':     item.id,
        'lab_id': labId,
        'name':   item.name,
      });
      await _db.inventoryDao.upsertLocation(LocationsCompanion(
        id:        Value(item.id),
        labId:     Value(labId),
        name:      Value(item.name),
        createdAt: Value(DateTime.now()),
      ));
      return await _reload(labId);
    });
  }

  Future<void> delete(String locationId) async {
    final labId = _lab;
    if (labId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('locations').delete().eq('id', locationId);
      await _db.inventoryDao.deleteLocationById(locationId);
      return await _reload(labId);
    });
  }

  Future<List<LocationItem>> _reload(String labId) async {
    final rows = await _db.inventoryDao.getLocations(labId);
    return rows.map((r) => LocationItem(id: r.id, name: r.name)).toList();
  }
}

// ── Helper ─────────────────────────────────────────────────

String newId() => const Uuid().v4();
