import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show AuthState;

import '../../../data/remote/supabase_client.dart';

// ── Raw Supabase auth stream ───────────────────────────────

final authStateChangesProvider = StreamProvider<sb.AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// ── Current user (null = not logged in) ───────────────────

final currentUserProvider = Provider<User?>((ref) {
  // Listen to stream so provider invalidates on auth changes
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

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
