import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/product.dart';
import '../../../shared/screens/barcode_scanner_screen.dart';
import '../../../data/repositories/supabase_inventory_repository.dart';
import '../../auth/providers/lab_provider.dart';
import '../providers/product_form_providers.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState
    extends ConsumerState<AddEditProductScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _barcodeCtrl    = TextEditingController();
  final _unitCtrl       = TextEditingController();
  final _reorderCtrl    = TextEditingController(text: '0');
  final _minStockCtrl   = TextEditingController(text: '0');
  final _deliveryCtrl   = TextEditingController(text: '7');

  String? _categoryId;
  String? _locationId;
  String? _supplierId;

  bool _initialized = false;

  bool get isEdit => widget.productId != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _unitCtrl.dispose();
    _reorderCtrl.dispose();
    _minStockCtrl.dispose();
    _deliveryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (!isEdit || _initialized) return;
    _initialized = true;

    final repo = ref.read(inventoryRepositoryProvider)
        as SupabaseInventoryRepository;
    final product =
        await repo.db.inventoryDao.getProductById(widget.productId!);
    if (product == null || !mounted) return;

    setState(() {
      _nameCtrl.text     = product.name;
      _barcodeCtrl.text  = product.barcode    ?? '';
      _unitCtrl.text     = product.unit;
      _reorderCtrl.text  = product.reorderPoint.toString();
      _minStockCtrl.text = product.minimumStock.toString();
      _deliveryCtrl.text = product.estimatedDeliveryDays.toString();
      _categoryId        = product.categoryId;
      _locationId        = product.defaultLocationId;
      _supplierId        = product.supplierId;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final lab = ref.read(selectedLabProvider);
    if (lab == null) return;

    final product = Product(
      id:                    widget.productId ?? '',
      labId:                 lab.labId,
      name:                  _nameCtrl.text.trim(),
      barcode:               _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      categoryId:            _categoryId,
      unit:                  _unitCtrl.text.trim(),
      reorderPoint:          double.tryParse(_reorderCtrl.text) ?? 0,
      minimumStock:          double.tryParse(_minStockCtrl.text) ?? 0,
      estimatedDeliveryDays: int.tryParse(_deliveryCtrl.text)    ?? 7,
      locationId:            _locationId,
      supplierId:            _supplierId,
      createdAt:             DateTime.now(),
    );

    await ref.read(saveProductProvider.notifier).save(product);

    if (!mounted) return;
    final state = ref.read(saveProductProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(state.error.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      context.pop();
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Delete product?'),
        content: const Text(
            'This will deactivate the product. Existing stock and history are preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:     const Text('Cancel'),
          ),
          FilledButton(
            style:     FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child:     const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    await ref.read(saveProductProvider.notifier).delete(widget.productId!);
    if (!mounted) return;
    context.go('/inventory');
  }

  @override
  Widget build(BuildContext context) {
    _loadExisting();

    final categoriesAsync = ref.watch(categoriesProvider);
    final locationsAsync  = ref.watch(locationsProvider);
    final suppliersAsync  = ref.watch(suppliersProvider);
    final saveState       = ref.watch(saveProductProvider);
    final isLoading       = saveState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'Add Product'),
        actions: [
          if (isEdit)
            IconButton(
              icon:    const Icon(Icons.delete_outline),
              tooltip: 'Delete product',
              onPressed: isLoading ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Name ──────────────────────────────
            _SectionLabel('Name *'),
            TextFormField(
              controller:     _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Sodium Chloride NaCl'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // ── Barcode ───────────────────────────
            _SectionLabel('Barcode (optional)'),
            TextFormField(
              controller: _barcodeCtrl,
              decoration: InputDecoration(
                hintText:   'e.g. 7647-14-5',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon:    const Icon(Icons.qr_code_scanner_outlined),
                  tooltip: 'Scan barcode',
                  onPressed: () async {
                    final code = await scanBarcode(context);
                    if (code != null) _barcodeCtrl.text = code;
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Unit ──────────────────────────────
            _SectionLabel('Unit *'),
            TextFormField(
              controller: _unitCtrl,
              decoration:
                  const InputDecoration(hintText: 'e.g. g, mL, units'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Unit is required' : null,
            ),
            const SizedBox(height: 16),

            // ── Category ──────────────────────────
            _SectionLabel('Category (optional)'),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error:   (_, __) => const SizedBox(),
              data: (cats) => DropdownButtonFormField<String>(
                value:      _categoryId,
                hint:       const Text('Select category'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...cats.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ),
            const SizedBox(height: 16),

            // ── Location ──────────────────────────
            _SectionLabel('Default Location (optional)'),
            locationsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error:   (_, __) => const SizedBox(),
              data: (locs) => DropdownButtonFormField<String>(
                value:      _locationId,
                hint:       const Text('Select location'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...locs.map((l) => DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name),
                      )),
                ],
                onChanged: (v) => setState(() => _locationId = v),
              ),
            ),
            const SizedBox(height: 16),

            // ── Supplier ──────────────────────────
            _SectionLabel('Supplier (optional)'),
            suppliersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error:   (_, __) => const SizedBox(),
              data: (sups) => DropdownButtonFormField<String>(
                value:      _supplierId,
                hint:       const Text('Select supplier'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...sups.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      )),
                ],
                onChanged: (v) => setState(() => _supplierId = v),
              ),
            ),
            const SizedBox(height: 24),

            // ── Stock thresholds ──────────────────
            Text('Stock Thresholds',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Used to trigger reorder alerts and mark stock as critical.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label:      'Reorder point',
                    controller: _reorderCtrl,
                    suffix:     _unitCtrl.text.isEmpty ? 'units' : _unitCtrl.text,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    label:      'Min. stock',
                    controller: _minStockCtrl,
                    suffix:     _unitCtrl.text.isEmpty ? 'units' : _unitCtrl.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _NumberField(
              label:      'Est. delivery (days)',
              controller: _deliveryCtrl,
              suffix:     'days',
              isInt:      true,
            ),
            const SizedBox(height: 32),

            // ── Save ──────────────────────────────
            FilledButton(
              onPressed: isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width:  20,
                      child:  CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Save changes' : 'Add product',
                      style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _NumberField extends StatelessWidget {
  final String             label;
  final TextEditingController controller;
  final String             suffix;
  final bool               isInt;

  const _NumberField({
    required this.label,
    required this.controller,
    required this.suffix,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller:  controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
        decoration: InputDecoration(
          labelText:  label,
          suffixText: suffix,
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          final n = isInt
              ? int.tryParse(v.trim())
              : double.tryParse(v.trim());
          if (n == null) return 'Enter a valid number';
          return null;
        },
      );
}
