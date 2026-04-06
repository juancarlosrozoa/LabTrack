import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/lab_membership.dart';
import '../providers/lab_provider.dart';

class LabPickerScreen extends ConsumerWidget {
  const LabPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labsAsync = ref.watch(userLabsProvider);
    final theme     = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
                'Select your laboratory',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'You have access to multiple laboratories.',
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
                      return _NoLabsMessage(theme: theme);
                    }
                    return ListView.separated(
                      itemCount:   labs.length,
                      separatorBuilder: (_, __) =>
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
}

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

class _NoLabsMessage extends StatelessWidget {
  final ThemeData theme;
  const _NoLabsMessage({required this.theme});

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
            'Contact your lab administrator\nto get access.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
