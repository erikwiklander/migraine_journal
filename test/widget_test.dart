import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:migraine_journal/main.dart';

void main() {
  testWidgets('home screen shows the migraine logger entry point', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = MigraineRepository(await SharedPreferences.getInstance());

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Migraine Buddy'), findsOneWidget);
    expect(find.text('Log Migraine'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });
}
