import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/product_with_stock.dart';
import '../providers/reports_providers.dart';
import '../providers/sheets_sync_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportDataProvider);

    return reportAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (report) => _ReportView(report: report),
    );
  }
}

class _ReportView extends ConsumerWidget {
  final ReportData report;
  const _ReportView({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme      = Theme.of(context);
    final dateFmt    = DateFormat('MMM d, yyyy  HH:mm');
    final syncState  = ref.watch(sheetsSyncProvider);
    final isSyncing  = syncState.isLoading;

    ref.listen(sheetsSyncProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Sync failed: ${next.error}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      } else if (!next.isLoading && next.hasValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sheets updated')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon:    const Icon(Icons.table_chart_outlined),
              tooltip: 'Sync to Google Sheets',
              onPressed: () => ref.read(sheetsSyncProvider.notifier).sync(),
            ),
          IconButton(
            icon:    const Icon(Icons.email_outlined),
            tooltip: 'Share via email',
            onPressed: () => _shareReport(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Header card ───────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.labName,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Generated ${dateFmt.format(report.generatedAt)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── KPI row ───────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _KpiTile(
                  label: 'Products',
                  value: '${report.allProducts.length}',
                  icon:  Icons.inventory_2_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiTile(
                  label: 'Alerts',
                  value: '${report.alertCount}',
                  icon:  Icons.warning_amber_rounded,
                  color: report.alertCount > 0
                      ? AppTheme.danger
                      : AppTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiTile(
                  label: 'Reorder',
                  value: '${report.reorderNeeded.length}',
                  icon:  Icons.shopping_cart_outlined,
                  color: report.reorderNeeded.isNotEmpty
                      ? AppTheme.warning
                      : AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Out of stock ──────────────────────────────
          if (report.outOfStock.isNotEmpty) ...[
            _SectionHeader(
                title: 'Out of Stock',
                count: report.outOfStock.length,
                color: AppTheme.danger),
            ...report.outOfStock.map(
              (p) => _ProductRow(
                product:      p,
                trailing:     '0 ${p.product.unit}',
                trailingColor: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Critical stock ────────────────────────────
          if (report.critical.isNotEmpty) ...[
            _SectionHeader(
                title: 'Critical Stock',
                count: report.critical.length,
                color: AppTheme.danger),
            ...report.critical.map(
              (p) => _ProductRow(
                product: p,
                trailing:
                    '${_fmt(p.totalQuantity)} / ${_fmt(p.product.minimumStock)} ${p.product.unit}',
                trailingColor: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Reorder needed ────────────────────────────
          if (report.reorderNeeded.isNotEmpty) ...[
            _SectionHeader(
                title: 'Reorder Needed',
                count: report.reorderNeeded.length,
                color: AppTheme.warning),
            ...report.reorderNeeded.map(
              (p) => _ProductRow(
                product: p,
                trailing:
                    '${_fmt(p.totalQuantity)} / ${_fmt(p.product.reorderPoint)} ${p.product.unit}',
                trailingColor: AppTheme.warning,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Expiring soon ─────────────────────────────
          if (report.expiringSoon.isNotEmpty) ...[
            _SectionHeader(
                title: 'Expiring Soon',
                count: report.expiringSoon.length,
                color: AppTheme.warning),
            ...report.expiringSoon.map(
              (p) => _ProductRow(
                product:  p,
                trailing: '${p.daysUntilNextExpiry} days',
                trailingColor: p.daysUntilNextExpiry! <= 7
                    ? AppTheme.danger
                    : AppTheme.warning,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── All clear ─────────────────────────────────
          if (report.alertCount == 0 &&
              report.reorderNeeded.isEmpty &&
              report.expiringSoon.isEmpty) ...[
            _Card(
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppTheme.success, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All products are within normal levels.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Full inventory ────────────────────────────
          _SectionHeader(
              title: 'Full Inventory',
              count: report.allProducts.length,
              color: theme.colorScheme.onSurfaceVariant),
          ...report.allProducts.map(
            (p) => _ProductRow(
              product:  p,
              trailing: '${_fmt(p.totalQuantity)} ${p.product.unit}',
              trailingColor: switch (p.stockStatus) {
                StockStatus.ok         => AppTheme.success,
                StockStatus.reorder    => AppTheme.warning,
                StockStatus.critical   => AppTheme.danger,
                StockStatus.outOfStock => AppTheme.danger,
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── Share button ──────────────────────────────
          FilledButton.icon(
            onPressed: _shareReport,
            icon:  const Icon(Icons.email_outlined),
            label: const Text('Share report via email'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _shareReport() {
    final text = buildReportText(report);
    Share.share(
      text,
      subject: 'LabTrack Inventory Report — ${report.labName}',
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}

class _KpiTile extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int    count;
  final Color  color;
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ProductWithStock product;
  final String           trailing;
  final Color            trailingColor;
  const _ProductRow({
    required this.product,
    required this.trailing,
    required this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(product.product.name,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis),
          ),
          Text(trailing,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: trailingColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
