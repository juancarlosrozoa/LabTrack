import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/models/movement.dart';
import '../../auth/providers/lab_provider.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../providers/movements_providers.dart';

class ScanCountScreen extends ConsumerStatefulWidget {
  const ScanCountScreen({super.key});

  @override
  ConsumerState<ScanCountScreen> createState() => _ScanCountScreenState();
}

class _ScanCountScreenState extends ConsumerState<ScanCountScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _processing = false;

  // Accumulated counts: productId → {name, unit, scanned, expected}
  final Map<String, _ProductCount> _counts = {};

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    _processing = true;
    await _scanner.stop();

    if (!mounted) return;

    final inventory = ref.read(inventoryProvider).valueOrNull ?? [];
    final match = inventory.where((p) => p.product.barcode == code).firstOrNull;

    if (!mounted) { _processing = false; return; }

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found for "$code"'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      final qty = await showModalBottomSheet<double>(
        context:            context,
        isScrollControlled: true,
        builder: (_) => _ScanConfirmSheet(
          productName:  match.product.name,
          unit:         match.product.unit,
          alreadyCounted: _counts[match.product.id]?.scanned ?? 0,
        ),
      );

      if (qty != null && qty > 0 && mounted) {
        setState(() {
          final existing = _counts[match.product.id];
          _counts[match.product.id] = _ProductCount(
            name:     match.product.name,
            unit:     match.product.unit,
            scanned:  (existing?.scanned ?? 0) + qty,
            expected: match.totalQuantity,
          );
        });
      }
    }

    _processing = false;
    if (mounted) await _scanner.start();
  }

  int get _totalScans => _counts.length;

  void _finish() {
    if (_counts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan at least one product first')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReviewScreen(counts: Map.from(_counts)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan & Count'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.flashlight_on_outlined),
            onPressed: _scanner.toggleTorch,
          ),
          if (_totalScans > 0)
            TextButton(
              onPressed: _finish,
              child: Text(
                'Finish ($_totalScans)',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _scanner, onDetect: _onDetect),
          _ScanOverlay(),

          // Live tally chips
          if (_counts.isNotEmpty)
            Positioned(
              top: 12, left: 12, right: 12,
              child: Wrap(
                spacing: 8, runSpacing: 6,
                children: _counts.entries.map((e) {
                  final c     = e.value;
                  final delta = c.scanned - c.expected;
                  final color = delta.abs() < 0.01
                      ? AppTheme.success
                      : (delta < 0 ? AppTheme.danger : AppTheme.warning);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:        color.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${c.name}  ${_fmt(c.scanned)} ${c.unit}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Bottom hint
          Positioned(
            bottom: 48, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Scan items or packages to accumulate count',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ── Confirm sheet ─────────────────────────────────────────

class _ScanConfirmSheet extends StatefulWidget {
  final String productName;
  final String unit;
  final double alreadyCounted;

  const _ScanConfirmSheet({
    required this.productName,
    required this.unit,
    required this.alreadyCounted,
  });

  @override
  State<_ScanConfirmSheet> createState() => _ScanConfirmSheetState();
}

class _ScanConfirmSheetState extends State<_ScanConfirmSheet> {
  double _qty = 1;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _adjust(double delta) {
    final next = (_qty + delta).clamp(1.0, 99999.0);
    setState(() => _qty = next);
    _ctrl.text = _fmt(next);
  }

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(widget.productName,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          if (widget.alreadyCounted > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Already scanned: ${_fmt(widget.alreadyCounted)} ${widget.unit}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppTheme.success),
            ),
          ],
          const SizedBox(height: 20),
          Text('Units in this scan',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Change to 12, 24, 100… if scanning a package',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StepBtn(icon: Icons.remove, onTap: () => _adjust(-1)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller:  _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  textAlign:   TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    suffixText:     widget.unit,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null && n > 0) setState(() => _qty = n);
                  },
                ),
              ),
              const SizedBox(width: 12),
              _StepBtn(icon: Icons.add, onTap: () => _adjust(1)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _qty),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Add ${_fmt(_qty)} ${widget.unit}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22),
        ),
      );
}

// ── Review screen ─────────────────────────────────────────

class _ReviewScreen extends ConsumerWidget {
  final Map<String, _ProductCount> counts;
  const _ReviewScreen({required this.counts});

