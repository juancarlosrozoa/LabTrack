import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/lab_membership.dart';
import '../../auth/providers/lab_provider.dart';
import '../../help/screens/help_screen.dart';
import '../../members/screens/members_screen.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileSection(),
          SizedBox(height: 24),
          _LabSection(),
          SizedBox(height: 24),
          _AlertConfigSection(),
          SizedBox(height: 24),
          _CategoriesSection(),
          SizedBox(height: 24),
          _LocationsSection(),
          SizedBox(height: 24),
          _StorageConditionsSection(),
          SizedBox(height: 24),
          _SuppliersSection(),
          SizedBox(height: 24),
          _MembersTile(),
          SizedBox(height: 24),
          _HelpTile(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Profile section ───────────────────────────────────────

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final theme        = Theme.of(context);

    return _Section(
      title: 'My Profile',
      trailing: IconButton(
        icon:    const Icon(Icons.edit_outlined),
        tooltip: 'Edit profile',
        onPressed: () => profileAsync.valueOrNull == null
            ? null
            : _showEditDialog(context, ref, profileAsync.value!),
      ),
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Text('Error: $e'),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          final initial = profile.displayName.isNotEmpty
              ? profile.displayName[0].toUpperCase()
              : '?';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                initial,
                style: TextStyle(
                  color:      theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              profile.displayName.isNotEmpty ? profile.displayName : '—',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(profile.email,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, UserProfile profile) async {
    final ctrl    = TextEditingController(text: profile.displayName);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller:         ctrl,
            autofocus:          true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await ref
                  .read(profileNotifierProvider.notifier)
                  .updateDisplayName(ctrl.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ── Lab section ───────────────────────────────────────────

class _LabSection extends ConsumerWidget {
  const _LabSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lab   = ref.watch(selectedLabProvider);
    final theme = Theme.of(context);

    return _Section(
      title: 'Laboratory',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                lab?.labName[0].toUpperCase() ?? '?',
                style: TextStyle(
                  color:      theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(lab?.labName ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(lab?.role.label ?? ''),
          ),
          const Divider(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:  const Icon(Icons.swap_horiz),
            title:    const Text('Switch laboratory'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                ref.read(selectedLabProvider.notifier).state = null,
          ),
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

// ── Shared simple-name section ────────────────────────────

/// Reusable section for catalog items that only have a name (categories,
/// locations). Parameterised via callbacks so no generics are needed.
class _SimpleNameSection extends StatelessWidget {
  final String                  title;
  final IconData                icon;
  final AsyncValue<List<({String id, String name})>> async;
  final void Function()         onAdd;
  final void Function(String id, String name) onEdit;
  final void Function(String id, String name) onDelete;

  const _SimpleNameSection({
    required this.title,
    required this.icon,
    required this.async,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      trailing: IconButton(
        icon:    const Icon(Icons.add),
        tooltip: 'Add $title',
        onPressed: onAdd,
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Text('Error: $e'),
        data: (items) => items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No ${title.toLowerCase()} yet.',
                      style: const TextStyle(color: Colors.grey)),
                ),
              )
            : Column(
                children: items
                    .map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Icon(icon, size: 18),
                          ),
                          title: Text(item.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:    const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit',
                                onPressed: () => onEdit(item.id, item.name),
                              ),
                              IconButton(
                                icon:  const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () => onDelete(item.id, item.name),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

// ── Categories ────────────────────────────────────────────

class _CategoriesSection extends ConsumerWidget {
  const _CategoriesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsCategoriesProvider);
    final items = async.valueOrNull
            ?.map((c) => (id: c.id, name: c.name))
            .toList() ??
        [];

    return _SimpleNameSection(
      title: 'Categories',
      icon:  Icons.category_outlined,
      async: AsyncData(items),
      onAdd: () => _showDialog(context, ref, null, null),
      onEdit:   (id, name) => _showDialog(context, ref, id, name),
      onDelete: (id, name) => _confirmDelete(context, ref, id, name),
    );
  }

  Future<void> _showDialog(BuildContext context, WidgetRef ref,
      String? existingId, String? existingName) async {
    final ctrl    = TextEditingController(text: existingName ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existingId == null ? 'Add Category' : 'Edit Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller:  ctrl,
            autofocus:   true,
            decoration:  const InputDecoration(labelText: 'Name *'),
            textCapitalization: TextCapitalization.sentences,
            validator:   (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
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
              ref.read(settingsCategoriesProvider.notifier).save(
                    CategoryItem(
                      id:   existingId ?? newId(),
                      name: ctrl.text.trim(),
                    ),
                  );
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Remove "$name"?'),
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
      ref.read(settingsCategoriesProvider.notifier).delete(id);
    }
  }
}

// ── Locations ─────────────────────────────────────────────

class _LocationsSection extends ConsumerWidget {
  const _LocationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsLocationsProvider);
    final items = async.valueOrNull
            ?.map((l) => (id: l.id, name: l.name))
            .toList() ??
        [];

    return _SimpleNameSection(
      title: 'Locations',
      icon:  Icons.place_outlined,
      async: AsyncData(items),
      onAdd: () => _showDialog(context, ref, null, null),
      onEdit:   (id, name) => _showDialog(context, ref, id, name),
      onDelete: (id, name) => _confirmDelete(context, ref, id, name),
    );
  }

  Future<void> _showDialog(BuildContext context, WidgetRef ref,
      String? existingId, String? existingName) async {
    final ctrl    = TextEditingController(text: existingName ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existingId == null ? 'Add Location' : 'Edit Location'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller:  ctrl,
            autofocus:   true,
            decoration:  const InputDecoration(labelText: 'Name *'),
            textCapitalization: TextCapitalization.sentences,
            validator:   (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
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
              ref.read(settingsLocationsProvider.notifier).save(
                    LocationItem(
                      id:   existingId ?? newId(),
                      name: ctrl.text.trim(),
                    ),
                  );
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text('Remove "$name"?'),
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
      ref.read(settingsLocationsProvider.notifier).delete(id);
    }
  }
}

// ── Storage Conditions ────────────────────────────────────

class _StorageConditionsSection extends ConsumerWidget {
  const _StorageConditionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsStorageConditionsProvider);

    return _Section(
      title: 'Storage Conditions',
      trailing: IconButton(
        icon:    const Icon(Icons.add),
        tooltip: 'Add storage condition',
        onPressed: () => _showDialog(context, ref, null),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Text('Error: $e'),
        data: (conditions) => conditions.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No storage conditions yet.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            : Column(
                children: conditions
                    .map((c) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.thermostat, size: 18),
                          ),
                          title: Text(c.name),
                          subtitle: Text(_describe(c)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18),
                                onPressed: () =>
                                    _showDialog(context, ref, c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () =>
                                    _confirmDelete(context, ref, c),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  String _describe(StorageConditionItem c) {
    final parts = <String>[];
    if (c.tempMin != null || c.tempMax != null) {
      final min = c.tempMin != null
          ? '${c.tempMin!.toStringAsFixed(0)}°C'
          : '—';
      final max = c.tempMax != null
          ? '${c.tempMax!.toStringAsFixed(0)}°C'
          : '—';
      parts.add('$min – $max');
    }
    if (c.humidityMax != null) {
      parts.add('≤${c.humidityMax!.toStringAsFixed(0)}% RH');
    }
    if (c.lightSensitive) parts.add('Light sensitive');
    return parts.isEmpty ? 'No conditions specified' : parts.join('  ·  ');
  }

  Future<void> _showDialog(BuildContext context, WidgetRef ref,
      StorageConditionItem? existing) async {
    var  lightSensitive = existing?.lightSensitive ?? false;
    final nameCtrl      = TextEditingController(text: existing?.name ?? '');
    final tempMinCtrl   = TextEditingController(
        text: existing?.tempMin?.toStringAsFixed(0) ?? '');
    final tempMaxCtrl   = TextEditingController(
        text: existing?.tempMax?.toStringAsFixed(0) ?? '');
    final humCtrl       = TextEditingController(
        text: existing?.humidityMax?.toStringAsFixed(0) ?? '');
    final formKey       = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? 'Add Storage Condition'
              : 'Edit Storage Condition'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller:  nameCtrl,
                    autofocus:   true,
                    decoration:  const InputDecoration(labelText: 'Name *'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller:   tempMinCtrl,
                          decoration:   const InputDecoration(
                              labelText: 'Temp min (°C)'),
                          keyboardType: const TextInputType
                              .numberWithOptions(
                                  decimal: true, signed: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller:   tempMaxCtrl,
                          decoration:   const InputDecoration(
                              labelText: 'Temp max (°C)'),
                          keyboardType: const TextInputType
                              .numberWithOptions(
                                  decimal: true, signed: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller:   humCtrl,
                    decoration:   const InputDecoration(
                        labelText: 'Max humidity (%RH)'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title:    const Text('Light sensitive'),
                    value:    lightSensitive,
                    onChanged: (v) =>
                        setDialogState(() => lightSensitive = v),
                  ),
                ],
              ),
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
                ref
                    .read(settingsStorageConditionsProvider.notifier)
                    .save(StorageConditionItem(
                      id:             existing?.id ?? newId(),
                      name:           nameCtrl.text.trim(),
                      tempMin:        double.tryParse(tempMinCtrl.text),
                      tempMax:        double.tryParse(tempMaxCtrl.text),
                      humidityMax:    double.tryParse(humCtrl.text),
                      lightSensitive: lightSensitive,
                    ));
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      StorageConditionItem c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete storage condition?'),
        content: Text('Remove "${c.name}"?'),
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
      ref.read(settingsStorageConditionsProvider.notifier).delete(c.id);
    }
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
            ?trailing,
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

// ── Members tile ──────────────────────────────────────────

class _MembersTile extends StatelessWidget {
  const _MembersTile();

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading:  const Icon(Icons.group_outlined),
          title:    const Text('Team Members'),
          subtitle: const Text('Manage roles and invitations'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MembersScreen()),
          ),
        ),
      );
}

// ── Help tile ─────────────────────────────────────────────

class _HelpTile extends StatelessWidget {
  const _HelpTile();

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.help_outline),
          title:   const Text('Help & User Manual'),
          subtitle: const Text('English · Français · Español'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HelpScreen()),
          ),
        ),
      );
}
