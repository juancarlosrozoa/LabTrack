import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/lot.dart';
import '../../../data/models/product_with_stock.dart';
import '../../../shared/widgets/expiry_badge.dart';
import '../../../shared/widgets/stock_status_badge.dart' as badge;
import '../providers/inventory_providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productDetailProvider(productId));

    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Product not found')),
          );
        }
        return _ProductDetailView(item: item);
      },
    );
  }
}

class _ProductDetailView extends StatelessWidget {
  final ProductWithStock item;
  const _ProductDetailView({required this.item});

  @override
  Widget build(BuildContext context) {
    final product = item.product;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon:    const Icon(Icons.edit_outlined),
            tooltip: 'Edit product',
            onPressed: () => context.push('/products/edit/${product.id}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stock summary card ────────────────────
          _StockSummaryCard(item: item),
          const SizedBox(height: 16),

          // ── Product info ──────────────────────────
          _SectionTitle('Product info'),
          _InfoCard(rows: [
            if (product.barcode != null)
              _InfoRow(Icons.qr_code,    'Barcode',   product.barcode!),
            _InfoRow(Icons.straighten,   'Unit',      product.unit),
            _InfoRow(Icons.warning_amber_outlined, 'Reorder point',
                '${product.reorderPoint} ${product.unit}'),
            _InfoRow(Icons.error_outline, 'Min. stock',
                '${product.minimumStock} ${product.unit}'),
            _InfoRow(Icons.local_shipping_outlined, 'Est. delivery',
                '${product.estimatedDeliveryDays} days'),
          ]),
          const SizedBox(height: 16),

          // ── Lots ──────────────────────────────────
          _SectionTitle('Lots (${item.lots.length})'),
          if (item.lots.isEmpty)
            const _EmptyLots()
          else
            ...item.lots.map((l) => _LotCard(lot: l, unit: product.unit)),
          const SizedBox(height: 80),
        ],
      ),

      // ── FAB actions ───────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag:   'exit',
            tooltip:   'Register exit',
            onPressed: () =>
                context.push('/movements/exit?productId=${product.id}'),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag:   'entry',
            onPressed: () =>
                context.push('/movements/entry?productId=${product.id}'),
            icon:  const Icon(Icons.add),
            label: const Text('Entry'),
          ),
        ],
      ),
    );
  }
}

// ── Stock summary card ────────────────────────────────────

class _StockSummaryCard extends StatelessWidget {
  final ProductWithStock item;
  const _StockSummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final status = item.stockStatus;
    final color  = _statusColor(status);

    return Card(
      color: color.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmt(item.totalQuantity)} ${item.product.unit}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:      color,
                  ),
                ),
                const SizedBox(height: 4),
                badge.StockStatusBadge(status: _mapStatus(status)),
              ],
            ),
            const Spacer(),
            Icon(_statusIcon(status), size: 48, color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(StockStatus s) => switch (s) {
        StockStatus.ok         => AppTheme.success,
        StockStatus.reorder    => AppTheme.warning,
        StockStatus.critical   => AppTheme.danger,
        StockStatus.outOfStock => AppTheme.danger,
      };

  IconData _statusIcon(StockStatus s) => switch (s) {
        StockStatus.ok         => Icons.check_circle_outline,
        StockStatus.reorder    => Icons.shopping_cart_outlined,
        StockStatus.critical   => Icons.warning_amber_rounded,
        StockStatus.outOfStock => Icons.remove_shopping_cart_outlined,
      };

  badge.StockStatus _mapStatus(StockStatus s) => switch (s) {
        StockStatus.ok         => badge.StockStatus.ok,
        StockStatus.reorder    => badge.StockStatus.reorder,
        StockStatus.critical   => badge.StockStatus.critical,
        StockStatus.outOfStock => badge.StockStatus.outOfStock,
      };

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Lot card ──────────────────────────────────────────────

class _LotCard extends StatelessWidget {
  final Lot    lot;
  final String unit;
  const _LotCard({required this.lot, required this.unit});

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final dateStr  = DateFormat('MMM d, yyyy').format(lot.expirationDate);
    final expired  = lot.expirationDate.isBefore(DateTime.now());

    return Card(
      color: expired
          ? AppTheme.danger.withValues(alpha: 0.05)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: const Icon(Icons.science_outlined, size: 18),
        ),
        title: Text(lot.lotNumber,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Exp. $dateStr'),
        trailing: Column(
          mainAxisSize:     MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_fmt(lot.quantity)} $unit',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ExpiryBadge(expirationDate: lot.expirationDate),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Helpers ───────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: rows
              .map((r) => ListTile(
                    dense:   true,
                    leading: Icon(r.icon, size: 20),
                    title:   Text(r.label),
                    trailing: Text(r.value,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ))
              .toList(),
        ),
      );
}

class _InfoRow {
  final IconData icon;
  final String   label;
  final String   value;
  const _InfoRow(this.icon, this.label, this.value);
}

class _EmptyLots extends StatelessWidget {
  const _EmptyLots();

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('No lots registered yet.',
                style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
}
