import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/app_error_widget.dart';
import '../../../data/models/lab_membership.dart';
import '../../auth/providers/lab_provider.dart';
import '../providers/members_providers.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role         = ref.watch(currentLabRoleProvider);
    final canManage    = role?.canManage ?? false;
    final membersAsync = ref.watch(labMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          if (canManage)
            IconButton(
              icon:    const Icon(Icons.person_add_outlined),
              tooltip: 'Invite member',
              onPressed: () => _showInviteDialog(context, ref),
            ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => AppErrorWidget(error: e),
        data:    (members) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Team ─────────────────────────────────────
            _SectionLabel('Team (${members.length})'),
            ...members.map((m) => _MemberTile(member: m, canManage: canManage)),

            // ── Active invitations ────────────────────────
            if (canManage) ...[
              const SizedBox(height: 8),
              const _SectionLabel('Active invitations'),
              const _InvitationsList(),
            ],
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
  }
}

// ── Section label ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color:       Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight:  FontWeight.bold,
                letterSpacing: 0.5,
              ),
        ),
      );
}

// ── Member tile ───────────────────────────────────────────

class _MemberTile extends ConsumerWidget {
  final LabMemberProfile member;
  final bool             canManage;
  const _MemberTile({required this.member, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme   = Theme.of(context);
    final isMe    = member.isCurrentUser;
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(initial,
            style: TextStyle(
                color:      theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold)),
      ),
      title: Text(
        '${member.displayName}${isMe ? '  (you)' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(member.email,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: _RoleBadge(role: member.role),
      onTap: (canManage && !isMe)
          ? () => _showMemberActions(context, ref, member)
          : null,
    );
  }

  void _showMemberActions(
      BuildContext context, WidgetRef ref, LabMemberProfile member) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _MemberActionsSheet(member: member),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final LabRole role;
  const _RoleBadge({required this.role});

  Color _color(BuildContext context) => switch (role) {
        LabRole.admin   => Theme.of(context).colorScheme.primary,
        LabRole.manager => Colors.indigo,
        LabRole.analyst => Colors.teal,
        LabRole.viewer  => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.label,
        style: TextStyle(
            color:      color,
            fontSize:   11,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Member actions bottom sheet ───────────────────────────

class _MemberActionsSheet extends ConsumerStatefulWidget {
  final LabMemberProfile member;
  const _MemberActionsSheet({required this.member});

  @override
  ConsumerState<_MemberActionsSheet> createState() =>
      _MemberActionsSheetState();
}

class _MemberActionsSheetState
    extends ConsumerState<_MemberActionsSheet> {
  LabRole? _newRole;

  @override
  Widget build(BuildContext context) {
    final theme          = Theme.of(context);
    final currentRole    = ref.watch(currentLabRoleProvider);
    final isCurrentAdmin = currentRole?.isAdmin ?? false;
    final targetIsAdmin  = widget.member.role == LabRole.admin;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.member.displayName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(widget.member.email,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),

          // Role picker
          Text('Change role',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          DropdownButtonFormField<LabRole>(
            initialValue: _newRole ?? widget.member.role,
            decoration:  const InputDecoration(isDense: true),
            items: LabRole.values
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.label),
                    ))
                .toList(),
            onChanged: (r) => setState(() => _newRole = r),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _newRole == null || _newRole == widget.member.role
                  ? null
                  : () async {
                      await ref
                          .read(membersNotifierProvider.notifier)
                          .changeRole(widget.member.userId, _newRole!);
                      if (context.mounted) Navigator.pop(context);
                    },
              child: const Text('Save role'),
            ),
          ),

          // Transfer admin (visible only to admin, only for non-admin members)
          if (isCurrentAdmin && !targetIsAdmin) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon:  const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text('Transfer admin'),
                onPressed: () => _showTransferAdminDialog(context),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Remove member
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Remove member'),
                    content: Text(
                        'Remove ${widget.member.displayName} from the lab?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Remove')),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref
                      .read(membersNotifierProvider.notifier)
                      .removeMember(widget.member.userId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Remove from lab'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransferAdminDialog(BuildContext context) async {
    LabRole myNewRole = LabRole.manager;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Transfer admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.member.displayName} will become the new admin.',
              ),
              const SizedBox(height: 16),
              const Text('Your new role:',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<LabRole>(
                initialValue: myNewRole,
                decoration:  const InputDecoration(isDense: true),
                items: [LabRole.manager, LabRole.analyst, LabRole.viewer]
                    .map<DropdownMenuItem<LabRole>>((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        ))
                    .toList(),
                onChanged: (r) {
                  if (r != null) setDialogState(() => myNewRole = r);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(membersNotifierProvider.notifier)
          .transferAdmin(widget.member.userId, myNewRole);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ── Active invitations list ───────────────────────────────

class _InvitationsList extends ConsumerWidget {
  const _InvitationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(labInvitationsProvider);

    return invAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error:   (e, _) => const SizedBox.shrink(),
      data:    (invitations) => invitations.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No active invitations.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          : Column(
              children: invitations
                  .map((inv) => _InvitationTile(invitation: inv))
                  .toList(),
            ),
    );
  }
}

class _InvitationTile extends ConsumerWidget {
  final LabInvitation invitation;
  const _InvitationTile({required this.invitation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme   = Theme.of(context);
    final expFmt  = DateFormat('MMM d');
    final expires = expFmt.format(invitation.expiresAt);

    return ListTile(
      leading: const Icon(Icons.vpn_key_outlined),
      title: Text(
        invitation.code,
        style: const TextStyle(
            fontFamily:  'monospace',
            fontWeight:  FontWeight.bold,
            letterSpacing: 3),
      ),
      subtitle: Text(
        '${invitation.role.label}  ·  expires $expires',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon:    const Icon(Icons.copy_outlined, size: 18),
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: invitation.code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied')),
              );
            },
          ),
          IconButton(
            icon:    const Icon(Icons.share_outlined, size: 18),
            tooltip: 'Share',
            onPressed: () => Share.share(
              'Join my lab on LabTrack with code: ${invitation.code}\n'
              'Role: ${invitation.role.label}  ·  Expires $expires',
            ),
          ),
          IconButton(
            icon:    Icon(Icons.delete_outline,
                size: 18, color: theme.colorScheme.error),
            tooltip: 'Revoke',
            onPressed: () => ref
                .read(invitationsNotifierProvider.notifier)
                .revokeInvitation(invitation.id),
          ),
        ],
      ),
    );
  }
}

// ── Invite dialog ─────────────────────────────────────────

class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  LabRole _role    = LabRole.analyst;
  String? _code;
  bool    _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Invite member'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assign a role for the new member:',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<LabRole>(
            initialValue: _role,
            decoration: const InputDecoration(isDense: true),
            items: LabRole.values
                .where((r) => r != LabRole.admin)
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
            onChanged: _code == null
                ? (r) => setState(() => _role = r ?? _role)
                : null,
          ),
          if (_code != null) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                _code!,
                style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily:    'monospace',
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 8,
                    color:         theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Share this code — expires in 7 days',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon:  const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _code!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon:  const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share'),
                  onPressed: () => Share.share(
                    'Join my lab on LabTrack!\n'
                    'Code: $_code\n'
                    'Role: ${_role.label}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_code == null)
          FilledButton(
            onPressed: _loading ? null : _generate,
            child: _loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Generate code'),
          ),
      ],
    );
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final code = await ref
          .read(invitationsNotifierProvider.notifier)
          .createInvitation(_role);
      setState(() { _code = code; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorWidget.friendlyMessage(e))),
        );
      }
    }
  }
}
