import 'package:drift/drift.dart';

// ── Categories ────────────────────────────────────────────

class Categories extends Table {
  TextColumn get id     => text()();
  TextColumn get labId  => text()();
  TextColumn get name   => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Storage Conditions ────────────────────────────────────

class StorageConditions extends Table {
  TextColumn  get id             => text()();
  TextColumn  get labId          => text()();
  TextColumn  get name           => text()();
  RealColumn  get tempMin        => real().nullable()();
  RealColumn  get tempMax        => real().nullable()();
  RealColumn  get humidityMax    => real().nullable()();
  BoolColumn  get lightSensitive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt   => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Locations ─────────────────────────────────────────────

class Locations extends Table {
  TextColumn get id                   => text()();
  TextColumn get labId                => text()();
  TextColumn get name                 => text()();
  TextColumn get storageConditionId   => text().nullable()();
  DateTimeColumn get createdAt        => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Suppliers ─────────────────────────────────────────────

class Suppliers extends Table {
  TextColumn get id           => text()();
  TextColumn get labId        => text()();
  TextColumn get name         => text()();
  TextColumn get contactEmail => text().nullable()();
  TextColumn get contactPhone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Products ──────────────────────────────────────────────

class Products extends Table {
  TextColumn  get id                    => text()();
  TextColumn  get labId                 => text()();
  TextColumn  get name                  => text()();
  TextColumn  get barcode               => text().nullable()();
  TextColumn  get categoryId            => text().nullable()();
  TextColumn  get unit                  => text()();
  RealColumn  get reorderPoint          => real().withDefault(const Constant(0.0))();
  RealColumn  get minimumStock          => real().withDefault(const Constant(0.0))();
  IntColumn   get estimatedDeliveryDays => integer().withDefault(const Constant(7))();
  TextColumn  get defaultLocationId     => text().nullable()();
  TextColumn  get supplierId            => text().nullable()();
  BoolColumn  get isActive              => boolean().withDefault(const Constant(true))();
  BoolColumn  get tracksLots            => boolean().withDefault(const Constant(true))();
  RealColumn  get directQuantity        => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt          => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt          => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Lots ──────────────────────────────────────────────────

class Lots extends Table {
  TextColumn  get id             => text()();
  TextColumn  get productId      => text().references(Products, #id)();
  TextColumn  get lotNumber      => text()();
  RealColumn  get quantity       => real().withDefault(const Constant(0.0))();
  DateTimeColumn get expirationDate => dateTime()();
  TextColumn  get locationId     => text().nullable()();
  DateTimeColumn get createdAt   => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt   => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Movements ─────────────────────────────────────────────
// isSynced = false → pending upload to Supabase

class Movements extends Table {
  TextColumn  get id         => text()();
  TextColumn  get labId      => text()();
  TextColumn  get productId  => text().references(Products, #id)();
  TextColumn  get lotId      => text().nullable()();
  TextColumn  get type       => text()(); // entry | exit | adjustment | return
  RealColumn  get quantity   => real()();
  TextColumn  get reason     => text().nullable()();
  TextColumn  get area       => text().nullable()();
  TextColumn  get project    => text().nullable()();
  TextColumn  get userId     => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn  get isSynced   => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt  => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
