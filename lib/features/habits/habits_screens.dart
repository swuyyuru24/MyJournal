import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';

class HabitsListScreen extends ConsumerWidget {
  const HabitsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final logsAsync = ref.watch(habitLogsForTodayProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Text('Plant your first habit',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      "Tiny actions, repeated kindly. Sow one habit you'd be proud to keep.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (logs) => ListView.builder(
              itemCount: habits.length,
              itemBuilder: (_, i) {
                final h = habits[i];
                final log = logs.where((l) => l.habitId == h.id).firstOrNull;
                return CheckboxListTile(
                  value: log?.completed ?? false,
                  title: Text(h.name),
                  subtitle: Text(
                      '${h.frequencyKind.label}${h.kind == HabitKind.numeric && h.targetPerOccurrence != null ? ' • ${h.targetPerOccurrence} ${h.unit ?? ''}' : ''}'),
                  secondary: const Icon(Icons.chevron_right),
                  onChanged: (v) async {
                    await ref.read(habitRepoProvider).upsertLog(
                          habitId: h.id,
                          date: DateTime.now(),
                          completed: v ?? false,
                        );
                    ref.invalidate(habitLogsForTodayProvider);
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/habits/new'),
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
    );
  }
}

class HabitEditScreen extends ConsumerStatefulWidget {
  const HabitEditScreen({super.key});
  @override
  ConsumerState<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends ConsumerState<HabitEditScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _unit = TextEditingController();
  final _target = TextEditingController();
  final _freqTarget = TextEditingController();
  HabitKind _kind = HabitKind.boolean;
  FrequencyKind _freqKind = FrequencyKind.daily;
  final Set<String> _goalIds = {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _unit.dispose();
    _target.dispose();
    _freqTarget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(habitRepoProvider).create(
            name: _name.text.trim(),
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            kind: _kind,
            unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
            targetPerOccurrence:
                num.tryParse(_target.text.trim()),
            frequencyKind: _freqKind,
            frequencyTarget: int.tryParse(_freqTarget.text.trim()),
            goalIds: _goalIds.toList(),
          );
      ref.invalidate(habitsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);
    final isNumeric = _kind == HabitKind.numeric;
    final needsFreqTarget = _freqKind == FrequencyKind.xPerWeek ||
        _freqKind == FrequencyKind.xPerMonth;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New habit'),
        actions: [
          TextButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: _desc,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 16),
          DropdownButtonFormField<HabitKind>(
            initialValue: _kind,
            decoration: const InputDecoration(
                labelText: 'Kind', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                  value: HabitKind.boolean, child: Text('Yes / No')),
              DropdownMenuItem(
                  value: HabitKind.numeric, child: Text('Numeric')),
            ],
            onChanged: (v) => setState(() => _kind = v!),
          ),
          if (isNumeric) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _target,
                  decoration: const InputDecoration(
                      labelText: 'Target per occurrence',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(
                      labelText: 'Unit (e.g. min, pages)',
                      border: OutlineInputBorder()),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<FrequencyKind>(
            initialValue: _freqKind,
            decoration: const InputDecoration(
                labelText: 'Frequency', border: OutlineInputBorder()),
            items: [
              for (final f in FrequencyKind.values)
                DropdownMenuItem(value: f, child: Text(f.label)),
            ],
            onChanged: (v) => setState(() => _freqKind = v!),
          ),
          if (needsFreqTarget) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _freqTarget,
              decoration: const InputDecoration(
                  labelText: 'How many times',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 24),
          Text('Link to goals', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          goalsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (goals) {
              if (goals.isEmpty) {
                return const Text('No goals yet. Create a goal first to link.');
              }
              return Wrap(
                spacing: 8,
                children: [
                  for (final g in goals)
                    FilterChip(
                      label: Text(g.title),
                      selected: _goalIds.contains(g.id),
                      onSelected: (s) {
                        setState(() {
                          if (s) {
                            _goalIds.add(g.id);
                          } else {
                            _goalIds.remove(g.id);
                          }
                        });
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
