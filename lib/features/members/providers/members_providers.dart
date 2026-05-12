import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/lab_membership.dart';
import '../../../data/remote/supabase_client.dart';
import '../../auth/providers/lab_provider.dart';

// ── Models ────────────────────────────────────────────────

class LabMemberProfile {
  final String   userId;
  final String   displayName;
  final String   email;
  final LabRole  role;
  final DateTime joinedAt;

  const LabMemberProfile({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  bool get isCurrentUser => userId == supabase.auth.currentUser?.id;

  factory LabMemberProfile.fromMap(Map<String, dynamic> m) {
    final profile = m['profiles'] as Map<String, dynamic>? ?? {};
    return LabMemberProfile(
      userId:      m['user_id'] as String,
      displayName: (profile['display_name'] as String?) ?? 'Unknown',
      email:       (profile['email'] as String?) ?? '',
      role:        LabRoleX.fromString(m['role'] as String),
      joinedAt:    DateTime.parse(m['created_at'] as String),
    );
  }
}

class LabInvitation {
  final String   id;
  final String   code;
  final LabRole  role;
  final DateTime expiresAt;

  const LabInvitation({
    required this.id,
    required this.code,
    required this.role,
    required this.expiresAt,
  });

  factory LabInvitation.fromMap(Map<String, dynamic> m) => LabInvitation(
        id:        m['id'] as String,
        code:      m['code'] as String,
        role:      LabRoleX.fromString(m['role'] as String),
        expiresAt: DateTime.parse(m['expires_at'] as String),
      );
}

class InvitationPreview {
  final String  labId;
  final String  labName;
  final LabRole role;
  const InvitationPreview({
    required this.labId,
    required this.labName,
    required this.role,
  });
}

// ── Members provider ──────────────────────────────────────

final labMembersProvider =
    FutureProvider.autoDispose<List<LabMemberProfile>>((ref) async {
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) return [];

  final data = await supabase
      .from('lab_members')
      .select('user_id, role, created_at, profiles(display_name, email)')
      .eq('lab_id', lab.labId)
      .order('created_at');

  return (data as List)
      .map((r) => LabMemberProfile.fromMap(r as Map<String, dynamic>))
      .toList();
});

// ── Invitations provider ──────────────────────────────────

final labInvitationsProvider =
    FutureProvider.autoDispose<List<LabInvitation>>((ref) async {
  final lab = ref.watch(selectedLabProvider);
  if (lab == null) return [];

  final data = await supabase
      .from('lab_invitations')
      .select()
      .eq('lab_id', lab.labId)
      .isFilter('used_at', null)
      .order('created_at', ascending: false);

  return (data as List)
      .map((r) => LabInvitation.fromMap(r as Map<String, dynamic>))
      .where((inv) => inv.expiresAt.isAfter(DateTime.now()))
      .toList();
});

// ── Members notifier (role change + remove) ───────────────

class MembersNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> changeRole(String userId, LabRole newRole) async {
    final lab = ref.read(selectedLabProvider);
    if (lab == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase
          .from('lab_members')
          .update({'role': newRole.name})
          .eq('lab_id', lab.labId)
          .eq('user_id', userId);
      ref.invalidate(labMembersProvider);
    });
  }

  Future<void> removeMember(String userId) async {
    final lab = ref.read(selectedLabProvider);
    if (lab == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase
          .from('lab_members')
          .delete()
          .eq('lab_id', lab.labId)
          .eq('user_id', userId);
      ref.invalidate(labMembersProvider);
    });
  }

  Future<void> transferAdmin(String targetUserId, LabRole myNewRole) async {
    final lab = ref.read(selectedLabProvider);
    if (lab == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.rpc('transfer_admin', params: {
        'p_lab_id':      lab.labId,
        'p_user_id':     targetUserId,
        'p_my_new_role': myNewRole.name,
      });
      ref.invalidate(labMembersProvider);
    });
  }
}

final membersNotifierProvider =
    AsyncNotifierProvider<MembersNotifier, void>(MembersNotifier.new);

// ── Invitations notifier (create + revoke) ────────────────

class InvitationsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> createInvitation(LabRole role) async {
    final lab  = ref.read(selectedLabProvider);
    final user = supabase.auth.currentUser;
    if (lab == null || user == null) throw Exception('Not authenticated');

    final code = _generateCode();
    await supabase.from('lab_invitations').insert({
      'lab_id':     lab.labId,
      'role':       role.name,
      'code':       code,
      'invited_by': user.id,
    });
    ref.invalidate(labInvitationsProvider);
    return code;
  }

  Future<void> revokeInvitation(String invitationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase
          .from('lab_invitations')
          .delete()
          .eq('id', invitationId);
      ref.invalidate(labInvitationsProvider);
    });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand  = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

final invitationsNotifierProvider =
    AsyncNotifierProvider<InvitationsNotifier, void>(InvitationsNotifier.new);

// ── Join with code ────────────────────────────────────────

class JoinWithCodeNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<InvitationPreview> validate(String code) async {
    final result = await supabase.rpc(
      'validate_invitation',
      params: {'p_code': code.trim().toUpperCase()},
    ) as Map<String, dynamic>;

    if (result['error'] != null) throw Exception(result['error'] as String);

    return InvitationPreview(
      labId:   result['lab_id'] as String,
      labName: result['lab_name'] as String,
      role:    LabRoleX.fromString(result['role'] as String),
    );
  }

  Future<LabMembership> redeem(String code) async {
    state = const AsyncLoading();
    late LabMembership membership;
    state = await AsyncValue.guard(() async {
      final result = await supabase.rpc(
        'redeem_invitation',
        params: {'p_code': code.trim().toUpperCase()},
      ) as Map<String, dynamic>;

      if (result['error'] != null) throw Exception(result['error'] as String);

      membership = LabMembership(
        labId:   result['lab_id'] as String,
        labName: result['lab_name'] as String,
        labSlug: result['lab_slug'] as String,
        role:    LabRoleX.fromString(result['role'] as String),
      );
      ref.invalidate(labMembersProvider);
    });
    return membership;
  }
}

final joinWithCodeProvider =
    AsyncNotifierProvider<JoinWithCodeNotifier, void>(JoinWithCodeNotifier.new);
