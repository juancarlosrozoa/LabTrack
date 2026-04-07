import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/movements_providers.dart';

class MovementsScreen extends ConsumerWidget {
  const MovementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(movementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movements')),
      body: movementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (movements) => movements.isEmpty
            ? const _EmptyState()
            : _MovementsList(items: movements),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag:   'exit_fab',
            tooltip:   'Register exit',
            onPressed: () => context.push('/movements/exit'),
            backgroundColor: AppTheme.danger,
            child: const Icon(Icons.remove, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag:   'entry_fab',
            onPressed: () => context.push('/movements/entry'),
            backgroundColor: AppTheme.success,
            icon:  const Icon(Icons.add, color: Colors.white),
            label: const Text('Entry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────

class _MovementsList extends StatelessWidget {
  final List<MovementWithProduct> items;
  const _MovementsList({required this.items});

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding:     const EdgeInsets.only(bottom: 100),
        itemCount:   items.length,
        itemBuilder: (_, i) => _MovementTile(item: items[i]),
      );
}

class _MovementTile extends StatelessWidget {
  final MovementWithProduct item;
  const _MovementTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final m       = item.movement;
    final theme   = Theme.of(context);
    final color   = _color(m.type);
    final icon    = _icon(m.type);
    final dateStr = DateFormat('MMM d, HH:mm').format(m.createdAt);
    final sign    = m.type == 'exit' ? '−' : '+';
    final qty     = _fmt(m.quantity);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '$sign$qty',
            style: TextStyle(
              color:      color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          _TypeBadge(type: m.type),
          const SizedBox(width: 8),
          Text(dateStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          if (!m.isSynced) ...[
            const SizedBox(width: 8),
            const Icon(Icons.cloud_off, size: 12, color: Colors.grey),
          ],
        ],
      ),
    );
  }

  Color _color(String type) => switch (type) {
        'entry'      => AppTheme.success,
        'exit'       => AppTheme.danger,
        'adjustment' => AppTheme.warning,
        'return'     => AppTheme.secondary,
        _            => Colors.grey,
      };

  IconData _icon(String type) => switch (type) {
        'entry'      => Icons.add_circle_outline,
        'exit'       => Icons.remove_circle_outline,
        'adjustment' => Icons.tune,
        'return'     => Icons.keyboard_return,
        _            => Icons.swap_vert,
      };

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'entry'      => AppTheme.success,
      'exit'       => AppTheme.danger,
      'adjustment' => AppTheme.warning,
      'return'     => AppTheme.secondary,
      _            => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color:      color,
          fontSize:   10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Empty ─────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No movements yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Register an entry or exit to get started.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
}
