import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = MigraineRepository(await SharedPreferences.getInstance());
  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.repository});

  final MigraineRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Migraine Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9B73),
          primary: const Color(0xFFFF885B),
          secondary: const Color(0xFF5FB0B7),
          surface: const Color(0xFFFFF8F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F3),
        useMaterial3: true,
      ),
      home: MigraineJournalApp(repository: repository),
    );
  }
}

class MigraineJournalApp extends StatefulWidget {
  const MigraineJournalApp({super.key, required this.repository});

  final MigraineRepository repository;

  @override
  State<MigraineJournalApp> createState() => _MigraineJournalAppState();
}

class _MigraineJournalAppState extends State<MigraineJournalApp> {
  int _selectedIndex = 0;
  List<MigraineEntry> _entries = <MigraineEntry>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await widget.repository.loadEntries();
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _saveEntry(MigraineEntry entry) async {
    final updatedEntries = <MigraineEntry>[entry, ..._entries]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await widget.repository.saveEntries(updatedEntries);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = updatedEntries;
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        entryCount: _entries.length,
        onLogPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LogMigraineScreen(onSave: _saveEntry),
            ),
          );
        },
      ),
      HistoryScreen(entries: _entries),
      ReportsScreen(entries: _entries),
    ];

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(child: screens[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.summarize_outlined),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.entryCount,
    required this.onLogPressed,
  });

  final int entryCount;
  final VoidCallback onLogPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD6C5), Color(0xFFFFF0C9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Migraine Buddy',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A simple migraine tracker for kids and caregivers.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onLogPressed,
                icon: const Icon(Icons.add_circle_outline),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Log Migraine',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 88),
                  backgroundColor: const Color(0xFFFF885B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SummaryTile(
          title: 'Entries logged',
          value: '$entryCount',
          subtitle: entryCount == 0
              ? 'Start with the big button above.'
              : 'Nice work keeping track.',
        ),
        const SizedBox(height: 16),
        const _SummaryTile(
          title: 'Helpful reminders',
          value: '1',
          subtitle: 'Use the report tab to create a doctor-ready summary.',
        ),
      ],
    );
  }
}

class LogMigraineScreen extends StatefulWidget {
  const LogMigraineScreen({super.key, required this.onSave});

  final Future<void> Function(MigraineEntry entry) onSave;

  @override
  State<LogMigraineScreen> createState() => _LogMigraineScreenState();
}

class _LogMigraineScreenState extends State<LogMigraineScreen> {
  static const severityOptions = <SeverityOption>[
    SeverityOption(value: 1, emoji: '🙂', label: 'Tiny'),
    SeverityOption(value: 2, emoji: '😐', label: 'Mild'),
    SeverityOption(value: 3, emoji: '😣', label: 'Medium'),
    SeverityOption(value: 4, emoji: '😖', label: 'Big'),
    SeverityOption(value: 5, emoji: '😭', label: 'Huge'),
  ];

  static const triggerOptions = <TriggerOption>[
    TriggerOption(
      key: MigraineTrigger.weather,
      label: 'Weather',
      icon: Icons.cloud_outlined,
    ),
    TriggerOption(
      key: MigraineTrigger.food,
      label: 'Food',
      icon: Icons.restaurant_outlined,
    ),
    TriggerOption(
      key: MigraineTrigger.sleep,
      label: 'Sleep',
      icon: Icons.bedtime_outlined,
    ),
    TriggerOption(
      key: MigraineTrigger.screens,
      label: 'Screens',
      icon: Icons.tablet_mac_outlined,
    ),
    TriggerOption(
      key: MigraineTrigger.stress,
      label: 'Stress',
      icon: Icons.favorite_outline,
    ),
  ];

