import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../auth/providers/lab_provider.dart';
import '../providers/inventory_trend_providers.dart';
import '../services/csv_export_service.dart';

class InventoryTrendScreen extends ConsumerWidget {
  const InventoryTrendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(inventoryTrendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Trend'),
        actions: [
          if (trendAsync.valueOrNull?.isEmpty == false)
            IconButton(
              icon:    const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () => CsvExportService.exportInventoryTrend(
                trendAsync.value!,
                ref.read(selectedLabProvider)?.labName ?? 'Lab',
              ),
            ),
        ],
      ),
      body: trendAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => AppErrorWidget(error: e),
        data:    (data) =>
            data == null || data.isEmpty
                ? const _EmptyState()
                : _TrendView(data: data),
      ),
    );
  }
}

// ── Trend table ───────────────────────────────────────────

class _TrendView extends StatelessWidget {
  final InventoryTrendData data;
  const _TrendView({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final dateFmt = DateFormat('MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Legend / info banner ──────────────────────
        Container(
          width:   double.infinity,
          margin:  const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Showing last ${data.sessionDates.length} count sessions. '
                  '"Change" = first count − last count.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Scrollable table ──────────────────────────
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing:  16,
                headingRowColor: WidgetStatePropertyAll(
                    theme.colorScheme.surfaceContainerLow),
                columns: [
                  const DataColumn(
                    label: Text('Product',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...data.sessionDates.map(
                    (d) => DataColumn(
                      label: Text(
                        dateFmt.format(d),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                  ),
                  const DataColumn(
                    label: Text('Change',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                ],
                rows: data.products.map((row) {
                  return DataRow(cells: [
                    // Product name + unit
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.productName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              row.unit,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // One cell per session
                    ...row.quantities.map(
                      (qty) => DataCell(
                        Text(
                          qty == null ? '—' : _fmt(qty),
                          style: TextStyle(
                            color: qty == null
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                    ),

                    // Change cell
                    DataCell(_ChangeCell(
                        consumption: row.inferredConsumption,
                        unit:        row.unit)),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangeCell extends StatelessWidget {
  final double? consumption;
  final String  unit;
  const _ChangeCell({required this.consumption, required this.unit});

  @override
  Widget build(BuildContext context) {
    if (consumption == null) return const Text('—');

    final consumed = consumption! > 0;
    final added    = consumption! < 0;
    final color    = consumed
        ? AppTheme.danger
        : added
            ? AppTheme.success
            : Theme.of(context).colorScheme.onSurface;
    final label = consumed
        ? '−${_fmt(consumption!.abs())} $unit'
        : added
            ? '+${_fmt(consumption!.abs())} $unit'
            : '±0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color:      color,
            fontWeight: FontWeight.w600,
            fontSize:   12),
      ),
    );
  }
}

String _fmt(double v) =>
    v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// ── Empty state ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No count sessions yet',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Complete at least one inventory count to see trends over time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}
