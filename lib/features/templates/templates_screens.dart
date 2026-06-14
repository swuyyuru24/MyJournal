import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';

class TemplatesListScreen extends ConsumerWidget {
  const TemplatesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (templates) {
          if (templates.isEmpty) {
            return const _EmptyState(
              emoji: '🪴',
              title: 'Plant a review ritual',
              body:
                  'Morning Review, Evening Reflection, Weekly Wrap — whatever shape your days call for.',
            );
          }
          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (_, i) {
              final t = templates[i];
              return ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: Text(t.name),
                subtitle: Text(
                    '${t.scheduleKind.label} • ${t.sections.length} section${t.sections.length == 1 ? '' : 's'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/templates/${t.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/templates/new'),
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
    );
  }
}

class TemplateEditScreen extends ConsumerStatefulWidget {
  const TemplateEditScreen({super.key, this.templateId});
  final String? templateId;

  @override
  ConsumerState<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends ConsumerState<TemplateEditScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  ScheduleKind _scheduleKind = ScheduleKind.daily;
  List<_SectionDraft> _sections = [];
  bool _busy = false;
  bool _loaded = false;

  bool get _isNew => widget.templateId == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSection(SectionKind kind) {
    setState(() => _sections.add(_SectionDraft.blank(kind)));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name required')),
      );
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(templateRepoProvider);
    try {
      final sections = [
        for (var i = 0; i < _sections.length; i++)
          TemplateSection(
            id: '',
            templateId: '',
            position: i + 1,
            label: _sections[i].labelCtrl.text.trim().isEmpty
                ? _sections[i].kind.label
                : _sections[i].labelCtrl.text.trim(),
            kind: _sections[i].kind,
            required: _sections[i].required,
            config: _sections[i].buildConfig(),
          ),
      ];
      if (_isNew) {
        await repo.create(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          scheduleKind: _scheduleKind,
          sections: sections,
        );
      } else {
        await repo.updateMeta(
          widget.templateId!,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          scheduleKind: _scheduleKind,
        );
        await repo.replaceSections(widget.templateId!, sections);
      }
      ref.invalidate(templatesProvider);
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

  Future<void> _delete() async {
    if (widget.templateId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete template?'),
        content: const Text(
            'Existing entries from this template will still be visible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(templateRepoProvider).softDelete(widget.templateId!);
    ref.invalidate(templatesProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isNew) {
      return _buildBody(null);
    }
    final tplAsync = ref.watch(templateProvider(widget.templateId!));
    return tplAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (t) {
        if (!_loaded) {
          _nameCtrl.text = t.name;
          _descCtrl.text = t.description ?? '';
          _scheduleKind = t.scheduleKind;
          _sections = t.sections.map(_SectionDraft.fromExisting).toList();
          _loaded = true;
        }
        return _buildBody(t);
      },
    );
  }

  Widget _buildBody(Template? existing) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New template' : 'Edit template'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ScheduleKind>(
            initialValue: _scheduleKind,
            decoration: const InputDecoration(
              labelText: 'Schedule',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final k in ScheduleKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (v) => setState(() => _scheduleKind = v!),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Sections', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              PopupMenuButton<SectionKind>(
                tooltip: 'Add section',
                icon: const Icon(Icons.add_circle_outline),
                onSelected: _addSection,
                itemBuilder: (_) => [
                  for (final k in SectionKind.values)
                    PopupMenuItem(
                      value: k,
                      child: Row(children: [
                        Icon(k.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(k.label),
                      ]),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_sections.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No sections yet. Tap + to add one.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = _sections.removeAt(oldIdx);
                _sections.insert(newIdx, item);
              });
            },
            children: [
              for (var i = 0; i < _sections.length; i++)
                _SectionRow(
                  key: ValueKey(_sections[i]),
                  draft: _sections[i],
                  onRemove: () =>
                      setState(() => _sections.removeAt(i)),
                  onChanged: () => setState(() {}),
                ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionDraft {
  _SectionDraft({
    required this.labelCtrl,
    required this.kind,
    required this.required,
    required this.promptCtrl,
    required this.listCount,
  });

  factory _SectionDraft.blank(SectionKind kind) => _SectionDraft(
        labelCtrl: TextEditingController(),
        kind: kind,
        required: false,
        promptCtrl: TextEditingController(),
        listCount: 3,
      );

  factory _SectionDraft.fromExisting(TemplateSection s) => _SectionDraft(
        labelCtrl: TextEditingController(text: s.label),
        kind: s.kind,
        required: s.required,
        promptCtrl:
            TextEditingController(text: (s.config['prompt'] as String?) ?? ''),
        listCount: (s.config['max_items'] as int?) ??
            (s.config['min_items'] as int?) ??
            3,
      );

  final TextEditingController labelCtrl;
  SectionKind kind;
  bool required;
  final TextEditingController promptCtrl;
  int listCount;

  Map<String, dynamic> buildConfig() {
    switch (kind) {
      case SectionKind.list:
        return {
          if (promptCtrl.text.trim().isNotEmpty)
            'prompt': promptCtrl.text.trim(),
          'min_items': listCount,
          'max_items': listCount,
        };
      case SectionKind.rating:
        return {'min': 1, 'max': 10};
      default:
        return <String, dynamic>{};
    }
  }

  void dispose() {
    labelCtrl.dispose();
    promptCtrl.dispose();
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required super.key,
    required this.draft,
    required this.onRemove,
    required this.onChanged,
  });

  final _SectionDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(draft.kind.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.labelCtrl,
                    decoration: InputDecoration(
                      hintText: draft.kind.label,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
                const Icon(Icons.drag_handle, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                DropdownButton<SectionKind>(
                  value: draft.kind,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final k in SectionKind.values)
                      DropdownMenuItem(value: k, child: Text(k.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      draft.kind = v;
                      onChanged();
                    }
                  },
                ),
                const Spacer(),
                const Text('Required'),
                Switch(
                  value: draft.required,
                  onChanged: (v) {
                    draft.required = v;
                    onChanged();
                  },
                ),
              ],
            ),
            if (draft.kind == SectionKind.list) ...[
              const SizedBox(height: 8),
              TextField(
                controller: draft.promptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prompt (optional)',
                  hintText: 'e.g. What three things went well today?',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Number of bullets'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: draft.listCount > 1
                        ? () {
                            draft.listCount--;
                            onChanged();
                          }
                        : null,
                  ),
                  Text('${draft.listCount}',
                      style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: draft.listCount < 10
                        ? () {
                            draft.listCount++;
                            onChanged();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.emoji, required this.title, required this.body});
  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
