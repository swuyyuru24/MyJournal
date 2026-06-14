import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import 'models.dart';

// ---------------- templates ----------------

class TemplateRepository {
  TemplateRepository(this._c);
  final SupabaseClient _c;

  Future<List<Template>> list() async {
    final rows = await _c
        .from('templates')
        .select('*, template_sections(*)')
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => Template.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Template> getById(String id) async {
    final row = await _c
        .from('templates')
        .select('*, template_sections(*)')
        .eq('id', id)
        .single();
    return Template.fromJson(row);
  }

  Future<Template> create({
    required String name,
    String? description,
    required ScheduleKind scheduleKind,
    bool isDefault = false,
    required List<TemplateSection> sections,
  }) async {
    final userId = _c.auth.currentUser!.id;
    final inserted = await _c
        .from('templates')
        .insert({
          'user_id': userId,
          'name': name,
          'description': description,
          'schedule_kind': scheduleKind.db,
          'is_default': isDefault,
        })
        .select()
        .single();
    final templateId = inserted['id'] as String;
    if (sections.isNotEmpty) {
      await _c.from('template_sections').insert(
            sections.map((s) => s.toInsert(templateId)).toList(),
          );
    }
    return getById(templateId);
  }

  Future<void> updateMeta(
    String id, {
    required String name,
    String? description,
    required ScheduleKind scheduleKind,
  }) async {
    await _c.from('templates').update({
      'name': name,
      'description': description,
      'schedule_kind': scheduleKind.db,
    }).eq('id', id);
  }

  Future<void> replaceSections(
    String templateId,
    List<TemplateSection> sections,
  ) async {
    // Try hard delete first (cleanest). If any section is already referenced
    // by an entry, the FK (ON DELETE RESTRICT) raises 23503 — fall back to
    // soft-delete so history is preserved.
    try {
      await _c
          .from('template_sections')
          .delete()
          .eq('template_id', templateId);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        await _c.from('template_sections').update({
          'deleted_at': DateTime.now().toIso8601String(),
        }).eq('template_id', templateId);
      } else {
        rethrow;
      }
    }
    if (sections.isNotEmpty) {
      await _c.from('template_sections').insert(
            sections.map((s) => s.toInsert(templateId)).toList(),
          );
    }
  }

  Future<void> softDelete(String id) async {
    await _c.from('templates').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> seedDefaultsIfEmpty() async {
    final existing = await _c
        .from('templates')
        .select('id')
        .filter('deleted_at', 'is', null)
        .limit(1);
    if ((existing as List).isNotEmpty) return;

    TemplateSection sec(int p, String l, SectionKind k,
            {bool req = false, Map<String, dynamic> cfg = const {}}) =>
        TemplateSection(
          id: '',
          templateId: '',
          position: p,
          label: l,
          kind: k,
          required: req,
          config: cfg,
        );

    await create(
      name: 'Morning Review',
      scheduleKind: ScheduleKind.daily,
      isDefault: true,
      sections: [
        sec(1, "Today's #1 focus", SectionKind.shortText, req: true),
        sec(2, 'Energy', SectionKind.rating, cfg: {'min': 1, 'max': 10}),
        sec(3, 'Habits', SectionKind.habits),
        sec(4, 'Anything I want to remember', SectionKind.longText),
      ],
    );
    await create(
      name: 'Evening Reflection',
      scheduleKind: ScheduleKind.daily,
      sections: [
        sec(1, 'Three wins today', SectionKind.list,
            req: true, cfg: {'min_items': 3, 'max_items': 3}),
        sec(2, 'What I learned', SectionKind.longText),
        sec(3, 'Mood', SectionKind.mood),
        sec(4, 'Gratitude', SectionKind.shortText),
      ],
    );
  }
}

final templateRepoProvider = Provider<TemplateRepository>(
    (ref) => TemplateRepository(ref.watch(supabaseProvider)));

final templatesProvider = FutureProvider.autoDispose<List<Template>>(
    (ref) => ref.watch(templateRepoProvider).list());

final templateProvider =
    FutureProvider.autoDispose.family<Template, String>((ref, id) {
  return ref.watch(templateRepoProvider).getById(id);
});

// ---------------- entries ----------------

class EntryRepository {
  EntryRepository(this._c);
  final SupabaseClient _c;

