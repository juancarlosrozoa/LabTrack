import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';
import 'daos/inventory_dao.dart';
import 'daos/movements_dao.dart';
import 'daos/count_session_dao.dart';

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
    InventoryCountSessions,
    InventoryCountSessionItems,
  ],
  daos: [InventoryDao, MovementsDao, CountSessionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(products, products.tracksLots);
            await m.addColumn(products, products.directQuantity);
          }
          if (from < 3) {
            await m.createTable(inventoryCountSessions);
            await m.createTable(inventoryCountSessionItems);
          }
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'labtrack_db');
}
