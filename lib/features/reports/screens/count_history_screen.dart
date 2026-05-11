import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart';
import '../../auth/providers/lab_provider.dart';
import '../providers/count_history_providers.dart';
import '../services/csv_export_service.dart';

class CountHistoryScreen extends ConsumerWidget {
  const CountHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(countHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Count History'),
        actions: [
          if (sessionsAsync.valueOrNull?.isNotEmpty == true)
            IconButton(
              icon:    const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () async {
                final sessions = sessionsAsync.value!;
                final labName  = ref.read(selectedLabProvider)?.labName ?? 'Lab';
                final items    = <String, List<InventoryCountSessionItem>>{};
                for (final s in sessions) {
                  items[s.id] = await ref.read(
                    countSessionItemsProvider(s.id).future,
                  );
                }
                await CsvExportService.exportCountHistory(
                    sessions, items, labName);
              },
            ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (sessions) => sessions.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding:     const EdgeInsets.symmetric(vertical: 8),
                itemCount:   sessions.length,
                itemBuilder: (_, i) =>
                    _SessionCard(session: sessions[i]),
              ),
      ),
    );
  }
}

// ── Session card (expandable) ─────────────────────────────

class _SessionCard extends ConsumerStatefulWidget {
  final InventoryCountSession session;
  const _SessionCard({required this.session});

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final dateFmt  = DateFormat('MMM d, yyyy  HH:mm');
    final hasDisc  = widget.session.discrepancyCount > 0;
    final color    = hasDisc ? AppTheme.warning : AppTheme.success;
    final discText = widget.session.discrepancyCount == 1
        ? '1 discrepancy'
        : '${widget.session.discrepancyCount} discrepancies';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                hasDisc
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: color,
                size: 20,
              ),
            ),
            title: Text(
              dateFmt.format(widget.session.countedAt),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${widget.session.totalCounted} products  ·  $discText',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) _SessionDetail(sessionId: widget.session.id),
        ],
      ),
    );
  }
}

// ── Expanded detail ───────────────────────────────────────

class _SessionDetail extends ConsumerWidget {
  final String sessionId;
  const _SessionDetail({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(countSessionItemsProvider(sessionId));

    return itemsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e'),
      ),
      data: (items) => Column(
        children: [
          const Divider(height: 1),
          _DetailHeader(),
          ...items.map((item) => _ItemRow(item: item)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text('Product', style: style)),
          Text('Expected', style: style),
          const SizedBox(width: 8),
          Text('Counted ', style: style),
          const SizedBox(width: 52),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final InventoryCountSessionItem item;
  const _ItemRow({required this.item});

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final delta   = item.counted - item.expected;
    final hasDisc = delta.abs() > 0.001;
    final color   = hasDisc
        ? (delta < 0 ? AppTheme.danger : AppTheme.warning)
        : AppTheme.success;
    final sign    = delta >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.productName,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_fmt(item.expected)} ${item.unit}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Text(
            '${_fmt(item.counted)} ${item.unit}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: hasDisc
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$sign${_fmt(delta)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:      color,
                        fontSize:   11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Icon(Icons.check, color: AppTheme.success, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No count sessions yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Complete a weekly count or scan count\nto see history here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
}
