import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../inventory/providers/inventory_providers.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.add),
            tooltip: 'Add product',
            onPressed: () => context.push('/products/add'),
          ),
        ],
      ),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (items) {
          if (items.isEmpty) return const _EmptyState();
          return _ProductList(items: items);
        },
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────

class _ProductList extends ConsumerStatefulWidget {
  final List items;
  const _ProductList({required this.items});

  @override
  ConsumerState<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends ConsumerState<_ProductList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((p) =>
            p.product.name.toLowerCase().contains(_query.toLowerCase()) ||
            (p.product.barcode
                    ?.toLowerCase()
                    .contains(_query.toLowerCase()) ??
                false))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText:    'Search by name or barcode…',
              prefixIcon:  const Icon(Icons.search),
              filled:      true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:   BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text('${filtered.length} product${filtered.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding:     const EdgeInsets.only(bottom: 24),
            itemCount:   filtered.length,
            itemBuilder: (_, i) => _ProductTile(item: filtered[i]),
          ),
        ),
      ],
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final dynamic item;
  const _ProductTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p     = item.product;
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            theme.colorScheme.primaryContainer,
        child: Text(
          p.name[0].toUpperCase(),
          style: TextStyle(
              color:      theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(p.name,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        [
          p.unit,
          if (p.barcode != null) p.barcode!,
          if (!p.tracksLots) 'direct stock',
        ].join('  ·  '),
        style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StockBadge(qty: item.totalQuantity, unit: p.unit),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
      onTap: () => context.push('/products/edit/${p.id}'),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final double qty;
  final String unit;
  const _StockBadge({required this.qty, required this.unit});

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final color = qty <= 0
        ? AppTheme.danger
        : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${_fmt(qty)} $unit',
        style: TextStyle(
            color:      color,
            fontSize:   11,
            fontWeight: FontWeight.w600),
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
            const Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No products yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Tap + to add your first product.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
}
