import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AlertConfigSection(),
          SizedBox(height: 24),
          _SuppliersSection(),
        ],
      ),
    );
  }
}

// ── Alert Config ──────────────────────────────────────────

class _AlertConfigSection extends ConsumerStatefulWidget {
  const _AlertConfigSection();

  @override
  ConsumerState<_AlertConfigSection> createState() =>
      _AlertConfigSectionState();
}

class _AlertConfigSectionState extends ConsumerState<_AlertConfigSection> {
  AlertConfig? _draft;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(alertConfigProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Text('Error: $e'),
      data: (config) {
        _draft ??= config;
        final draft = _draft!;

        return _Section(
          title: 'Alert Notifications',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expiry alert days chips
              const Text('Notify before expiry:',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [30, 60, 90].map((days) {
                  final selected = draft.expiryAlertDays.contains(days);
                  return FilterChip(
                    label:    Text('$days days'),
                    selected: selected,
                    onSelected: (on) {
                      final list = List<int>.from(draft.expiryAlertDays);
                      on ? list.add(days) : list.remove(days);
                      list.sort();
                      setState(() => _draft = draft.copyWith(expiryAlertDays: list));
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 24),

              // Reorder toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title:    const Text('Reorder point alerts'),
                subtitle: const Text('Notify when stock reaches reorder point'),
                value:    draft.reorderNotifications,
                onChanged: (v) =>
                    setState(() => _draft = draft.copyWith(reorderNotifications: v)),
              ),

              // Critical stock toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title:    const Text('Critical stock alerts'),
                subtitle: const Text('Notify when stock is critically low'),
                value:    draft.criticalStockNotifications,
                onChanged: (v) =>
                    setState(() => _draft = draft.copyWith(criticalStockNotifications: v)),
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: async.isLoading
                      ? null
                      : () {
                          ref
                              .read(alertConfigProvider.notifier)
                              .save(draft);
                          setState(() => _draft = null);
                        },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Suppliers ─────────────────────────────────────────────

class _SuppliersSection extends ConsumerWidget {
  const _SuppliersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsSuppliersProvider);

    return _Section(
      title: 'Suppliers',
      trailing: IconButton(
        icon:    const Icon(Icons.add),
        tooltip: 'Add supplier',
        onPressed: () => _showSupplierDialog(context, ref, null),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Text('Error: $e'),
        data: (suppliers) => suppliers.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No suppliers yet.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            : Column(
                children: suppliers
                    .map((s) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.local_shipping_outlined, size: 18),
                          ),
                          title: Text(s.name),
                          subtitle: Text([
                            if (s.email != null) s.email!,
                            if (s.phone != null) s.phone!,
                          ].join('  ·  ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:    const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit',
                                onPressed: () =>
                                    _showSupplierDialog(context, ref, s),
                              ),
                              IconButton(
                                icon:  const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () =>
                                    _confirmDelete(context, ref, s),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _showSupplierDialog(
      BuildContext context, WidgetRef ref, SupplierItem? existing) async {
    final nameCtrl  = TextEditingController(text: existing?.name  ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final formKey   = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add Supplier' : 'Edit Supplier'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator:  (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller:  emailCtrl,
                decoration:  const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller:  phoneCtrl,
                decoration:  const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final item = SupplierItem(
                id:    existing?.id ?? newId(),
                name:  nameCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty
                    ? null
                    : emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
              );
              ref.read(settingsSuppliersProvider.notifier).save(item);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SupplierItem s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete supplier?'),
        content: Text('Remove "${s.name}" from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(settingsSuppliersProvider.notifier).delete(s.id);
    }
  }
}

// ── Shared widget ─────────────────────────────────────────

class _Section extends StatelessWidget {
  final String  title;
  final Widget? trailing;
  final Widget  child;

  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ],
    );
  }
}
