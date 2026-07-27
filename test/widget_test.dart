import 'package:flutter_test/flutter_test.dart';

import 'package:matebooks/main.dart';
import 'package:matebooks/providers/log_provider.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MateBooksApp(logProvider: LogProvider()));
    expect(find.text('MateBooks'), findsOneWidget);
  });

  test('LogProvider captures and caps entries', () {
    final provider = LogProvider();

    provider.addLog('[DataLookupService] Attempt 1/3: Open Library API...');
    provider.addLog('[DataLookupService] Google Books: fetching isbn=1234567890');
    provider.addLog('[DataLookupService] Crossref succeeded: title="Test Book"');

    expect(provider.logs.length, 3);
    expect(provider.logs[0], contains('Open Library API'));
    expect(provider.logs[1], contains('Google Books'));
    expect(provider.logs[2], contains('Crossref succeeded'));
  });

  test('LogProvider clear removes all entries', () {
    final provider = LogProvider();

    provider.addLog('log 1');
    provider.addLog('log 2');
    provider.clear();

    expect(provider.logs, isEmpty);
  });

  test('LogProvider caps at 1000 entries', () {
    final provider = LogProvider();

    for (var i = 0; i < 1050; i++) {
      provider.addLog('log entry $i');
    }

    expect(provider.logs.length, 1000);
    expect(provider.logs.first, contains('log entry 50'));
    expect(provider.logs.last, contains('log entry 1049'));
  });
}