  int _severity = 3;
  final Set<MigraineTrigger> _selectedTriggers = <MigraineTrigger>{};
  final TextEditingController _durationController = TextEditingController();
  final DateTime _startedAt = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
    });
    final durationText = _durationController.text.trim();
    final durationMinutes = int.tryParse(durationText);
    final entry = MigraineEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      severity: _severity,
      triggers: _selectedTriggers.toList(),
      startedAt: _startedAt,
      durationMinutes: durationMinutes,
    );
    await widget.onSave(entry);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Log Migraine')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'How big did it feel?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: severityOptions.map((option) {
                final isSelected = option.value == _severity;
                return ChoiceChip(
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _severity = option.value;
                    });
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  label: SizedBox(
                    width: 78,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(option.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(
                          '${option.value} • ${option.label}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            Text(
              'What might have caused it?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: triggerOptions.map((option) {
                final isSelected = _selectedTriggers.contains(option.key);
                return FilterChip(
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      if (isSelected) {
                        _selectedTriggers.remove(option.key);
                      } else {
                        _selectedTriggers.add(option.key);
                      }
                    });
                  },
                  avatar: Icon(option.icon, size: 18),
                  label: Text(option.label),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            _InfoCard(
              title: 'Date and time',
              value: formatDateTime(_startedAt),
              helper: 'Filled in automatically.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration in minutes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 58),
              ),
              child: Text(_isSaving ? 'Saving...' : 'Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.entries});

  final List<MigraineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyState(
        title: 'No migraines logged yet',
        message: 'Tap Log Migraine on the home screen to create the first one.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: entries.length + 1,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            'History',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          );
        }

        final entry = entries[index - 1];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              child: Text(severityEmoji(entry.severity)),
            ),
            title: Text(
              '${formatDate(entry.startedAt)} at ${formatTime(entry.startedAt)}',
            ),
            subtitle: Text(
              [
                'Severity ${entry.severity}/5',
                if (entry.durationMinutes != null)
                  '${entry.durationMinutes} min',
                if (entry.triggers.isNotEmpty)
                  entry.triggers.map(triggerLabel).join(', '),
              ].join(' • '),
            ),
          ),
        );
      },
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.entries});

  final List<MigraineEntry> entries;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const _EmptyState(
        title: 'No reports yet',
        message: 'Reports appear after at least one migraine is logged.',
      );
    }

    final sortedEntries = [...widget.entries]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final defaultRange = DateTimeRange(
      start: sortedEntries.first.startedAt,
      end: sortedEntries.last.startedAt,
    );
    final activeRange = _range ?? defaultRange;
    final filteredEntries = widget.entries.where((entry) {
      final day = DateTime(
        entry.startedAt.year,
        entry.startedAt.month,
        entry.startedAt.day,
      );
      final start = DateTime(
        activeRange.start.year,
        activeRange.start.month,
        activeRange.start.day,
      );
      final end = DateTime(
        activeRange.end.year,
        activeRange.end.month,
        activeRange.end.day,
      );
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final summary = buildReportSummary(filteredEntries, activeRange);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Reports',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final pickedRange = await showDateRangePicker(
              context: context,
              firstDate: sortedEntries.first.startedAt.subtract(
                const Duration(days: 365),
              ),
              lastDate: DateTime.now().add(const Duration(days: 30)),
              initialDateRange: activeRange,
            );
            if (pickedRange != null) {
              setState(() {
                _range = pickedRange;
              });
            }
          },
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            '${formatDate(activeRange.start)} - ${formatDate(activeRange.end)}',
          ),
        ),
        const SizedBox(height: 16),
        _SummaryTile(
          title: 'Entries in range',
          value: '${filteredEntries.length}',
          subtitle: filteredEntries.isEmpty
              ? 'No migraines in this date range.'
              : 'Average severity ${averageSeverity(filteredEntries).toStringAsFixed(1)}/5',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doctor Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SelectableText(summary),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: summary));
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Summary copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy Summary'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MigraineEntry {
  const MigraineEntry({
    required this.id,
    required this.severity,
    required this.triggers,
    required this.startedAt,
    this.durationMinutes,
  });

  final String id;
  final int severity;
  final List<MigraineTrigger> triggers;
  final DateTime startedAt;
  final int? durationMinutes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'severity': severity,
      'triggers': triggers.map((trigger) => trigger.name).toList(),
      'startedAt': startedAt.toIso8601String(),
      'durationMinutes': durationMinutes,
    };
  }

  factory MigraineEntry.fromJson(Map<String, dynamic> json) {
    return MigraineEntry(
      id: json['id'] as String,
      severity: json['severity'] as int,
      triggers: (json['triggers'] as List<dynamic>)
          .map((value) => MigraineTrigger.values.byName(value as String))
          .toList(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      durationMinutes: json['durationMinutes'] as int?,
    );
  }
}

