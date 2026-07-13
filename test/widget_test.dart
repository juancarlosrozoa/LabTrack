import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:labtrack/shared/widgets/stock_status_badge.dart';

void main() {
  testWidgets('StockStatusBadge shows the correct label per status',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StockStatusBadge(status: StockStatus.critical)),
      ),
    );

    expect(find.text('Critical'), findsOneWidget);
  });
}