  String _fmt(double v) =>
      v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _fmtDelta(double v) =>
      '${v >= 0 ? '+' : ''}${_fmt(v)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discrepancies = counts.entries
        .where((e) => (e.value.scanned - e.value.expected).abs() > 0.001)
        .toList();

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Count Review')),
      body: Column(
        children: [
          // Banner
          Container(
            width: double.infinity,
            margin:  const EdgeInsets.all(16),
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
                        ? '${counts.length} products match. No adjustments needed.'
                        : '${discrepancies.length} discrepanc${discrepancies.length == 1 ? 'y' : 'ies'} out of ${counts.length} products scanned.',
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

          // List
          Expanded(
            child: ListView.builder(
              itemCount:   counts.length,
              itemBuilder: (_, i) {
                final entry = counts.entries.elementAt(i);
                final c     = entry.value;
                final delta = c.scanned - c.expected;
                final hasDisc = delta.abs() > 0.001;
                final color = hasDisc
                    ? (delta < 0 ? AppTheme.danger : AppTheme.warning)
                    : AppTheme.success;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(
                      hasDisc
                          ? Icons.warning_amber_rounded
                          : Icons.check,
                      color: color,
                      size: 20,
                    ),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Expected ${_fmt(c.expected)} · Counted ${_fmt(c.scanned)} ${c.unit}',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: hasDisc
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:        color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${_fmtDelta(delta)} ${c.unit}',
                            style: TextStyle(
                              color:      color,
                              fontWeight: FontWeight.bold,
                              fontSize:   12,
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: discrepancies.isEmpty
              ? FilledButton.icon(
                  onPressed: () => _saveCount(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon:  const Icon(Icons.check_circle_outline),
                  label: const Text('Save count result'),
                )
              : FilledButton.icon(
                  onPressed: () =>
                      _approveAdjustments(context, ref, discrepancies),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon:  const Icon(Icons.tune),
                  label: Text(
                      'Approve ${discrepancies.length} adjustment${discrepancies.length == 1 ? '' : 's'}'),
                ),
        ),
      ),
    );
  }

  Future<void> _saveCount(BuildContext context, WidgetRef ref) async {
    await _persistSession(ref, []);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Count saved')),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _approveAdjustments(
    BuildContext context,
    WidgetRef ref,
    List<MapEntry<String, _ProductCount>> discrepancies,
  ) async {
    for (final e in discrepancies) {
      final delta = e.value.scanned - e.value.expected;
      await ref.read(registerMovementProvider.notifier).register(
            productId: e.key,
            lotId:     null,
            type:      MovementType.adjustment,
            quantity:  delta,
            reason:    'Scan count adjustment',
          );
    }

    await _persistSession(ref, discrepancies);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjustments recorded')),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _persistSession(
    WidgetRef ref,
    List<MapEntry<String, _ProductCount>> discrepancies,
  ) async {
    final lab = ref.read(selectedLabProvider);
    if (lab == null) return;
    final db = ref.read(databaseProvider);
    await db.countSessionDao.saveSession(
      labId:            lab.labId,
      countedAt:        DateTime.now(),
      totalCounted:     counts.length,
      discrepancyCount: discrepancies.length,
      items: counts.entries
          .map((e) => (
                productId:   e.key,
                productName: e.value.name,
                unit:        e.value.unit,
                expected:    e.value.expected,
                counted:     e.value.scanned,
              ))
          .toList(),
    );
  }
}

// ── Data model ────────────────────────────────────────────

class _ProductCount {
  final String name;
  final String unit;
  final double scanned;
  final double expected;

  const _ProductCount({
    required this.name,
    required this.unit,
    required this.scanned,
    required this.expected,
  });
}

// ── Scan overlay ──────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w    = c.maxWidth;
      final h    = c.maxHeight;
      final side = w * 0.7;
      final left = (w - side) / 2;
      final top  = (h - side) / 2 - 40;

      return Stack(children: [
        ColorFiltered(
          colorFilter:
              const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
          child: Stack(children: [
            Container(
              decoration: const BoxDecoration(
                color:               Colors.black,
                backgroundBlendMode: BlendMode.dstOut,
              ),
            ),
            Positioned(
              left: left, top: top, width: side, height: side,
              child: Container(
                decoration: BoxDecoration(
                  color:        Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ]),
        ),
        Positioned(
          left: left, top: top, width: side, height: side,
          child: CustomPaint(painter: _BracketPainter()),
        ),
      ]);
    });
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = Colors.white
      ..strokeWidth = 3.0
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    const len = 20.0;
    const r   = 8.0;
    final w   = size.width;
    final h   = size.height;
    for (final path in [
      Path()
        ..moveTo(0, len)..lineTo(0, r)
        ..arcToPoint(Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len, 0),
      Path()
        ..moveTo(w - len, 0)..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, len),
      Path()
        ..moveTo(0, h - len)..lineTo(0, h - r)
        ..arcToPoint(Offset(r, h), radius: const Radius.circular(r))
        ..lineTo(len, h),
      Path()
        ..moveTo(w - len, h)..lineTo(w - r, h)
        ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r))
        ..lineTo(w, h - len),
    ]) {
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
