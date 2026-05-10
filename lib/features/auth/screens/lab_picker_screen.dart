import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/lab_membership.dart';
import '../providers/lab_provider.dart';
import '../../members/providers/members_providers.dart';

class LabPickerScreen extends ConsumerWidget {
  const LabPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labsAsync = ref.watch(userLabsProvider);
    final theme     = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag:   'join',
            onPressed: () => _showJoinDialog(context, ref),
            icon:      const Icon(Icons.vpn_key_outlined),
            label:     const Text('Join with code'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag:   'create',
            onPressed: () => _showCreateLabDialog(context, ref),
            icon:      const Icon(Icons.add),
            label:     const Text('Create laboratory'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.biotech_rounded,
                  size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Your laboratories',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Select one to continue, or create / join a new one.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: labsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Error loading labs: $e',
                        style:
                            TextStyle(color: theme.colorScheme.error)),
                  ),
                  data: (labs) {
                    if (labs.isEmpty) {
                      return _NoLabsMessage(
                        theme:          theme,
                        onCreateLab:    () => _showCreateLabDialog(context, ref),
                        onJoinWithCode: () => _showJoinDialog(context, ref),
                      );
                    }
                    return ListView.separated(
                      itemCount:   labs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _LabCard(membership: labs[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateLabDialog(BuildContext context, WidgetRef ref) async {
    final membership = await showDialog<LabMembership>(
      context: context,
      builder: (_) => const _CreateLabDialog(),
    );
    if (membership != null && context.mounted) {
      ref.read(selectedLabProvider.notifier).state = membership;
      context.go('/dashboard');
    }
  }

  Future<void> _showJoinDialog(BuildContext context, WidgetRef ref) async {
    final membership = await showDialog<LabMembership>(
      context: context,
      builder: (_) => const _JoinWithCodeDialog(),
    );
    if (membership != null && context.mounted) {
      ref.read(selectedLabProvider.notifier).state = membership;
      context.go('/dashboard');
    }
  }
}

// ── Lab card ──────────────────────────────────────────────

class _LabCard extends ConsumerWidget {
  final LabMembership membership;
  const _LabCard({required this.membership});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            membership.labName[0].toUpperCase(),
            style: TextStyle(
              color:      theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          membership.labName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(membership.role.label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(selectedLabProvider.notifier).state = membership;
          context.go('/dashboard');
        },
      ),
    );
  }
}

// ── No labs empty state ───────────────────────────────────

class _NoLabsMessage extends StatelessWidget {
  final ThemeData    theme;
  final VoidCallback onCreateLab;
  final VoidCallback onJoinWithCode;
  const _NoLabsMessage({
    required this.theme,
    required this.onCreateLab,
    required this.onJoinWithCode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'No labs assigned',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your lab administrator to get access,\n'
            'or join with an invitation code.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon:      const Icon(Icons.add),
            label:     const Text('Create laboratory'),
            onPressed: onCreateLab,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon:      const Icon(Icons.vpn_key_outlined),
            label:     const Text('Join with code'),
            onPressed: onJoinWithCode,
          ),
        ],
      ),
    );
  }
}

// ── Create laboratory dialog ──────────────────────────────

class _CreateLabDialog extends ConsumerStatefulWidget {
  const _CreateLabDialog();

  @override
  ConsumerState<_CreateLabDialog> createState() => _CreateLabDialogState();
}

class _CreateLabDialogState extends ConsumerState<_CreateLabDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl    = TextEditingController();
  bool  _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create laboratory'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You will be the administrator of this laboratory.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller:         _ctrl,
              autofocus:          true,
              textCapitalization: TextCapitalization.words,
              textInputAction:    TextInputAction.done,
              onFieldSubmitted:   (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Laboratory name',
                hintText:  'e.g. Chemistry Lab A',
                errorText: _error,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final membership = await ref
          .read(createLabProvider.notifier)
          .create(_ctrl.text);
      ref.invalidate(userLabsProvider);
      if (mounted) Navigator.pop(context, membership);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
}

// ── Join-with-code dialog ─────────────────────────────────

class _JoinWithCodeDialog extends ConsumerStatefulWidget {
  const _JoinWithCodeDialog();

  @override
  ConsumerState<_JoinWithCodeDialog> createState() =>
      _JoinWithCodeDialogState();
}

class _JoinWithCodeDialogState extends ConsumerState<_JoinWithCodeDialog> {
  final _ctrl = TextEditingController();
  bool              _loading = false;
  InvitationPreview? _preview;
  String?           _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Join with code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_preview == null) ...[
            Text('Enter your 6-character invitation code:',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus:  true,
              textCapitalization: TextCapitalization.characters,
              maxLength:  6,
              textAlign:  TextAlign.center,
              style: const TextStyle(
                  fontFamily:    'monospace',
                  fontWeight:    FontWeight.bold,
                  letterSpacing: 6,
                  fontSize:      22),
              decoration: InputDecoration(
                counterText: '',
                errorText:   _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ] else ...[
            Text('You are about to join:',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    _preview!.labName[0].toUpperCase(),
                    style: TextStyle(
                        color:      theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(_preview!.labName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Role: ${_preview!.role.label}'),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_preview == null)
          FilledButton(
            onPressed: _loading ? null : _validate,
            child: _loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Validate'),
          )
        else
          FilledButton(
            onPressed: _loading ? null : _join,
            child: _loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Join lab'),
          ),
      ],
    );
  }

  Future<void> _validate() async {
    final code = _ctrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Code must be 6 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final preview = await ref
          .read(joinWithCodeProvider.notifier)
          .validate(code);
      setState(() { _preview = preview; _loading = false; });
    } catch (e) {
      setState(() {
        _loading = false;
        _error   = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _join() async {
    setState(() => _loading = true);
    try {
      final membership = await ref
          .read(joinWithCodeProvider.notifier)
          .redeem(_ctrl.text.trim());
      ref.invalidate(userLabsProvider);
      if (mounted) Navigator.pop(context, membership);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _preview = null;
        _error   = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
}
