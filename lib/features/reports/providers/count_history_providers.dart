import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart';
import '../../../data/local/database_provider.dart';
import '../../auth/providers/lab_provider.dart';

final countHistoryProvider =
    FutureProvider.autoDispose<List<InventoryCountSession>>((ref) async {
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) return [];
  final db = ref.watch(databaseProvider);
  return db.countSessionDao.getSessionsForLab(lab.labId);
});

final countSessionItemsProvider = FutureProvider.autoDispose
    .family<List<InventoryCountSessionItem>, String>((ref, sessionId) async {
  final db = ref.watch(databaseProvider);
  return db.countSessionDao.getItemsForSession(sessionId);
});
