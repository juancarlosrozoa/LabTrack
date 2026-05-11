import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/local/database.dart';
import '../providers/consumption_providers.dart';
import '../providers/inventory_trend_providers.dart';

class CsvExportService {
  // ── Helpers ───────────────────────────────────────────────

  static String _escape(dynamic value) {
    final s = value?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _row(List<dynamic> fields) =>
      fields.map(_escape).join(',');

  static Future<void> _share(String content, String filename) async {
    final dir  = await getTemporaryDirectory();
    final safe = filename
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .toLowerCase();
    final file = File('${dir.path}/$safe.csv');
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: '$safe.csv',
    );
  }

  // ── Consumption report ────────────────────────────────────

  static Future<void> exportConsumption(
    List<ProductConsumption> data,
    String period,
    String labName,
  ) async {
    final generated = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final buf       = StringBuffer();

    buf.writeln(_row(['Laboratory', labName]));
    buf.writeln(_row(['Period', period]));
    buf.writeln(_row(['Generated', generated]));
    buf.writeln();
    buf.writeln(_row(['Product', 'Unit', 'Total Consumed', 'Movements']));

    for (final item in data) {
      buf.writeln(_row([
        item.productName,
        item.unit,
        item.totalConsumed.toStringAsFixed(3),
        item.movementCount,
      ]));
    }

    await _share(buf.toString(), 'consumption_${labName}_$period');
  }

  // ── Inventory trend ───────────────────────────────────────

  static Future<void> exportInventoryTrend(
    InventoryTrendData data,
    String labName,
  ) async {
    final dateFmt   = DateFormat('yyyy-MM-dd');
    final generated = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final buf       = StringBuffer();

    buf.writeln(_row(['Laboratory', labName]));
    buf.writeln(_row(['Generated', generated]));
    buf.writeln();

    final headers = [
      'Product',
      'Unit',
      ...data.sessionDates.map(dateFmt.format),
      'Inferred Consumption',
    ];
    buf.writeln(_row(headers));

    for (final row in data.products) {
      buf.writeln(_row([
        row.productName,
        row.unit,
        ...row.quantities.map((q) => q?.toStringAsFixed(3) ?? ''),
        row.inferredConsumption?.toStringAsFixed(3) ?? '',
      ]));
    }

    await _share(buf.toString(), 'inventory_trend_$labName');
  }

  // ── Count history ─────────────────────────────────────────

  static Future<void> exportCountHistory(
    List<InventoryCountSession> sessions,
    Map<String, List<InventoryCountSessionItem>> itemsBySession,
    String labName,
  ) async {
    final dateFmt   = DateFormat('yyyy-MM-dd HH:mm');
    final generated = dateFmt.format(DateTime.now());
    final buf       = StringBuffer();

    buf.writeln(_row(['Laboratory', labName]));
    buf.writeln(_row(['Generated', generated]));
    buf.writeln();
    buf.writeln(_row([
      'Session Date',
      'Product',
      'Unit',
      'Expected',
      'Counted',
      'Discrepancy',
    ]));

    for (final session in sessions) {
      final items = itemsBySession[session.id] ?? [];
      for (final item in items) {
        final disc = item.counted - item.expected;
        buf.writeln(_row([
          dateFmt.format(session.countedAt),
          item.productName,
          item.unit,
          item.expected.toStringAsFixed(3),
          item.counted.toStringAsFixed(3),
          disc.toStringAsFixed(3),
        ]));
      }
    }

    await _share(buf.toString(), 'count_history_$labName');
  }
}
