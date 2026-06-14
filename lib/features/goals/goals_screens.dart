import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';

class GoalsListScreen extends ConsumerWidget {
  const GoalsListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏔️', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Text('Where are you heading?',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Name a peak worth climbing — your habits will be the path up.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: goals.length,
            itemBuilder: (_, i) {
              final g = goals[i];
              return ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(g.title),
                subtitle: Text(
                  [
                    g.status.label,
                    if (g.targetDate != null)
                      'by ${g.targetDate!.year}-${g.targetDate!.month.toString().padLeft(2, '0')}-${g.targetDate!.day.toString().padLeft(2, '0')}',
                    if (g.targetValue != null)
                      '${g.targetValue} ${g.targetUnit ?? ''}',
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/goals/${g.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/goals/new'),
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
    );
  }
}

class GoalEditScreen extends ConsumerStatefulWidget {
  const GoalEditScreen({super.key});
  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _targetValue = TextEditingController();
  final _targetUnit = TextEditingController();
  DateTime? _targetDate;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _targetValue.dispose();
    _targetUnit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(goalRepoProvider).create(
            title: _title.text.trim(),
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            targetDate: _targetDate,
            targetValue: num.tryParse(_targetValue.text.trim()),
            targetUnit:
                _targetUnit.text.trim().isEmpty ? null : _targetUnit.text.trim(),
          );
      ref.invalidate(goalsProvider);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('New goal'),
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
            controller: _title,
            decoration: const InputDecoration(
                labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(_targetDate == null
                    ? 'Target date (optional)'
                    : '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate ?? DateTime.now(),
                    firstDate: DateTime.now()
                        .subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) setState(() => _targetDate = picked);
                },
              ),
            ),
            if (_targetDate != null)
              IconButton(
                onPressed: () => setState(() => _targetDate = null),
                icon: const Icon(Icons.clear),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Measurable target (optional)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _targetValue,
                decoration: const InputDecoration(
                    labelText: 'Value', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _targetUnit,
                decoration: const InputDecoration(
                    labelText: 'Unit (kg, km, books…)',
                    border: OutlineInputBorder()),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalProvider(goalId));
    final habitsAsync = ref.watch(habitsForGoalProvider(goalId));
    return Scaffold(
      appBar: AppBar(
        title: goalAsync.maybeWhen(
          data: (g) => Text(g.title),
          orElse: () => const Text('Goal'),
        ),
        actions: [
          goalAsync.maybeWhen(
            data: (g) => PopupMenuButton<GoalStatus>(
              onSelected: (s) async {
                await ref.read(goalRepoProvider).updateStatus(g.id, s);
                ref.invalidate(goalProvider(goalId));
                ref.invalidate(goalsProvider);
              },
              itemBuilder: (_) => [
                for (final s in GoalStatus.values)
                  PopupMenuItem(value: s, child: Text('Mark ${s.label}')),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: goalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (g) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Chip(label: Text(g.status.label)),
                      const Spacer(),
                      if (g.targetDate != null)
                        Text('by ${g.targetDate!.toString().split(' ').first}'),
                    ]),
                    if (g.description != null) ...[
                      const SizedBox(height: 8),
                      Text(g.description!),
                    ],
                    if (g.targetValue != null) ...[
                      const SizedBox(height: 8),
                      Text('Target: ${g.targetValue} ${g.targetUnit ?? ''}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Linked habits',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            habitsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (habits) {
                if (habits.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No habits linked to this goal yet.'),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final h in habits)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.repeat),
                          title: Text(h.name),
                          subtitle: Text(h.frequencyKind.label),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
