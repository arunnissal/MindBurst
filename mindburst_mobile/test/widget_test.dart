import 'package:flutter_test/flutter_test.dart';
import 'package:mindburst_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MindBurstApp());
    expect(find.byType(MindBurstApp), findsOneWidget);
  });
}
