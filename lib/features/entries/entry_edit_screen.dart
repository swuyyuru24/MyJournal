import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

class EntryEditScreen extends ConsumerStatefulWidget {
  const EntryEditScreen({super.key, required this.entryId});
  final String entryId;
  @override
  ConsumerState<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends ConsumerState<EntryEditScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(entryProvider(widget.entryId));
    return Scaffold(
      appBar: AppBar(
        title: entryAsync.maybeWhen(
          data: (e) => Text(e.template?.name ?? 'Entry'),
          orElse: () => const Text('Entry'),
        ),
        actions: [
          entryAsync.maybeWhen(
            data: (e) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: e.completedAt == null
                      ? JournalPalette.sageLight
                      : JournalPalette.honey.withValues(alpha: 0.25),
                  foregroundColor: JournalPalette.sageDark,
                ),
                icon: Icon(e.completedAt == null
                    ? Icons.check_rounded
                    : Icons.check_circle),
                label:
                    Text(e.completedAt == null ? 'Complete' : 'Completed'),
                onPressed: () async {
                  final repo = ref.read(entryRepoProvider);
                  final wasOpen = e.completedAt == null;
                  if (wasOpen) {
                    await repo.markCompleted(e.id);
                    _confetti.play();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Beautifully done 🌸'),
                          backgroundColor: JournalPalette.sageDark,
                        ),
                      );
                    }
                  } else {
                    await repo.markDraft(e.id);
                  }
                  ref.invalidate(entryProvider(widget.entryId));
                  ref.invalidate(entriesProvider);
                },
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Stack(
        children: [
          entryAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: JournalPalette.sageDark),
            ),
            error: (e, _) => Center(child: Text('$e')),
            data: (entry) {
              final t = entry.template;
              if (t == null) {
                return const Center(child: Text('Template missing'));
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                children: [
                  Text(
                    prettyDate(entry.entryDate),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: JournalPalette.inkSoft,
                          letterSpacing: 1.1,
                        ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < t.sections.length; i++)
                    _SectionEditor(
                      key: ValueKey(t.sections[i].id),
                      entry: entry,
                      section: t.sections[i],
                    )
                        .animate()
                        .fadeIn(delay: (80 * i).ms, duration: 350.ms)
                        .slideY(begin: 0.04),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              maxBlastForce: 30,
              minBlastForce: 10,
              gravity: 0.2,
              colors: const [
                JournalPalette.sage,
                JournalPalette.terracotta,
                JournalPalette.honey,
                JournalPalette.sageLight,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEditor extends ConsumerStatefulWidget {
  const _SectionEditor({super.key, required this.entry, required this.section});
  final Entry entry;
  final TemplateSection section;

  @override
  ConsumerState<_SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends ConsumerState<_SectionEditor> {
  EntrySectionValue? get _existing =>
      widget.entry.values.where((v) => v.sectionId == widget.section.id).firstOrNull;

  late final TextEditingController _textCtrl =
      TextEditingController(text: _existing?.valueText ?? '');
  late num? _number = _existing?.valueNumber;
  late bool _bool = (_existing?.valueNumber ?? 0) == 1;
  late final List<TextEditingController> _listCtrls = (() {
    final cfg = widget.section.config;
    final fixedCount = (cfg['min_items'] as int?) ??
        (cfg['max_items'] as int?) ??
        3;
    final json = _existing?.valueJson as List?;
    final items = (json ?? const [])
        .cast<dynamic>()
        .map((e) => e.toString())
        .toList();
    while (items.length < fixedCount) {
      items.add('');
    }
    if (items.length > fixedCount) {
      items.removeRange(fixedCount, items.length);
    }
    return items.map((s) => TextEditingController(text: s)).toList();
  })();

  Future<void> _save({
    String? text,
    num? number,
    dynamic json,
  }) async {
    await ref.read(entryRepoProvider).upsertValue(
          entryId: widget.entry.id,
          section: widget.section,
          valueText: text,
          valueNumber: number,
          valueJson: json,
        );
    ref.invalidate(entryProvider(widget.entry.id));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    for (final c in _listCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(s.kind.icon, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(s.label,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              if (s.required)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Required', style: TextStyle(fontSize: 11)),
                ),
            ]),
            const SizedBox(height: 8),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    switch (widget.section.kind) {
      case SectionKind.shortText:
      case SectionKind.prompt:
        return TextField(
          controller: _textCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (v) => _save(text: v),
        );
      case SectionKind.longText:
        return TextField(
          controller: _textCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          maxLines: 5,
          onChanged: (v) => _save(text: v),
        );
      case SectionKind.list:
        final prompt = widget.section.config['prompt'] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null && prompt.isNotEmpty) ...[
              Text(
                prompt,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: JournalPalette.sageDark,
                    ),
              ),
              const SizedBox(height: 10),
            ],
            for (var i = 0; i < _listCtrls.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: JournalPalette.sageLight,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: JournalPalette.sageDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _listCtrls[i],
                      decoration: const InputDecoration(),
                      onChanged: (_) => _save(
                          json: _listCtrls.map((c) => c.text).toList()),
                    ),
                  ),
                ]),
              ),
          ],
        );
      case SectionKind.rating:
        final min = (widget.section.config['min'] as int?) ?? 1;
        final max = (widget.section.config['max'] as int?) ?? 10;
        return Wrap(
          spacing: 4,
          children: [
            for (var v = min; v <= max; v++)
              ChoiceChip(
                label: Text('$v'),
                selected: _number == v,
                onSelected: (_) {
                  setState(() => _number = v);
                  _save(number: v);
                },
              ),
          ],
        );
      case SectionKind.number:
        return TextField(
          controller: _textCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final n = num.tryParse(v);
            _number = n;
            _save(number: n);
          },
        );
      case SectionKind.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Yes'),
          value: _bool,
          onChanged: (v) {
            setState(() => _bool = v);
            _save(number: v ? 1 : 0);
          },
        );
      case SectionKind.mood:
        const moods = ['😞', '🙁', '😐', '🙂', '😄'];
        return Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < moods.length; i++)
              ChoiceChip(
                label: Text(moods[i], style: const TextStyle(fontSize: 20)),
                selected: _number == i + 1,
                onSelected: (_) {
                  setState(() => _number = i + 1);
                  _save(number: i + 1);
                },
              ),
          ],
        );
      case SectionKind.tags:
        return const Text('Tags editor not implemented yet.');
      case SectionKind.habits:
        return const _TodayHabitsSnapshot();
    }
  }
}

class _TodayHabitsSnapshot extends ConsumerWidget {
  const _TodayHabitsSnapshot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final logs = ref.watch(habitLogsForTodayProvider);
    return habits.when(
      loading: () => const SizedBox(
          height: 20, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('$e'),
      data: (hs) => logs.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Text('$e'),
        data: (ls) {
          if (hs.isEmpty) return const Text('No habits to track.');
          return Column(
            children: [
              for (final h in hs)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(h.name),
                  value: ls.where((l) => l.habitId == h.id).firstOrNull?.completed ?? false,
                  onChanged: (v) async {
                    await ref.read(habitRepoProvider).upsertLog(
                          habitId: h.id,
                          date: DateTime.now(),
                          completed: v ?? false,
                        );
                    ref.invalidate(habitLogsForTodayProvider);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
