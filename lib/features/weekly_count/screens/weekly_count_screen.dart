import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/weekly_count_providers.dart';

class WeeklyCountScreen extends ConsumerWidget {
  const WeeklyCountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(weeklyCountProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Weekly Count')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (session) => switch (session.status) {
        CountSessionStatus.idle       => const _IdleView(),
        CountSessionStatus.inProgress => _InProgressView(session: session),
        CountSessionStatus.reviewing  => _ReviewView(session: session),
        CountSessionStatus.completed  => const _CompletedView(),
      },
    );
  }
}

// ── Idle — start screen ───────────────────────────────────

class _IdleView extends ConsumerWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Count')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fact_check_outlined,
                  size: 80,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6)),
              const SizedBox(height: 24),
              Text('Physical inventory count',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Compare your recorded stock against\nwhat\'s physically in the lab.\nDiscrepancies can be approved as adjustments.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(weeklyCountProvider.notifier).startSession(),
                icon:  const Icon(Icons.play_arrow),
                label: const Text('Start count session'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── In progress — product list ────────────────────────────

class _InProgressView extends ConsumerWidget {
  final CountSession session;
  const _InProgressView({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Count'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(weeklyCountProvider.notifier).reset(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${session.countedSoFar} / ${session.totalProducts} products counted',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      '${session.remaining} remaining',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value:            session.progress,
                  borderRadius:     BorderRadius.circular(4),
                  backgroundColor:  theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Product list ────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount:   session.entries.length,
              itemBuilder: (_, i) =>
                  _CountEntryTile(entry: session.entries[i]),
            ),
          ),
        ],
      ),
      floatingActionButton: session.allCounted
          ? FloatingActionButton.extended(
              onPressed: () => ref
                  .read(weeklyCountProvider.notifier)
                  .proceedToReview(),
              icon:  const Icon(Icons.check),
              label: const Text('Review & finish'),
            )
          : null,
    );
  }
}

class _CountEntryTile extends ConsumerWidget {
  final CountEntry entry;
  const _CountEntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = entry.item.product;
    final theme   = Theme.of(context);

    Color? tileColor;
    if (entry.hasDiscrepancy) {
      tileColor = AppTheme.warning.withValues(alpha: 0.05);
    } else if (entry.hasCount) {
      tileColor = AppTheme.success.withValues(alpha: 0.05);
    }

    return ListTile(
      tileColor: tileColor,
      leading: CircleAvatar(
        backgroundColor: entry.hasCount
            ? (entry.hasDiscrepancy
                ? AppTheme.warning.withValues(alpha: 0.15)
                : AppTheme.success.withValues(alpha: 0.15))
            : theme.colorScheme.surfaceContainerHighest,
        child: entry.hasCount
            ? Icon(
                entry.hasDiscrepancy
                    ? Icons.warning_amber_rounded
                    : Icons.check,
                color: entry.hasDiscrepancy
                    ? AppTheme.warning
                    : AppTheme.success,
                size: 20,
              )
            : Text(
                product.name[0].toUpperCase(),
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
      ),
      title: Text(product.name,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: entry.hasCount
          ? Text(
              'Expected ${_fmt(entry.expected)} · Counted ${_fmt(entry.counted!)} ${product.unit}'
              '${entry.hasDiscrepancy ? '  (Δ ${_fmtDelta(entry.difference)} ${product.unit})' : ''}',
              style: TextStyle(
                color: entry.hasDiscrepancy
                    ? AppTheme.warning
                    : AppTheme.success,
                fontSize: 12,
              ),
            )
          : Text(
              'Expected: ${_fmt(entry.expected)} ${product.unit}',
              style: theme.textTheme.bodySmall,
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showCountDialog(context, ref, entry),
    );
  }

  Future<void> _showCountDialog(
      BuildContext context, WidgetRef ref, CountEntry entry) async {
    final ctrl = TextEditingController(
      text: entry.counted?.toString() ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry.item.product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expected: ${_fmt(entry.expected)} ${entry.item.product.unit}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller:   ctrl,
              autofocus:    true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:  'Counted quantity',
                suffixText: entry.item.product.unit,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val >= 0) {
                ref
                    .read(weeklyCountProvider.notifier)
                    .recordCount(entry.item.product.id, val);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _fmtDelta(double v) =>
      '${v >= 0 ? '+' : ''}${v == v.floorToDouble() ? v.toInt() : v.toStringAsFixed(1)}';
}

// ── Review — discrepancies ────────────────────────────────

class _ReviewView extends ConsumerWidget {
  final CountSession session;
  const _ReviewView({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discrepancies = session.discrepancies;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Count'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref
              .read(weeklyCountProvider.notifier)
              .proceedToReview(), // re-enters review from in-progress
        ),
      ),
      body: Column(
        children: [
          // ── Summary banner ──────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: discrepancies.isEmpty
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: discrepancies.isEmpty
                    ? AppTheme.success.withValues(alpha: 0.3)
                    : AppTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  discrepancies.isEmpty
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: discrepancies.isEmpty
                      ? AppTheme.success
                      : AppTheme.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    discrepancies.isEmpty
                        ? 'All ${session.totalProducts} products match. No adjustments needed.'
                        : '${discrepancies.length} discrepanc${discrepancies.length == 1 ? 'y' : 'ies'} found out of ${session.totalProducts} products.',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: discrepancies.isEmpty
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Discrepancy list ────────────────────
          if (discrepancies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('The following adjustments will be recorded:',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: discrepancies
                    .map((e) => _DiscrepancyTile(entry: e))
                    .toList(),
              ),
            ),
          ] else
            const Expanded(child: SizedBox()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => ref
                .read(weeklyCountProvider.notifier)
                .approveAdjustments(),
            icon:  const Icon(Icons.check),
            label: Text(discrepancies.isEmpty
                ? 'Confirm count'
                : 'Approve ${discrepancies.length} adjustment${discrepancies.length == 1 ? '' : 's'}'),
            style: FilledButton.styleFrom(
              padding:           const EdgeInsets.symmetric(vertical: 16),
              backgroundColor:   discrepancies.isEmpty
                  ? AppTheme.success
                  : AppTheme.warning,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscrepancyTile extends StatelessWidget {
  final CountEntry entry;
  const _DiscrepancyTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final product = entry.item.product;
    final delta   = entry.difference;
    final color   = delta < 0 ? AppTheme.danger : AppTheme.success;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.warning.withValues(alpha: 0.1),
        child: const Icon(Icons.swap_vert, color: AppTheme.warning, size: 20),
      ),
      title: Text(product.name,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        'Expected ${_fmt(entry.expected)} → Counted ${_fmt(entry.counted!)} ${product.unit}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          '${delta >= 0 ? '+' : ''}${_fmt(delta)} ${product.unit}',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Completed ─────────────────────────────────────────────

class _CompletedView extends ConsumerWidget {
  const _CompletedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Weekly Count')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 80, color: AppTheme.success),
                const SizedBox(height: 24),
                Text('Count completed',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'All adjustments have been recorded\nand synced to Supabase.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(weeklyCountProvider.notifier).reset(),
                  icon:  const Icon(Icons.refresh),
                  label: const Text('Start new count'),
                ),
              ],
            ),
          ),
        ),
      );
}
