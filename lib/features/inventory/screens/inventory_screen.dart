import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/product_with_stock.dart';
import '../../../shared/screens/barcode_scanner_screen.dart';
import '../../../shared/widgets/product_card.dart';
import '../providers/inventory_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: ref.read(inventorySearchProvider),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(filteredInventoryProvider);
    final searchQuery    = ref.watch(inventorySearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.qr_code_scanner_outlined),
            tooltip: 'Scan barcode',
            onPressed: () async {
              final code = await scanBarcode(context);
              if (code != null && mounted) {
                _searchCtrl.text = code;
                ref.read(inventorySearchProvider.notifier).state = code;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller:  _searchCtrl,
              decoration: InputDecoration(
                hintText:     'Search by name or barcode…',
                prefixIcon:   const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon:      const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(inventorySearchProvider.notifier).state = '';
                        },
                      )
                    : null,
                isDense:      true,
              ),
              onChanged: (v) =>
                  ref.read(inventorySearchProvider.notifier).state = v,
            ),
          ),

          // ── Filter chips ─────────────────────────
          const _StatusFilterChips(),

          // ── List ─────────────────────────────────
          Expanded(
            child: inventoryAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error:   (e, _) => _ErrorState(error: e),
              data:    (items) => items.isEmpty
                  ? const _EmptyState()
                  : _InventoryList(items: items),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:  () => context.push('/products/add'),
        icon:       const Icon(Icons.add),
        label:      const Text('Add product'),
      ),
    );
  }
}

// ── Status filter chips ───────────────────────────────────

class _StatusFilterChips extends ConsumerWidget {
  const _StatusFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(inventoryStatusFilterProvider);

    void pick(StockStatus? s) =>
        ref.read(inventoryStatusFilterProvider.notifier).state =
            selected == s ? null : s;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _Chip(label: 'All',       selected: selected == null,                  onTap: () => pick(null)),
          _Chip(label: 'OK',        selected: selected == StockStatus.ok,        onTap: () => pick(StockStatus.ok)),
          _Chip(label: 'Reorder',   selected: selected == StockStatus.reorder,   onTap: () => pick(StockStatus.reorder)),
          _Chip(label: 'Critical',  selected: selected == StockStatus.critical,  onTap: () => pick(StockStatus.critical)),
          _Chip(label: 'Out',       selected: selected == StockStatus.outOfStock,onTap: () => pick(StockStatus.outOfStock)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label:          Text(label),
          selected:       selected,
          onSelected:     (_) => onTap(),
          visualDensity:  VisualDensity.compact,
        ),
      );
}

// ── List ──────────────────────────────────────────────────

class _InventoryList extends StatelessWidget {
  final List<ProductWithStock> items;
  const _InventoryList({required this.items});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {},  // sync triggered by pull-to-refresh
        child: ListView.builder(
          padding:      const EdgeInsets.only(bottom: 96),
          itemCount:    items.length,
          itemBuilder:  (_, i) => ProductCard(item: items[i]),
        ),
      );
}

// ── Empty / error states ──────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No products yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Tap "Add product" to get started.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final Object error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Error loading inventory',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(error.toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
}
