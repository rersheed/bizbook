import 'package:flutter_test/flutter_test.dart';
import 'package:bizbook/main.dart';

void main() {
  testWidgets('BizBookApp builds', (tester) async {
    await tester.pumpWidget(const BizBookApp());
    expect(find.byType(BizBookApp), findsOneWidget);
  });
}
