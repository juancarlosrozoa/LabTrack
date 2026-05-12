import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../data/models/product_with_stock.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/providers/lab_provider.dart';
import '../../../shared/widgets/expiry_badge.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lab     = ref.watch(selectedLabProvider);
    final summary = ref.watch(dashboardSnapshotProvider);
    final theme   = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (lab != null)
              Text(lab.labName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
          ],
        ),
        actions: [
          IconButton(
            icon:    const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon:    const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => AppErrorWidget(error: e),
        data:    (s) => _DashboardBody(summary: s),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardSummary summary;
  const _DashboardBody({required this.summary});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
        children: [
          // ── KPI row ────────────────────────────────
          _KpiRow(summary: summary),
          const SizedBox(height: 8),

          // ── Alert banner ───────────────────────────
          if (summary.hasAlerts) _AlertBanner(count: summary.alertCount),

          // ── Critical stock ─────────────────────────
          if (summary.criticalStock.isNotEmpty) ...[
            _SectionHeader(
              icon:  Icons.warning_amber_rounded,
              color: AppTheme.danger,
              title: 'Critical Stock',
              count: summary.criticalStock.length,
            ),
            ...summary.criticalStock
                .map((p) => _StockAlertCard(item: p)),
          ],

          // ── Reorder needed ─────────────────────────
          if (summary.reorderNeeded.isNotEmpty) ...[
            _SectionHeader(
              icon:  Icons.shopping_cart_outlined,
              color: AppTheme.warning,
              title: 'Reorder Needed',
              count: summary.reorderNeeded.length,
            ),
            ...summary.reorderNeeded
                .map((p) => _StockAlertCard(item: p)),
          ],

          // ── Expiring soon ──────────────────────────
          if (summary.expiringSoon.isNotEmpty) ...[
            _SectionHeader(
              icon:  Icons.schedule,
              color: AppTheme.warning,
              title: 'Expiring Soon (≤ 30 days)',
              count: summary.expiringSoon.length,
            ),
            ...summary.expiringSoon
                .map((p) => _ExpiryAlertCard(item: p)),
          ],

          // ── All clear ──────────────────────────────
          if (!summary.hasAlerts && summary.totalProducts > 0)
            const _AllClearCard(),

          // ── Empty ──────────────────────────────────
          if (summary.totalProducts == 0) const _EmptyCard(),
        ],
      ),
    );
  }
}

// ── KPI row ───────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final DashboardSummary summary;
  const _KpiRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _KpiCard(
            label: 'Products',
            value: summary.totalProducts.toString(),
            icon:  Icons.inventory_2_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          _KpiCard(
            label: 'Alerts',
            value: summary.alertCount.toString(),
            icon:  Icons.notifications_outlined,
            color: summary.hasAlerts ? AppTheme.danger : AppTheme.success,
          ),
          const SizedBox(width: 12),
          _KpiCard(
            label: 'Reorder',
            value: summary.reorderNeeded.length.toString(),
            icon:  Icons.shopping_cart_outlined,
            color: summary.reorderNeeded.isNotEmpty
                ? AppTheme.warning
                : AppTheme.success,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:      color,
                  )),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Alert banner ──────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final int count;
  const _AlertBanner({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:        AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppTheme.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count active alert${count == 1 ? '' : 's'} require your attention.',
                style: const TextStyle(
                  color:      AppTheme.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Section header ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final int      count;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color:      color,
                fontWeight: FontWeight.bold,
                fontSize:   13,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}

// ── Stock alert card ──────────────────────────────────────

class _StockAlertCard extends StatelessWidget {
  final ProductWithStock item;
  const _StockAlertCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isOut   = item.stockStatus == StockStatus.outOfStock;
    final color   = isOut ? AppTheme.danger : AppTheme.danger;
    final product = item.product;

    return Card(
      child: ListTile(
        onTap: () => context.push('/inventory/product/${product.id}'),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isOut ? Icons.remove_shopping_cart : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
        ),
        title:    Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isOut
              ? 'Out of stock'
              : '${_fmt(item.totalQuantity)} ${product.unit} — min. ${_fmt(product.minimumStock)}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Expiry alert card ─────────────────────────────────────

class _ExpiryAlertCard extends StatelessWidget {
  final ProductWithStock item;
  const _ExpiryAlertCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final lot     = item.fefoLot!;
    final product = item.product;
    final dateStr = DateFormat('MMM d, yyyy').format(lot.expirationDate);

    return Card(
      child: ListTile(
        onTap: () => context.push('/inventory/product/${product.id}'),
        leading: CircleAvatar(
          backgroundColor: AppTheme.warning.withValues(alpha: 0.1),
          child: const Icon(Icons.schedule, color: AppTheme.warning, size: 20),
        ),
        title:    Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Lot ${lot.lotNumber} — exp. $dateStr'),
        trailing: ExpiryBadge(expirationDate: lot.expirationDate),
      ),
    );
  }
}

// ── All clear / empty ─────────────────────────────────────

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 48, color: AppTheme.success),
              const SizedBox(height: 12),
              Text('All clear',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('No alerts at this time.',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No products yet',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Add products in the Inventory tab.',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
}