  Future<List<Entry>> list({int limit = 50}) async {
    final rows = await _c
        .from('entries')
        .select('*, entry_section_values(*), templates(*, template_sections(*))')
        .filter('deleted_at', 'is', null)
        .order('entry_date', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => Entry.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Entry?> findForTemplateAndDate(String templateId, DateTime date) async {
    final rows = await _c
        .from('entries')
        .select('*, entry_section_values(*), templates(*, template_sections(*))')
        .eq('template_id', templateId)
        .eq('entry_date', ymd(date))
        .filter('deleted_at', 'is', null)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return Entry.fromJson(list.first);
  }

  Future<Entry> getById(String id) async {
    final row = await _c
        .from('entries')
        .select('*, entry_section_values(*), templates(*, template_sections(*))')
        .eq('id', id)
        .single();
    return Entry.fromJson(row);
  }

  Future<Entry> createForTemplate(Template template, DateTime date) async {
    final userId = _c.auth.currentUser!.id;
    final inserted = await _c
        .from('entries')
        .insert({
          'user_id': userId,
          'template_id': template.id,
          'entry_date': ymd(date),
        })
        .select()
        .single();
    return getById(inserted['id'] as String);
  }

  Future<void> upsertValue({
    required String entryId,
    required TemplateSection section,
    String? valueText,
    num? valueNumber,
    dynamic valueJson,
  }) async {
    await _c.from('entry_section_values').upsert(
      {
        'entry_id': entryId,
        'section_id': section.id,
        'section_label_snapshot': section.label,
        'section_kind_snapshot': section.kind.db,
        'value_text': valueText,
        'value_number': valueNumber,
        'value_json': valueJson,
      },
      onConflict: 'entry_id,section_id',
    );
  }

  Future<void> markCompleted(String entryId) async {
    await _c.from('entries').update({
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', entryId);
  }

  Future<void> markDraft(String entryId) async {
    await _c.from('entries').update({'completed_at': null}).eq('id', entryId);
  }

  Future<void> softDelete(String entryId) async {
    await _c.from('entries').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', entryId);
  }
}

final entryRepoProvider = Provider<EntryRepository>(
    (ref) => EntryRepository(ref.watch(supabaseProvider)));

final entriesProvider = FutureProvider.autoDispose<List<Entry>>(
    (ref) => ref.watch(entryRepoProvider).list());

final entryProvider =
    FutureProvider.autoDispose.family<Entry, String>((ref, id) {
  return ref.watch(entryRepoProvider).getById(id);
});

// ---------------- habits ----------------

class HabitRepository {
  HabitRepository(this._c);
  final SupabaseClient _c;

  Future<List<Habit>> list() async {
    final rows = await _c
        .from('habits')
        .select('*, habit_goals(goal_id)')
        .filter('deleted_at', 'is', null)
        .filter('archived_at', 'is', null)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => Habit.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Habit> getById(String id) async {
    final row = await _c
        .from('habits')
        .select('*, habit_goals(goal_id)')
        .eq('id', id)
        .single();
    return Habit.fromJson(row);
  }

  Future<Habit> create({
    required String name,
    String? description,
    required HabitKind kind,
    String? unit,
    num? targetPerOccurrence,
    required FrequencyKind frequencyKind,
    int? frequencyTarget,
    List<String> goalIds = const [],
  }) async {
    final userId = _c.auth.currentUser!.id;
    final inserted = await _c
        .from('habits')
        .insert({
          'user_id': userId,
          'name': name,
          'description': description,
          'kind': kind.db,
          'unit': unit,
          'target_per_occurrence': targetPerOccurrence,
          'frequency_kind': frequencyKind.db,
          'frequency_target': frequencyTarget,
        })
        .select()
        .single();
    final habitId = inserted['id'] as String;
    if (goalIds.isNotEmpty) {
      await _c.from('habit_goals').insert(
            goalIds.map((g) => {'habit_id': habitId, 'goal_id': g}).toList(),
          );
    }
    return getById(habitId);
  }

  Future<void> archive(String id) async {
    await _c.from('habits').update({
      'archived_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<HabitLog>> logsForDate(DateTime date) async {
    final rows = await _c
        .from('habit_logs')
        .select()
        .eq('log_date', ymd(date));
    return (rows as List)
        .map((r) => HabitLog.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<HabitLog>> recentLogs({int days = 60}) async {
    final start = DateTime.now().subtract(Duration(days: days));
    final rows = await _c
        .from('habit_logs')
        .select()
        .gte('log_date', ymd(start))
        .order('log_date', ascending: false);
    return (rows as List)
        .map((r) => HabitLog.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertLog({
    required String habitId,
    required DateTime date,
    required bool completed,
    num? value,
    String? note,
  }) async {
    final userId = _c.auth.currentUser!.id;
    await _c.from('habit_logs').upsert(
      {
        'user_id': userId,
        'habit_id': habitId,
        'log_date': ymd(date),
        'completed': completed,
        'value': value,
        'note': note,
      },
      onConflict: 'habit_id,log_date',
    );
  }
}

final habitRepoProvider = Provider<HabitRepository>(
    (ref) => HabitRepository(ref.watch(supabaseProvider)));

final habitsProvider = FutureProvider.autoDispose<List<Habit>>(
    (ref) => ref.watch(habitRepoProvider).list());

final habitLogsForTodayProvider =
    FutureProvider.autoDispose<List<HabitLog>>((ref) {
  return ref.watch(habitRepoProvider).logsForDate(DateTime.now());
});

final recentHabitLogsProvider =
    FutureProvider.autoDispose<List<HabitLog>>((ref) {
  return ref.watch(habitRepoProvider).recentLogs();
});

/// Streak = consecutive prior days (including today if completed) on which
/// a log marked completed=true exists.
int computeStreak(String habitId, List<HabitLog> logs, {DateTime? today}) {
  final t = today ?? DateTime.now();
  final completedDates = logs
      .where((l) => l.habitId == habitId && l.completed)
      .map((l) => DateTime(l.logDate.year, l.logDate.month, l.logDate.day))
      .toSet();
  var streak = 0;
  var day = DateTime(t.year, t.month, t.day);
  while (completedDates.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

// ---------------- goals ----------------

class GoalRepository {
  GoalRepository(this._c);
  final SupabaseClient _c;

  Future<List<Goal>> list() async {
    final rows = await _c
        .from('goals')
        .select()
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Goal.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Goal> getById(String id) async {
    final row = await _c.from('goals').select().eq('id', id).single();
    return Goal.fromJson(row);
  }

  Future<Goal> create({
    required String title,
    String? description,
    DateTime? targetDate,
    num? targetValue,
    String? targetUnit,
  }) async {
    final userId = _c.auth.currentUser!.id;
    final inserted = await _c
        .from('goals')
        .insert({
          'user_id': userId,
          'title': title,
          'description': description,
          'target_date': targetDate == null ? null : ymd(targetDate),
          'target_value': targetValue,
          'target_unit': targetUnit,
        })
        .select()
        .single();
    return Goal.fromJson(inserted);
  }

  Future<void> updateStatus(String id, GoalStatus status) async {
    await _c.from('goals').update({
      'status': status.db,
      if (status == GoalStatus.achieved)
        'achieved_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<Habit>> habitsForGoal(String goalId) async {
    final rows = await _c
        .from('habit_goals')
        .select('habits(*, habit_goals(goal_id))')
        .eq('goal_id', goalId);
    return (rows as List)
        .map((r) => Habit.fromJson(
              (r as Map<String, dynamic>)['habits'] as Map<String, dynamic>,
            ))
        .toList();
  }
}

final goalRepoProvider =
    Provider<GoalRepository>((ref) => GoalRepository(ref.watch(supabaseProvider)));

final goalsProvider = FutureProvider.autoDispose<List<Goal>>(
    (ref) => ref.watch(goalRepoProvider).list());

final goalProvider =
    FutureProvider.autoDispose.family<Goal, String>((ref, id) {
  return ref.watch(goalRepoProvider).getById(id);
});

final habitsForGoalProvider =
    FutureProvider.autoDispose.family<List<Habit>, String>((ref, goalId) {
  return ref.watch(goalRepoProvider).habitsForGoal(goalId);
});
