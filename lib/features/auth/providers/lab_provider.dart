import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/lab_membership.dart';
import '../../../data/remote/supabase_client.dart';
import 'auth_provider.dart';

// ── Rename lab ────────────────────────────────────────────

class RenameLabNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> rename(String labId, String newName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase
          .from('laboratories')
          .update({'name': newName.trim()})
          .eq('id', labId);

      // Keep selectedLabProvider in sync
      final current = ref.read(selectedLabProvider);
      if (current != null && current.labId == labId) {
        ref.read(selectedLabProvider.notifier).state = LabMembership(
          labId:   current.labId,
          labName: newName.trim(),
          labSlug: current.labSlug,
          role:    current.role,
        );
      }
      ref.invalidate(userLabsProvider);
    });
  }
}

final renameLabProvider =
    AsyncNotifierProvider<RenameLabNotifier, void>(RenameLabNotifier.new);

// ── Create lab ────────────────────────────────────────────

class CreateLabNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<LabMembership> create(String name) async {
    state = const AsyncLoading();
    late LabMembership membership;
    state = await AsyncValue.guard(() async {
      final result = await supabase.rpc(
        'create_laboratory',
        params: {'p_name': name.trim()},
      ) as Map<String, dynamic>;

      if (result['error'] != null) throw Exception(result['error'] as String);

      membership = LabMembership(
        labId:   result['lab_id']   as String,
        labName: result['lab_name'] as String,
        labSlug: result['lab_slug'] as String,
        role:    LabRoleX.fromString(result['role'] as String),
      );
    });
    return membership;
  }
}

final createLabProvider =
    AsyncNotifierProvider<CreateLabNotifier, void>(CreateLabNotifier.new);

// ── All labs the current user belongs to ──────────────────

final userLabsProvider = FutureProvider<List<LabMembership>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final data = await supabase
      .from('lab_members')
      .select('lab_id, role, laboratories(name, slug)')
      .eq('user_id', user.id);

  return (data as List)
      .map((row) => LabMembership.fromMap(row as Map<String, dynamic>))
      .toList();
});

// ── Currently selected lab (persists for session) ─────────

final selectedLabProvider =
    StateProvider<LabMembership?>((ref) => null);

// ── Convenience: current lab role ─────────────────────────

final currentLabRoleProvider = Provider<LabRole?>((ref) {
  return ref.watch(selectedLabProvider)?.role;
});
