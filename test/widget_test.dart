import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:migraine_journal/main.dart';

void main() {
  test('titleCaseWords capitalizes custom trigger labels', () {
    expect(titleCaseWords('candy'), 'Candy');
    expect(titleCaseWords('too much sugar'), 'Too Much Sugar');
  });

  test('ranked trigger labels prefer most used triggers', () {
    final entries = <MigraineEntry>[
      MigraineEntry(
        id: '3',
        severity: 4,
        triggers: <String>['Food', 'Pollen'],
        startedAt: DateTime(2026, 4, 11, 12),
      ),
      MigraineEntry(
        id: '2',
        severity: 2,
        triggers: <String>['Weather', 'Pollen'],
        startedAt: DateTime(2026, 4, 10, 12),
      ),
      MigraineEntry(
        id: '1',
        severity: 3,
        triggers: <String>['Food', 'Weather'],
        startedAt: DateTime(2026, 4, 8, 12),
      ),
    ];

    expect(rankedTriggerLabels(entries), <String>['Food', 'Pollen', 'Weather']);
  });

  test('selected custom trigger is appended to baseline visible triggers', () {
    final visible = visibleTriggerOptionsForLogScreen(
      allOptions: <TriggerOption>[
        ...defaultTriggerOptions,
        TriggerOption(
          key: 'candy',
          label: 'Candy',
          icon: iconForCustomTrigger('Candy'),
          isCustom: true,
        ),
      ],
      rankedTriggerLabels: <String>['Weather'],
      selectedTriggerLabels: <String>{'Candy'},
    );

    expect(visible.map((option) => option.label).toList(), <String>[
      'Weather',
      'Food',
      'Sleep',
      'Screens',
      'Stress',
      'Candy',
    ]);
  });

  test('custom trigger icon matcher uses reasonable heuristics', () {
    expect(iconForCustomTrigger('Candy'), CupertinoIcons.square_favorites_alt);
    expect(iconForCustomTrigger('School Stress'), CupertinoIcons.heart);
    expect(iconForCustomTrigger('Dehydration'), CupertinoIcons.drop);
  });

  test('custom triggers are saved for reuse', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = MigraineRepository(
      await SharedPreferences.getInstance(),
    );

    await repository.saveCustomTriggers(<String>['Dehydration', 'Pollen']);

    expect(await repository.loadCustomTriggers(), <String>[
      'Dehydration',
      'Pollen',
    ]);
  });

  test('old saved custom triggers are normalized on load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'migraine_custom_triggers': <String>['candy', 'too much sugar'],
    });
    final repository = MigraineRepository(
      await SharedPreferences.getInstance(),
    );

    expect(await repository.loadCustomTriggers(), <String>[
      'Candy',
      'Too Much Sugar',
    ]);
  });

  test('custom trigger list can be updated to remove an item', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'migraine_custom_triggers': <String>['Candy', 'Dehydration'],
    });
    final repository = MigraineRepository(
      await SharedPreferences.getInstance(),
    );

    await repository.saveCustomTriggers(<String>['Dehydration']);

    expect(await repository.loadCustomTriggers(), <String>['Dehydration']);
  });

  test('malformed saved entries fall back to an empty list', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'migraine_entries': 'not valid json',
    });
    final repository = MigraineRepository(
      await SharedPreferences.getInstance(),
    );

    expect(await repository.loadEntries(), isEmpty);
  });

  test('invalid saved entries are skipped while valid entries still load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'migraine_entries':
          '[{"id":"entry-1","severity":3,"triggers":["weather"],"startedAt":"2026-04-08T14:30:00.000","durationMinutes":45},{"id":"entry-2","severity":"bad","triggers":[],"startedAt":"2026-04-08T15:30:00.000"}]',
    });
    final repository = MigraineRepository(
      await SharedPreferences.getInstance(),
    );

    final entries = await repository.loadEntries();

    expect(entries, hasLength(1));
    expect(entries.single.id, 'entry-1');
  });

  test('clampToNow prevents future timestamps', () {
    final now = DateTime(2026, 4, 17, 10, 30);

    expect(
      clampToNow(DateTime(2026, 4, 17, 11), now: now),
      now,
    );
    expect(
      clampToNow(DateTime(2026, 4, 17, 9), now: now),
      DateTime(2026, 4, 17, 9),
    );
  });

  testWidgets('home screen shows the migraine logger entry point', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = MigraineRepository(
      await SharedPreferences.getInstance(),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Aida'), findsOneWidget);
    expect(find.text('Log Migraine'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('history entry deletes only after confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'migraine_entries':
          '[{"id":"entry-1","severity":3,"triggers":["weather"],"startedAt":"2026-04-08T14:30:00.000","durationMinutes":45}]',
    });
    final repository = MigraineRepository(
      await SharedPreferences.getInstance(),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Apr 8, 2026 at 2:30 PM'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Delete Entry?'), findsOneWidget);
    expect(find.text('Apr 8, 2026 at 2:30 PM'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Entry?'), findsNothing);
    expect(find.text('Apr 8, 2026 at 2:30 PM'), findsNothing);
    expect(find.text('No migraines logged yet'), findsOneWidget);
  });

  testWidgets('saving an entry returns home and shows confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = MigraineRepository(
      await SharedPreferences.getInstance(),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Migraine'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Aida'), findsOneWidget);
    expect(find.text('I hope you feel better.'), findsOneWidget);
  });
}