enum MigraineTrigger { weather, food, sleep, screens, stress }

class MigraineRepository {
  MigraineRepository(this._preferences);

  static const _storageKey = 'migraine_entries';
  final SharedPreferences _preferences;

  Future<List<MigraineEntry>> loadEntries() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <MigraineEntry>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => MigraineEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveEntries(List<MigraineEntry> entries) {
    final raw = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    return _preferences.setString(_storageKey, raw);
  }
}

class TriggerOption {
  const TriggerOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final MigraineTrigger key;
  final String label;
  final IconData icon;
}

class SeverityOption {
  const SeverityOption({
    required this.value,
    required this.emoji,
    required this.label,
  });

  final int value;
  final String emoji;
  final String label;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.helper,
  });

  final String title;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(helper),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 44),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String formatDateTime(DateTime value) {
  return '${formatDate(value)} at ${formatTime(value)}';
}

String formatDate(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String severityEmoji(int severity) {
  switch (severity) {
    case 1:
      return '🙂';
    case 2:
      return '😐';
    case 3:
      return '😣';
    case 4:
      return '😖';
    default:
      return '😭';
  }
}

String triggerLabel(MigraineTrigger trigger) {
  switch (trigger) {
    case MigraineTrigger.weather:
      return 'Weather';
    case MigraineTrigger.food:
      return 'Food';
    case MigraineTrigger.sleep:
      return 'Sleep';
    case MigraineTrigger.screens:
      return 'Screens';
    case MigraineTrigger.stress:
      return 'Stress';
  }
}

double averageSeverity(List<MigraineEntry> entries) {
  if (entries.isEmpty) {
    return 0;
  }
  final total = entries.fold<int>(0, (sum, entry) => sum + entry.severity);
  return total / entries.length;
}

String buildReportSummary(List<MigraineEntry> entries, DateTimeRange range) {
  if (entries.isEmpty) {
    return 'Migraine report for ${formatDate(range.start)} to ${formatDate(range.end)}.\nNo migraine entries were logged in this range.';
  }

  final triggerCounts = <MigraineTrigger, int>{};
  for (final entry in entries) {
    for (final trigger in entry.triggers) {
      triggerCounts.update(trigger, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  final sortedTriggers = triggerCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topTriggers = sortedTriggers.isEmpty
      ? 'None selected'
      : sortedTriggers
            .take(3)
            .map((entry) => '${triggerLabel(entry.key)} (${entry.value})')
            .join(', ');

  final lines = <String>[
    'Migraine report for ${formatDate(range.start)} to ${formatDate(range.end)}',
    'Total entries: ${entries.length}',
    'Average severity: ${averageSeverity(entries).toStringAsFixed(1)}/5',
    'Most common triggers: $topTriggers',
    '',
    'Log by day:',
    ...entries.map((entry) {
      final duration = entry.durationMinutes == null
          ? 'Duration not recorded'
          : 'Duration ${entry.durationMinutes} min';
      final triggers = entry.triggers.isEmpty
          ? 'No triggers selected'
          : entry.triggers.map(triggerLabel).join(', ');
      return '- ${formatDateTime(entry.startedAt)}: Severity ${entry.severity}/5. $duration. Triggers: $triggers.';
    }),
  ];
  return lines.join('\n');
}
