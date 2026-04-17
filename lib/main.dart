import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateTimeRange, SelectableText;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
    const accentColor = Color(0xFF0A84FF);

    return CupertinoApp(
      title: 'Aida Migraine Journal',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        primaryColor: accentColor,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
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
  List<String> _customTriggers = <String>[];
  List<String> _rankedTriggers = <String>[];
  bool _showSavedConfirmation = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await widget.repository.loadEntries();
    final customTriggers = await widget.repository.loadCustomTriggers();
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _customTriggers = customTriggers;
      _rankedTriggers = rankedTriggerLabels(entries);
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
      _rankedTriggers = rankedTriggerLabels(updatedEntries);
      _selectedIndex = 0;
      _showSavedConfirmation = true;
    });
  }

  Future<String> _saveCustomTrigger(String label) async {
    final trimmedLabel = titleCaseWords(label.trim());
    final existingLabels = <String>{
      ...defaultTriggerOptions.map((option) => option.label),
      ..._customTriggers,
    };
    final matchingLabel = existingLabels.cast<String?>().firstWhere(
      (value) =>
          normalizeTriggerKey(value!) == normalizeTriggerKey(trimmedLabel),
      orElse: () => null,
    );
    if (matchingLabel != null) {
      return matchingLabel;
    }

    final updatedCustomTriggers = <String>[..._customTriggers, trimmedLabel]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await widget.repository.saveCustomTriggers(updatedCustomTriggers);
    if (!mounted) {
      return trimmedLabel;
    }
    setState(() {
      _customTriggers = updatedCustomTriggers;
    });
    return trimmedLabel;
  }

  Future<void> _deleteCustomTrigger(String label) async {
    final updatedCustomTriggers =
        _customTriggers
            .where(
              (trigger) =>
                  normalizeTriggerKey(trigger) != normalizeTriggerKey(label),
            )
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await widget.repository.saveCustomTriggers(updatedCustomTriggers);
    if (!mounted) {
      return;
    }
    setState(() {
      _customTriggers = updatedCustomTriggers;
    });
  }

  Future<void> _deleteEntry(String entryId) async {
    final updatedEntries =
        _entries.where((entry) => entry.id != entryId).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await widget.repository.saveEntries(updatedEntries);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = updatedEntries;
      _rankedTriggers = rankedTriggerLabels(updatedEntries);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    final screens = <Widget>[
      HomeScreen(
        showSavedConfirmation: _showSavedConfirmation,
        onLogPressed: () {
          setState(() {
            _showSavedConfirmation = false;
          });
          Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => LogMigraineScreen(
                onSave: _saveEntry,
                customTriggers: _customTriggers,
                rankedTriggers: _rankedTriggers,
                onAddCustomTrigger: _saveCustomTrigger,
                onDeleteCustomTrigger: _deleteCustomTrigger,
              ),
            ),
          );
        },
      ),
      HistoryScreen(entries: _entries, onDeleteEntry: _deleteEntry),
      ReportsScreen(entries: _entries),
    ];

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index != 0) {
              _showSavedConfirmation = false;
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.time),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            label: 'Reports',
          ),
        ],
      ),
      tabBuilder: (_, index) => screens[index],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onLogPressed,
    required this.showSavedConfirmation,
  });

  final VoidCallback onLogPressed;
  final bool showSavedConfirmation;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text('Aida', style: theme.textTheme.navLargeTitleTextStyle),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF4F8FF), Color(0xFFE8F1FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A simple migraine tracker for kids and caregivers.',
                    style: theme.textTheme.textStyle.copyWith(
                      color: CupertinoColors.secondaryLabel,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: onLogPressed,
                      borderRadius: BorderRadius.circular(18),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: const Text(
                        'Log Migraine',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (showSavedConfirmation) ...[
                    const SizedBox(height: 14),
                    Text(
                      'I hope you feel better.',
                      style: theme.textTheme.textStyle.copyWith(
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LogMigraineScreen extends StatefulWidget {
  const LogMigraineScreen({
    super.key,
    required this.onSave,
    required this.customTriggers,
    required this.rankedTriggers,
    required this.onAddCustomTrigger,
    required this.onDeleteCustomTrigger,
  });

  final Future<void> Function(MigraineEntry entry) onSave;
  final List<String> customTriggers;
  final List<String> rankedTriggers;
  final Future<String> Function(String label) onAddCustomTrigger;
  final Future<void> Function(String label) onDeleteCustomTrigger;

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

  int _severity = 3;
  final Set<String> _selectedTriggers = <String>{};
  late List<String> _customTriggers;
  final TextEditingController _durationController = TextEditingController();
  DateTime _startedAt = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _customTriggers = [...widget.customTriggers];
  }

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
      triggers: _selectedTriggers.toList()..sort(),
      startedAt: _startedAt,
      durationMinutes: durationMinutes,
    );
    await widget.onSave(entry);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickStartedAt() async {
    var selectedDate = _startedAt;

    final pickedDate = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) {
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(selectedDate),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _startedAt,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (value) {
                    selectedDate = DateTime(
                      value.year,
                      value.month,
                      value.day,
                      selectedDate.hour,
                      selectedDate.minute,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    selectedDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      _startedAt.hour,
      _startedAt.minute,
    );

    final pickedTime = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) {
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(selectedDate),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: selectedDate,
                  onDateTimeChanged: (value) {
                    selectedDate = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      value.hour,
                      value.minute,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _startedAt = pickedTime;
    });
  }

  Future<void> _showAddCustomTriggerSheet() async {
    final controller = TextEditingController();
    String? errorText;

    final label = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  final value = controller.text.trim();
                                  if (value.isEmpty) {
                                    setModalState(() {
                                      errorText = 'Enter a trigger name first.';
                                    });
                                    return;
                                  }
                                  Navigator.of(context).pop(value);
                                },
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                          Text(
                            'Add your own trigger',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .navTitleTextStyle
                                .copyWith(fontSize: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This will be saved for next time too.',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  color: CupertinoColors.secondaryLabel,
                                ),
                          ),
                          const SizedBox(height: 16),
                          CupertinoTextField(
                            controller: controller,
                            autofocus: true,
                            placeholder: 'Example: Dehydration',
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            onChanged: (_) {
                              if (errorText != null) {
                                setModalState(() {
                                  errorText = null;
                                });
                              }
                            },
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              errorText!,
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    color: CupertinoColors.destructiveRed,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();

    if (label == null || !mounted) {
      return;
    }

    final savedLabel = await widget.onAddCustomTrigger(label);
    if (!mounted) {
      return;
    }
    setState(() {
      if (!_customTriggers.contains(savedLabel)) {
        _customTriggers = [..._customTriggers, savedLabel]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
      _selectedTriggers.add(savedLabel);
    });
  }

  Future<void> _showAllTriggersSheet(
    List<TriggerOption> allTriggerOptions,
  ) async {
    final result = await showCupertinoModalPopup<Object?>(
      context: context,
      builder: (context) {
        final localSelection = <String>{..._selectedTriggers};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 420,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(<String, Object?>{'selection': localSelection}),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                    Text(
                      'All triggers',
                      style: CupertinoTheme.of(
                        context,
                      ).textTheme.navTitleTextStyle.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose any triggers you want to include.',
                      style: CupertinoTheme.of(context).textTheme.textStyle
                          .copyWith(color: CupertinoColors.secondaryLabel),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: allTriggerOptions.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final option = allTriggerOptions[index];
                          final isSelected = localSelection.contains(
                            option.label,
                          );
                          final row = CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setModalState(() {
                                if (isSelected) {
                                  localSelection.remove(option.label);
                                } else {
                                  localSelection.add(option.label);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? CupertinoColors.activeBlue
                                    : CupertinoColors
                                          .secondarySystemGroupedBackground
                                          .resolveFrom(context),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    option.icon,
                                    color: isSelected
                                        ? CupertinoColors.white
                                        : CupertinoColors.activeBlue,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: CupertinoTheme.of(context)
                                          .textTheme
                                          .textStyle
                                          .copyWith(
                                            color: isSelected
                                                ? CupertinoColors.white
                                                : CupertinoColors.label,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? CupertinoIcons
                                              .check_mark_circled_solid
                                        : CupertinoIcons.circle,
                                    color: isSelected
                                        ? CupertinoColors.white
                                        : CupertinoColors.systemGrey,
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (!option.isCustom) {
                            return row;
                          }

                          return Dismissible(
                            key: ValueKey('custom-trigger-${option.key}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              final navigator = Navigator.of(context);
                              final shouldDelete =
                                  await showCupertinoDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return CupertinoAlertDialog(
                                        title: const Text(
                                          'Delete Custom Reason?',
                                        ),
                                        content: Text(
                                          '"${option.label}" will no longer appear as a reusable reason.',
                                        ),
                                        actions: [
                                          CupertinoDialogAction(
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          CupertinoDialogAction(
                                            isDestructiveAction: true,
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                              if (shouldDelete == true) {
                                navigator.pop(<String, Object?>{
                                  'delete': option.label,
                                });
                              }
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                color: CupertinoColors.destructiveRed,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                CupertinoIcons.delete,
                                color: CupertinoColors.white,
                              ),
                            ),
                            child: row,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    if (result is Map<String, Object?> && result['delete'] is String) {
      final deletedLabel = result['delete']! as String;
      await widget.onDeleteCustomTrigger(deletedLabel);
      if (!mounted) {
        return;
      }
      setState(() {
        _customTriggers =
            _customTriggers
                .where(
                  (trigger) =>
                      normalizeTriggerKey(trigger) !=
                      normalizeTriggerKey(deletedLabel),
                )
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _selectedTriggers.removeWhere(
          (trigger) =>
              normalizeTriggerKey(trigger) == normalizeTriggerKey(deletedLabel),
        );
      });
      return;
    }

    if (result is! Map<String, Object?> ||
        result['selection'] is! Set<String>) {
      return;
    }
    final updatedSelection = result['selection']! as Set<String>;

    setState(() {
      _selectedTriggers
        ..clear()
        ..addAll(updatedSelection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final allTriggerOptions = <TriggerOption>[
      ..._customTriggers.map(
        (label) => TriggerOption(
          key: normalizeTriggerKey(label),
          label: label,
          icon: iconForCustomTrigger(label),
          isCustom: true,
        ),
      ),
      ...defaultTriggerOptions,
    ];
    final triggerOptions = visibleTriggerOptionsForLogScreen(
      allOptions: allTriggerOptions,
      rankedTriggerLabels: widget.rankedTriggers,
      selectedTriggerLabels: _selectedTriggers,
    );

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Log Migraine')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'How bad is it?',
              style: theme.textTheme.navTitleTextStyle,
            ),
            const SizedBox(height: 12),
            Row(
              children: severityOptions.map((option) {
                final isSelected = option.value == _severity;
                final isLast = identical(option, severityOptions.last);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                    child: _SelectablePill(
                      isSelected: isSelected,
                      onPressed: () {
                        setState(() {
                          _severity = option.value;
                        });
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.label,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.textStyle.copyWith(
                              fontSize: 11,
                              color: isSelected
                                  ? CupertinoColors.white
                                  : CupertinoColors.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            Text(
              'What might have caused it?',
              style: theme.textTheme.navTitleTextStyle,
            ),
            const SizedBox(height: 4),
            Text(
              'Optional. Tap all that fit.',
              style: theme.textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ...triggerOptions.map((option) {
                  final isSelected = _selectedTriggers.contains(option.label);
                  return _SelectablePill(
                    isSelected: isSelected,
                    onPressed: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTriggers.remove(option.label);
                        } else {
                          _selectedTriggers.add(option.label);
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.icon,
                          size: 18,
                          color: isSelected
                              ? CupertinoColors.white
                              : CupertinoColors.activeBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          option.label,
                          style: theme.textTheme.textStyle.copyWith(
                            color: isSelected
                                ? CupertinoColors.white
                                : CupertinoColors.label,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                _SelectablePill(
                  isSelected: false,
                  onPressed: () => _showAllTriggersSheet(allTriggerOptions),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.ellipsis_circle,
                        size: 18,
                        color: CupertinoColors.activeBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'More triggers',
                        style: theme.textTheme.textStyle.copyWith(
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                _SelectablePill(
                  isSelected: false,
                  onPressed: _showAddCustomTriggerSheet,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.add_circled,
                        size: 18,
                        color: CupertinoColors.activeBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add your own',
                        style: theme.textTheme.textStyle.copyWith(
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _GroupedCard(
              child: Column(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickStartedAt,
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.calendar,
                          color: CupertinoColors.activeBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Started',
                                style: theme.textTheme.textStyle.copyWith(
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatDateTime(_startedAt),
                                style: theme.textTheme.textStyle,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.chevron_forward,
                          size: 18,
                          color: CupertinoColors.systemGrey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(
                        context,
                      ),
                      border: Border.all(
                        color: CupertinoColors.systemGrey4.resolveFrom(context),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Duration',
                              style: theme.textTheme.textStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Optional',
                              style: theme.textTheme.textStyle.copyWith(
                                color: CupertinoColors.secondaryLabel,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CupertinoTextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          placeholder: 'How many minutes did it last?',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6.resolveFrom(
                              context,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            CupertinoButton.filled(
              onPressed: _isSaving ? null : _submit,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_isSaving ? 'Saving...' : 'Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.entries,
    required this.onDeleteEntry,
  });

  final List<MigraineEntry> entries;
  final Future<void> Function(String entryId) onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const CupertinoPageScaffold(
        child: _EmptyState(
          title: 'No migraines logged yet',
          message:
              'Tap Log Migraine on the home screen to create the first one.',
        ),
      );
    }

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: entries.length + 1,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                'History',
                style: CupertinoTheme.of(
                  context,
                ).textTheme.navLargeTitleTextStyle,
              );
            }

            final entry = entries[index - 1];
            final subtitleParts = <String>[
              'Severity ${entry.severity}/5',
              if (entry.durationMinutes != null) '${entry.durationMinutes} min',
              if (entry.triggers.isNotEmpty) entry.triggers.join(', '),
            ];

            return _GroupedCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      severityEmoji(entry.severity),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatDate(entry.startedAt)} at ${formatTime(entry.startedAt)}',
                          style: CupertinoTheme.of(
                            context,
                          ).textTheme.navTitleTextStyle.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitleParts.join(' • '),
                          style: const TextStyle(
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () async {
                      final shouldDelete = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (context) {
                          return CupertinoAlertDialog(
                            title: const Text('Delete Entry?'),
                            content: Text(
                              '${formatDate(entry.startedAt)} at ${formatTime(entry.startedAt)} will be removed from history.',
                            ),
                            actions: [
                              CupertinoDialogAction(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              CupertinoDialogAction(
                                isDestructiveAction: true,
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                      if (shouldDelete == true) {
                        await onDeleteEntry(entry.id);
                      }
                    },
                    child: const Icon(
                      CupertinoIcons.delete,
                      color: CupertinoColors.destructiveRed,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    required DateTime minimumDate,
    required DateTime maximumDate,
  }) async {
    var selectedDate = initialDate;

    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) {
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(selectedDate),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: minimumDate,
                  maximumDate: maximumDate,
                  onDateTimeChanged: (value) {
                    selectedDate = value;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickRange(
    DateTimeRange activeRange,
    DateTime minimumDate,
    DateTime maximumDate,
  ) async {
    final startDate = await _pickDate(
      initialDate: activeRange.start,
      minimumDate: minimumDate,
      maximumDate: activeRange.end,
    );
    if (startDate == null || !mounted) {
      return;
    }

    final endDate = await _pickDate(
      initialDate: activeRange.end.isBefore(startDate)
          ? startDate
          : activeRange.end,
      minimumDate: startDate,
      maximumDate: maximumDate,
    );
    if (endDate == null || !mounted) {
      return;
    }

    setState(() {
      _range = DateTimeRange(start: startDate, end: endDate);
    });
  }

  Future<void> _copySummary(String summary) async {
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) {
      return;
    }

    await showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Summary Copied'),
          content: const Text('The doctor summary is on the clipboard.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List> _buildReportPdfBytes(
    List<MigraineEntry> entries,
    DateTimeRange range,
  ) async {
    final document = pw.Document();
    final topTriggers = summarizeTopTriggers(entries);
    final rows = entries
        .map(
          (entry) => <String>[
            formatDateTime(entry.startedAt),
            '${entry.severity}/5',
            entry.durationMinutes == null
                ? 'Not recorded'
                : '${entry.durationMinutes} min',
            entry.triggers.isEmpty ? 'None' : entry.triggers.join(', '),
          ],
        )
        .toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Aida Migraine Journal',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Doctor Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Range: ${formatDate(range.start)} to ${formatDate(range.end)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Entries: ${entries.length}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            entries.isEmpty
                ? 'Average severity: N/A'
                : 'Average severity: ${averageSeverity(entries).toStringAsFixed(1)}/5',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Most common triggers: $topTriggers',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 18),
          if (rows.isEmpty)
            pw.Text(
              'No migraine entries were logged in this range.',
              style: const pw.TextStyle(fontSize: 12),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const <String>[
                'Date/Time',
                'Severity',
                'Duration',
                'Triggers',
              ],
              data: rows,
              headerStyle: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              columnWidths: <int, pw.TableColumnWidth>{
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(0.9),
                2: const pw.FlexColumnWidth(1.1),
                3: const pw.FlexColumnWidth(2.2),
              },
            ),
        ],
      ),
    );

    return document.save();
  }

  Future<void> _exportPdf(
    List<MigraineEntry> entries,
    DateTimeRange range,
  ) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Export PDF'),
          message: const Text('Print it or save a PDF copy to Files.'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('print'),
              child: const Text('Print PDF'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('share'),
              child: const Text('Save or Share PDF'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (action == null) {
      return;
    }

    final pdfBytes = await _buildReportPdfBytes(entries, range);
    final fileName =
        'aida-migraine-report-${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}-to-${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}.pdf';

    if (action == 'print') {
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      return;
    }

    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const CupertinoPageScaffold(
        child: _EmptyState(
          title: 'No reports yet',
          message: 'Reports appear after at least one migraine is logged.',
        ),
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
    }).toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final summary = buildReportSummary(filteredEntries, activeRange);
    final minDate = sortedEntries.first.startedAt.subtract(
      const Duration(days: 365),
    );
    final maxDate = DateTime.now().add(const Duration(days: 30));

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Reports',
              style: CupertinoTheme.of(
                context,
              ).textTheme.navLargeTitleTextStyle,
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _pickRange(activeRange, minDate, maxDate),
              child: _GroupedCard(
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.calendar,
                      color: CupertinoColors.activeBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${formatDate(activeRange.start)} - ${formatDate(activeRange.end)}',
                        style: CupertinoTheme.of(context).textTheme.textStyle,
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.chevron_forward,
                      size: 18,
                      color: CupertinoColors.systemGrey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _StatCard(
              title: 'Entries in range',
              value: '${filteredEntries.length}',
              subtitle: filteredEntries.isEmpty
                  ? 'No migraines in this date range.'
                  : 'Average severity ${averageSeverity(filteredEntries).toStringAsFixed(1)}/5',
            ),
            const SizedBox(height: 14),
            _GroupedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doctor Summary',
                    style: CupertinoTheme.of(
                      context,
                    ).textTheme.navTitleTextStyle.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(summary),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      onPressed: () => _exportPdf(filteredEntries, activeRange),
                      borderRadius: BorderRadius.circular(14),
                      color: CupertinoColors.systemGrey5,
                      child: const Text('Export PDF'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: () => _copySummary(summary),
                      borderRadius: BorderRadius.circular(14),
                      child: const Text('Copy Summary'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
  final List<String> triggers;
  final DateTime startedAt;
  final int? durationMinutes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'severity': severity,
      'triggers': triggers,
      'startedAt': startedAt.toIso8601String(),
      'durationMinutes': durationMinutes,
    };
  }

  factory MigraineEntry.fromJson(Map<String, dynamic> json) {
    return MigraineEntry(
      id: json['id'] as String,
      severity: json['severity'] as int,
      triggers: (json['triggers'] as List<dynamic>)
          .map((value) => decodeTrigger(value as String))
          .toList(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      durationMinutes: json['durationMinutes'] as int?,
    );
  }
}

class MigraineRepository {
  MigraineRepository(this._preferences);

  static const _storageKey = 'migraine_entries';
  static const _customTriggerStorageKey = 'migraine_custom_triggers';
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

  Future<List<String>> loadCustomTriggers() async {
    final triggers = _preferences.getStringList(_customTriggerStorageKey);
    if (triggers == null) {
      return <String>[];
    }
    return triggers
        .where((trigger) => trigger.trim().isNotEmpty)
        .map(titleCaseWords)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> saveCustomTriggers(List<String> triggers) {
    return _preferences.setStringList(_customTriggerStorageKey, triggers);
  }
}

class TriggerOption {
  const TriggerOption({
    required this.key,
    required this.label,
    required this.icon,
    this.isCustom = false,
  });

  final String key;
  final String label;
  final IconData icon;
  final bool isCustom;
}

const defaultTriggerOptions = <TriggerOption>[
  TriggerOption(key: 'weather', label: 'Weather', icon: CupertinoIcons.cloud),
  TriggerOption(
    key: 'food',
    label: 'Food',
    icon: CupertinoIcons.square_favorites_alt,
  ),
  TriggerOption(key: 'sleep', label: 'Sleep', icon: CupertinoIcons.moon),
  TriggerOption(
    key: 'screens',
    label: 'Screens',
    icon: CupertinoIcons.device_phone_portrait,
  ),
  TriggerOption(key: 'stress', label: 'Stress', icon: CupertinoIcons.heart),
];

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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _GroupedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: CupertinoTheme.of(
              context,
            ).textTheme.navTitleTextStyle.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: CupertinoTheme.of(context).textTheme.textStyle),
        ],
      ),
    );
  }
}

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _SelectablePill extends StatelessWidget {
  const _SelectablePill({
    required this.isSelected,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  });

  final bool isSelected;
  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: padding,
      minimumSize: Size.zero,
      color: isSelected
          ? CupertinoColors.activeBlue
          : CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
      borderRadius: BorderRadius.circular(18),
      onPressed: onPressed,
      child: child,
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
            const Icon(
              CupertinoIcons.waveform_path_ecg,
              size: 44,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
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

String normalizeTriggerKey(String value) {
  return value.trim().toLowerCase();
}

String titleCaseWords(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

IconData iconForCustomTrigger(String label) {
  final normalized = normalizeTriggerKey(label);

  if (_containsAny(normalized, <String>[
    'candy',
    'sugar',
    'sweet',
    'snack',
    'food',
    'meal',
    'chocolate',
  ])) {
    return CupertinoIcons.square_favorites_alt;
  }
  if (_containsAny(normalized, <String>[
    'water',
    'dehydr',
    'drink',
    'thirst',
  ])) {
    return CupertinoIcons.drop;
  }
  if (_containsAny(normalized, <String>[
    'sleep',
    'tired',
    'nap',
    'bed',
    'late night',
  ])) {
    return CupertinoIcons.moon;
  }
  if (_containsAny(normalized, <String>[
    'screen',
    'phone',
    'tablet',
    'computer',
    'tv',
    'video game',
  ])) {
    return CupertinoIcons.device_phone_portrait;
  }
  if (_containsAny(normalized, <String>[
    'stress',
    'anxiety',
    'worry',
    'overwhelm',
    'upset',
  ])) {
    return CupertinoIcons.heart;
  }
  if (_containsAny(normalized, <String>[
    'weather',
    'rain',
    'storm',
    'sun',
    'heat',
    'cold',
    'humid',
    'pollen',
    'allergy',
  ])) {
    return CupertinoIcons.cloud;
  }
  if (_containsAny(normalized, <String>[
    'school',
    'homework',
    'class',
    'teacher',
    'test',
    'exam',
    'study',
    'reading',
  ])) {
    return CupertinoIcons.book;
  }
  if (_containsAny(normalized, <String>['sound', 'noise', 'loud', 'music'])) {
    return CupertinoIcons.speaker_2;
  }
  if (_containsAny(normalized, <String>[
    'light',
    'bright',
    'sunlight',
    'lamp',
  ])) {
    return CupertinoIcons.sun_max;
  }
  if (_containsAny(normalized, <String>[
    'car',
    'travel',
    'drive',
    'ride',
    'motion',
  ])) {
    return CupertinoIcons.car;
  }

  return CupertinoIcons.tag;
}

bool _containsAny(String value, List<String> candidates) {
  for (final candidate in candidates) {
    if (value.contains(candidate)) {
      return true;
    }
  }
  return false;
}

String decodeTrigger(String rawValue) {
  final builtIn = defaultTriggerOptions.cast<TriggerOption?>().firstWhere(
    (option) => option!.key == rawValue,
    orElse: () => null,
  );
  return builtIn?.label ?? rawValue;
}

List<String> rankedTriggerLabels(List<MigraineEntry> entries) {
  final usageCounts = <String, int>{};
  final latestUse = <String, DateTime>{};
  final displayLabels = <String, String>{};

  for (final entry in entries) {
    for (final trigger in entry.triggers) {
      final normalized = normalizeTriggerKey(trigger);
      usageCounts.update(normalized, (count) => count + 1, ifAbsent: () => 1);
      final previousLatest = latestUse[normalized];
      if (previousLatest == null || entry.startedAt.isAfter(previousLatest)) {
        latestUse[normalized] = entry.startedAt;
        displayLabels[normalized] = trigger;
      }
    }
  }

  final rankedKeys = usageCounts.keys.toList()
    ..sort((a, b) {
      final countCompare = usageCounts[b]!.compareTo(usageCounts[a]!);
      if (countCompare != 0) {
        return countCompare;
      }
      final latestCompare = latestUse[b]!.compareTo(latestUse[a]!);
      if (latestCompare != 0) {
        return latestCompare;
      }
      return displayLabels[a]!.toLowerCase().compareTo(
        displayLabels[b]!.toLowerCase(),
      );
    });

  return rankedKeys.map((key) => displayLabels[key]!).toList();
}

List<TriggerOption> visibleTriggerOptionsForLogScreen({
  required List<TriggerOption> allOptions,
  required List<String> rankedTriggerLabels,
  required Set<String> selectedTriggerLabels,
}) {
  const baselineCount = 7;
  final byNormalizedLabel = <String, TriggerOption>{
    for (final option in allOptions) normalizeTriggerKey(option.label): option,
  };
  final baselineLabels = <String>[];
  final seen = <String>{};

  for (final label in rankedTriggerLabels) {
    final normalized = normalizeTriggerKey(label);
    if (byNormalizedLabel.containsKey(normalized) && seen.add(normalized)) {
      baselineLabels.add(normalized);
    }
    if (baselineLabels.length >= baselineCount) {
      break;
    }
  }

  for (final option in allOptions) {
    if (baselineLabels.length >= baselineCount) {
      break;
    }
    final normalized = normalizeTriggerKey(option.label);
    if (seen.add(normalized)) {
      baselineLabels.add(normalized);
    }
  }

  final visibleLabels = <String>[...baselineLabels];
  for (final label in selectedTriggerLabels) {
    final normalized = normalizeTriggerKey(label);
    if (byNormalizedLabel.containsKey(normalized) &&
        !visibleLabels.contains(normalized)) {
      visibleLabels.add(normalized);
    }
  }

  if (visibleLabels.isEmpty) {
    for (final option in allOptions.take(baselineCount)) {
      final normalized = normalizeTriggerKey(option.label);
      if (!visibleLabels.contains(normalized)) {
        visibleLabels.add(normalized);
      }
    }
  }

  return visibleLabels.map((label) => byNormalizedLabel[label]!).toList();
}

String summarizeTopTriggers(List<MigraineEntry> entries) {
  final triggerCounts = <String, int>{};
  for (final entry in entries) {
    for (final trigger in entry.triggers) {
      triggerCounts.update(trigger, (count) => count + 1, ifAbsent: () => 1);
    }
  }

  final sortedTriggers = triggerCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  if (sortedTriggers.isEmpty) {
    return 'None selected';
  }

  return sortedTriggers
      .take(3)
      .map((entry) => '${entry.key} (${entry.value})')
      .join(', ');
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

  final triggerCounts = <String, int>{};
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
            .map((entry) => '${entry.key} (${entry.value})')
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
          : entry.triggers.join(', ');
      return '- ${formatDateTime(entry.startedAt)}: Severity ${entry.severity}/5. $duration. Triggers: $triggers.';
    }),
  ];
  return lines.join('\n');
}
