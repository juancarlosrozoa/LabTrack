import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ExpiryBadge extends StatelessWidget {
  final DateTime expirationDate;

  const ExpiryBadge({super.key, required this.expirationDate});

  @override
  Widget build(BuildContext context) {
    final days  = expirationDate.difference(DateTime.now()).inDays;
    final color = _color(days);
    final label = _label(days);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _label(int days) {
    if (days < 0)   return 'Expired';
    if (days == 0)  return 'Expires today';
    if (days == 1)  return 'Expires tomorrow';
    return 'Exp. in $days d';
  }

  Color _color(int days) {
    if (days < 0)   return AppTheme.danger;
    if (days <= 7)  return AppTheme.danger;
    if (days <= 30) return AppTheme.warning;
    return AppTheme.success;
  }
}
