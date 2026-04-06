import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/product_with_stock.dart';
import 'expiry_badge.dart';
import 'stock_status_badge.dart' as badge;

class ProductCard extends StatelessWidget {
  final ProductWithStock item;

  const ProductCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final theme   = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/inventory/product/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  badge.StockStatusBadge(status: _mapStatus(item.stockStatus)),
                ],
              ),

              const SizedBox(height: 8),

              // ── Stock row ────────────────────────────
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${_fmt(item.totalQuantity)} ${product.unit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (product.barcode != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.qr_code, size: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      product.barcode!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),

              // ── Expiry row (only if next lot exists) ─
              if (item.fefoLot != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Next: lot ${item.fefoLot!.lotNumber}  ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    ExpiryBadge(
                        expirationDate: item.fefoLot!.expirationDate),
                  ],
                ),
              ],

              // ── Reorder warning ─────────────────────
              if (item.stockStatus == StockStatus.reorder ||
                  item.stockStatus == StockStatus.critical) ...[
                const SizedBox(height: 8),
                _WarningBanner(status: item.stockStatus, product: product),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  badge.StockStatus _mapStatus(StockStatus s) => switch (s) {
        StockStatus.ok         => badge.StockStatus.ok,
        StockStatus.reorder    => badge.StockStatus.reorder,
        StockStatus.critical   => badge.StockStatus.critical,
        StockStatus.outOfStock => badge.StockStatus.outOfStock,
      };
}

class _WarningBanner extends StatelessWidget {
  final StockStatus status;
  final dynamic     product;

  const _WarningBanner({required this.status, required this.product});

  @override
  Widget build(BuildContext context) {
    final isCritical = status == StockStatus.critical ||
        status == StockStatus.outOfStock;
    final color = isCritical ? AppTheme.danger : AppTheme.warning;
    final text  = isCritical
        ? 'Critical — place urgent order'
        : 'Below reorder point — place order';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color:      color,
              fontSize:   12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
