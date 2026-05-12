import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show AuthState;

import '../../../data/remote/supabase_client.dart';

// ── Raw Supabase auth stream ───────────────────────────────

final authStateChangesProvider = StreamProvider<sb.AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// ── Current auth event (tracked for password-recovery redirect) ───

final authEventProvider = StateProvider<AuthChangeEvent?>((ref) => null);

/// Keep-alive listener that pumps auth events into [authEventProvider].
/// Watch this in the app root so it lives for the full app lifetime.
final authEventListenerProvider = Provider<void>((ref) {
  final sub = supabase.auth.onAuthStateChange.listen(
    (data) => ref.read(authEventProvider.notifier).state = data.event,
  );
  ref.onDispose(sub.cancel);
});

// ── Current user (null = not logged in) ───────────────────

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return supabase.auth.currentUser;
});

// ── Auth actions ───────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithPassword(
        email:    email.trim(),
        password: password,
      );
    });
  }

  /// Returns true if email confirmation is required (session not created yet).
  Future<bool> signUp(String email, String password, String displayName) async {
    state = const AsyncLoading();
    bool needsConfirmation = false;
    state = await AsyncValue.guard(() async {
      final res = await supabase.auth.signUp(
        email:    email.trim(),
        password: password,
        data:     {'full_name': displayName.trim()},
      );
      needsConfirmation = res.session == null;
    });
    return needsConfirmation;
  }

  Future<void> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'io.supabase.labtrack://reset-callback',
      );
    });
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    });
  }

  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.rpc('delete_own_account');
      await supabase.auth.signOut();
    });
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
