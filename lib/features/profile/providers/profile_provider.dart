import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';

// ── Model ─────────────────────────────────────────────────

class UserProfile {
  final String  id;
  final String  displayName;
  final String  email;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
  });

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id:          m['id'] as String,
        displayName: (m['display_name'] as String?) ?? '',
        email:       (m['email'] as String?) ?? '',
      );
}

// ── Provider ──────────────────────────────────────────────

final currentProfileProvider =
    FutureProvider.autoDispose<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final data = await supabase
      .from('profiles')
      .select()
      .eq('id', user.id)
      .single();

  return UserProfile.fromMap(data);
});

// ── Notifier ──────────────────────────────────────────────

class ProfileNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateDisplayName(String name) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('profiles').update({
        'display_name': name.trim(),
        'updated_at':   DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      ref.invalidate(currentProfileProvider);
    });
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, void>(ProfileNotifier.new);
