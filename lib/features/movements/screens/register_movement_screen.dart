import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/movement.dart';
import '../../../data/models/product_with_stock.dart';
import '../../../shared/screens/barcode_scanner_screen.dart';
import '../../../shared/widgets/expiry_badge.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../providers/movements_providers.dart';

class RegisterMovementScreen extends ConsumerStatefulWidget {
  final MovementType type;
  final String?      preselectedProductId;

  const RegisterMovementScreen({
    super.key,
    required this.type,
    this.preselectedProductId,
  });

  @override
  ConsumerState<RegisterMovementScreen> createState() =>
      _RegisterMovementScreenState();
}

class _RegisterMovementScreenState
    extends ConsumerState<RegisterMovementScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _qtyCtrl    = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _areaCtrl   = TextEditingController();

  ProductWithStock? _selectedProduct;
  String?           _selectedLotId;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  bool get isEntry => widget.type == MovementType.entry ||
      widget.type == MovementType.returnItem;

  String get title => switch (widget.type) {
        MovementType.entry      => 'Register Entry',
        MovementType.exit       => 'Register Exit',
        MovementType.adjustment => 'Register Adjustment',
        MovementType.returnItem => 'Register Return',
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;

    await ref.read(registerMovementProvider.notifier).register(
          productId: _selectedProduct!.product.id,
          lotId:     _selectedLotId,
          type:      widget.type,
          quantity:  qty,
          reason:    _reasonCtrl.text.trim().isEmpty
              ? null
              : _reasonCtrl.text.trim(),
          area:      _areaCtrl.text.trim().isEmpty
              ? null
              : _areaCtrl.text.trim(),
        );

    final state = ref.read(registerMovementProvider);
    if (!mounted) return;

    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(state.error.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movement registered successfully')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final notifierState  = ref.watch(registerMovementProvider);
    final isLoading      = notifierState.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (items) => _buildForm(context, items, isLoading),
      ),
    );
  }

  Widget _buildForm(
      BuildContext context, List<ProductWithStock> items, bool isLoading) {
    final lots = _selectedProduct?.lots
            .where((l) => l.quantity > 0)
            .toList() ??
        [];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Product picker ────────────────────────
          Row(
            children: [
              Text('Product',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                icon:    const Icon(Icons.qr_code_scanner_outlined, size: 18),
                label:   const Text('Scan'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final code = await scanBarcode(context);
                  if (code == null || !mounted) return;
                  final match = items
                      .where((p) => p.product.barcode == code)
                      .firstOrNull;
                  if (match != null) {
                    setState(() {
                      _selectedProduct = match;
                      _selectedLotId   = null;
                    });
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text('No product found for "$code"')),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ProductWithStock>(
            value:        _selectedProduct,
            hint:        const Text('Select a product'),
            isExpanded:  true,
            items: items
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.product.name,
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (p) => setState(() {
              _selectedProduct = p;
              _selectedLotId   = null;
            }),
            validator: (v) => v == null ? 'Select a product' : null,
          ),
          const SizedBox(height: 20),

          // ── Lot picker (only for exit/adjustment) ─
          if (_selectedProduct != null) ...[
            Text('Lot',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (lots.isEmpty)
              const Text('No lots with stock available.',
                  style: TextStyle(color: Colors.grey))
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedLotId,
                hint:       const Text('Select a lot (optional)'),
                isExpanded: true,
                items: lots
                    .map((l) => DropdownMenuItem(
                          value: l.id,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${l.lotNumber} — ${_fmt(l.quantity)} ${_selectedProduct!.product.unit}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ExpiryBadge(
                                  expirationDate: l.expirationDate),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (id) =>
                    setState(() => _selectedLotId = id),
              ),
            const SizedBox(height: 20),
          ],

          // ── Quantity ──────────────────────────────
          Text('Quantity',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller:  _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText:  'e.g. 100',
              suffixText: _selectedProduct?.product.unit,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter a quantity';
              final n = double.tryParse(v.trim());
              if (n == null || n <= 0) return 'Enter a valid positive number';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // ── Reason (optional) ─────────────────────
          Text('Reason (optional)',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _reasonCtrl,
            decoration:
                const InputDecoration(hintText: 'e.g. Monthly restock'),
          ),
          const SizedBox(height: 20),

          // ── Area (optional) ───────────────────────
          Text('Area / Project (optional)',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _areaCtrl,
            decoration: const InputDecoration(
                hintText: 'e.g. Lab room 3 / Project X'),
          ),
          const SizedBox(height: 32),

          // ── Submit ────────────────────────────────
          FilledButton(
            onPressed: isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              padding:       const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width:  20,
                    child:  CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(title, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
