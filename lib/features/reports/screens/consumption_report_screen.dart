import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../auth/providers/lab_provider.dart';
import '../providers/consumption_providers.dart';
import '../services/csv_export_service.dart';

class ConsumptionReportScreen extends ConsumerWidget {
  const ConsumptionReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period    = ref.watch(consumptionPeriodProvider);
    final dataAsync = ref.watch(consumptionReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumption'),
        actions: [
          if (dataAsync.valueOrNull?.isNotEmpty == true)
            IconButton(
              icon:    const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () => CsvExportService.exportConsumption(
                dataAsync.value!,
                period.label,
                ref.read(selectedLabProvider)?.labName ?? 'Lab',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Period chips ──────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: ConsumptionPeriod.values
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label:    Text(p.label),
                          selected: period == p,
                          onSelected: (_) => ref
                              .read(consumptionPeriodProvider.notifier)
                              .state = p,
                          visualDensity: VisualDensity.compact,
                        ),
                      ))
                  .toList(),
            ),
          ),

          // ── Content ───────────────────────────────────
          Expanded(
            child: dataAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error:   (e, _) => AppErrorWidget(error: e),
              data:    (items) => items.isEmpty
                  ? const _EmptyState()
                  : _ConsumptionList(items: items),
            ),
          ),
        ],
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────

class _ConsumptionList extends StatelessWidget {
  final List<ProductConsumption> items;
  const _ConsumptionList({required this.items});

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max   = items.first.totalConsumed; // sorted desc, so first = max

    return ListView.builder(
      padding:     const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount:   items.length,
      itemBuilder: (_, i) {
        final item     = items[i];
        final fraction = max > 0 ? item.totalConsumed / max : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Rank badge
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Product name
                  Expanded(
                    child: Text(
                      item.productName,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Total consumed
                  Text(
                    '${_fmt(item.totalConsumed)} ${item.unit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:      AppTheme.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Movement count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${item.movementCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Progress bar
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           fraction,
                    minHeight:       5,
                    backgroundColor: AppTheme.danger.withValues(alpha: 0.1),
                    valueColor:      AlwaysStoppedAnimation<Color>(
                        AppTheme.danger.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
              Icon(Icons.trending_down_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No consumption recorded',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Start registering exit movements to see which products are being consumed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}
