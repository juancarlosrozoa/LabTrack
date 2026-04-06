import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum StockStatus { ok, reorder, critical, outOfStock }

class StockStatusBadge extends StatelessWidget {
  final StockStatus status;

  const StockStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color, width: 1),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String get _label => switch (status) {
        StockStatus.ok => 'OK',
        StockStatus.reorder => 'Reorder',
        StockStatus.critical => 'Critical',
        StockStatus.outOfStock => 'Out of Stock',
      };

  Color get _color => switch (status) {
        StockStatus.ok => AppTheme.success,
        StockStatus.reorder => AppTheme.warning,
        StockStatus.critical => AppTheme.danger,
        StockStatus.outOfStock => AppTheme.danger,
      };
}
