import 'package:flutter_test/flutter_test.dart';

import 'package:matebooks/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MateBooksApp());
    expect(find.text('MateBooks'), findsOneWidget);
  });
}
