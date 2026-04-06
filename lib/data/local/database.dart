import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';
import 'daos/inventory_dao.dart';
import 'daos/movements_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    StorageConditions,
    Locations,
    Suppliers,
    Products,
    Lots,
    Movements,
  ],
  daos: [InventoryDao, MovementsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // future migrations go here
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'labtrack_db');
}
