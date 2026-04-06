import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/lab_membership.dart';
import '../../../data/remote/supabase_client.dart';
import 'auth_provider.dart';

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
