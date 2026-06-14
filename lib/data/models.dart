import 'package:flutter/material.dart';

// ---------------- enums ----------------

enum ScheduleKind { daily, weekly, monthly, onDemand }

extension ScheduleKindDb on ScheduleKind {
  String get db => switch (this) {
        ScheduleKind.daily => 'daily',
        ScheduleKind.weekly => 'weekly',
        ScheduleKind.monthly => 'monthly',
        ScheduleKind.onDemand => 'on_demand',
      };
  String get label => switch (this) {
        ScheduleKind.daily => 'Daily',
        ScheduleKind.weekly => 'Weekly',
        ScheduleKind.monthly => 'Monthly',
        ScheduleKind.onDemand => 'On demand',
      };
  static ScheduleKind fromDb(String s) =>
      ScheduleKind.values.firstWhere((e) => e.db == s);
}

enum SectionKind {
  shortText,
  longText,
  list,
  rating,
  number,
  boolean,
  mood,
  tags,
  prompt,
  habits,
}

extension SectionKindDb on SectionKind {
  String get db => switch (this) {
        SectionKind.shortText => 'short_text',
        SectionKind.longText => 'long_text',
        SectionKind.list => 'list',
        SectionKind.rating => 'rating',
        SectionKind.number => 'number',
        SectionKind.boolean => 'boolean',
        SectionKind.mood => 'mood',
        SectionKind.tags => 'tags',
        SectionKind.prompt => 'prompt',
        SectionKind.habits => 'habits',
      };
  String get label => switch (this) {
        SectionKind.shortText => 'Short text',
        SectionKind.longText => 'Long text',
        SectionKind.list => 'List',
        SectionKind.rating => 'Rating',
        SectionKind.number => 'Number',
        SectionKind.boolean => 'Yes / No',
        SectionKind.mood => 'Mood',
        SectionKind.tags => 'Tags',
        SectionKind.prompt => 'Prompt',
        SectionKind.habits => 'Habits',
      };
  IconData get icon => switch (this) {
        SectionKind.shortText => Icons.short_text,
        SectionKind.longText => Icons.notes,
        SectionKind.list => Icons.format_list_bulleted,
        SectionKind.rating => Icons.star_outline,
        SectionKind.number => Icons.numbers,
        SectionKind.boolean => Icons.check_circle_outline,
        SectionKind.mood => Icons.mood,
        SectionKind.tags => Icons.label_outline,
        SectionKind.prompt => Icons.lightbulb_outline,
        SectionKind.habits => Icons.repeat,
      };
  static SectionKind fromDb(String s) =>
      SectionKind.values.firstWhere((e) => e.db == s);
}

enum HabitKind { boolean, numeric }

extension HabitKindDb on HabitKind {
  String get db => name;
  static HabitKind fromDb(String s) =>
      HabitKind.values.firstWhere((e) => e.db == s);
}

enum FrequencyKind { daily, weekdays, weekends, xPerWeek, xPerMonth, custom }

extension FrequencyKindDb on FrequencyKind {
  String get db => switch (this) {
        FrequencyKind.daily => 'daily',
        FrequencyKind.weekdays => 'weekdays',
        FrequencyKind.weekends => 'weekends',
        FrequencyKind.xPerWeek => 'x_per_week',
        FrequencyKind.xPerMonth => 'x_per_month',
        FrequencyKind.custom => 'custom',
      };
  String get label => switch (this) {
        FrequencyKind.daily => 'Every day',
        FrequencyKind.weekdays => 'Weekdays',
        FrequencyKind.weekends => 'Weekends',
        FrequencyKind.xPerWeek => 'X times per week',
        FrequencyKind.xPerMonth => 'X times per month',
        FrequencyKind.custom => 'Custom',
      };
  static FrequencyKind fromDb(String s) =>
      FrequencyKind.values.firstWhere((e) => e.db == s);
}

enum GoalStatus { active, paused, achieved, abandoned }

extension GoalStatusDb on GoalStatus {
  String get db => name;
  String get label => switch (this) {
        GoalStatus.active => 'Active',
        GoalStatus.paused => 'Paused',
        GoalStatus.achieved => 'Achieved',
        GoalStatus.abandoned => 'Abandoned',
      };
  static GoalStatus fromDb(String s) =>
      GoalStatus.values.firstWhere((e) => e.db == s);
}

// ---------------- models ----------------

class TemplateSection {
  final String id;
  final String templateId;
  final int position;
  final String label;
  final SectionKind kind;
  final bool required;
  final Map<String, dynamic> config;
  final DateTime? deletedAt;

  TemplateSection({
    required this.id,
    required this.templateId,
    required this.position,
    required this.label,
    required this.kind,
    required this.required,
    required this.config,
    this.deletedAt,
  });

  factory TemplateSection.fromJson(Map<String, dynamic> j) => TemplateSection(
        id: j['id'] as String,
        templateId: j['template_id'] as String,
        position: j['position'] as int,
        label: j['label'] as String,
        kind: SectionKindDb.fromDb(j['kind'] as String),
        required: j['required'] as bool? ?? false,
        config: (j['config'] as Map?)?.cast<String, dynamic>() ?? {},
        deletedAt: j['deleted_at'] == null
            ? null
            : DateTime.parse(j['deleted_at'] as String),
      );

  Map<String, dynamic> toInsert(String templateId) => {
        'template_id': templateId,
        'position': position,
        'label': label,
        'kind': kind.db,
        'required': required,
        'config': config,
      };
}

class Template {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final ScheduleKind scheduleKind;
  final bool isDefault;
  final List<TemplateSection> sections;

  Template({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.scheduleKind,
    required this.isDefault,
    this.sections = const [],
  });

  factory Template.fromJson(Map<String, dynamic> j) => Template(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        scheduleKind: ScheduleKindDb.fromDb(j['schedule_kind'] as String),
        isDefault: j['is_default'] as bool? ?? false,
        sections: ((j['template_sections'] as List?) ?? [])
            .map((s) => TemplateSection.fromJson(s as Map<String, dynamic>))
            .where((s) => s.deletedAt == null)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'name': name,
        'description': description,
        'schedule_kind': scheduleKind.db,
        'is_default': isDefault,
      };
}

class EntrySectionValue {
  final String id;
  final String entryId;
  final String sectionId;
  final String sectionLabelSnapshot;
  final String sectionKindSnapshot;
  final String? valueText;
  final num? valueNumber;
  final dynamic valueJson;

  EntrySectionValue({
    required this.id,
    required this.entryId,
    required this.sectionId,
    required this.sectionLabelSnapshot,
    required this.sectionKindSnapshot,
    this.valueText,
    this.valueNumber,
    this.valueJson,
  });

  factory EntrySectionValue.fromJson(Map<String, dynamic> j) =>
      EntrySectionValue(
        id: j['id'] as String,
        entryId: j['entry_id'] as String,
        sectionId: j['section_id'] as String,
        sectionLabelSnapshot: j['section_label_snapshot'] as String,
        sectionKindSnapshot: j['section_kind_snapshot'] as String,
        valueText: j['value_text'] as String?,
        valueNumber: j['value_number'] as num?,
        valueJson: j['value_json'],
      );
}

class Entry {
  final String id;
  final String userId;
  final String templateId;
  final DateTime entryDate;
  final DateTime? completedAt;
  final int version;
  final List<EntrySectionValue> values;
  final Template? template;

  Entry({
    required this.id,
    required this.userId,
    required this.templateId,
    required this.entryDate,
    this.completedAt,
    required this.version,
    this.values = const [],
    this.template,
  });

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        templateId: j['template_id'] as String,
        entryDate: DateTime.parse(j['entry_date'] as String),
        completedAt: j['completed_at'] == null
            ? null
            : DateTime.parse(j['completed_at'] as String),
        version: j['version'] as int? ?? 1,
        values: ((j['entry_section_values'] as List?) ?? [])
            .map((v) => EntrySectionValue.fromJson(v as Map<String, dynamic>))
            .toList(),
        template: j['templates'] == null
            ? null
            : Template.fromJson(j['templates'] as Map<String, dynamic>),
      );
}

class Habit {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final HabitKind kind;
  final String? unit;
  final num? targetPerOccurrence;
  final FrequencyKind frequencyKind;
  final int? frequencyTarget;
  final String? color;
  final String? icon;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? archivedAt;
  final List<String> linkedGoalIds;

  Habit({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.kind,
    this.unit,
    this.targetPerOccurrence,
    required this.frequencyKind,
    this.frequencyTarget,
    this.color,
    this.icon,
    required this.startDate,
    this.endDate,
    this.archivedAt,
    this.linkedGoalIds = const [],
  });

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        kind: HabitKindDb.fromDb(j['kind'] as String),
        unit: j['unit'] as String?,
        targetPerOccurrence: j['target_per_occurrence'] as num?,
        frequencyKind: FrequencyKindDb.fromDb(j['frequency_kind'] as String),
        frequencyTarget: j['frequency_target'] as int?,
        color: j['color'] as String?,
        icon: j['icon'] as String?,
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: j['end_date'] == null
            ? null
            : DateTime.parse(j['end_date'] as String),
        archivedAt: j['archived_at'] == null
            ? null
            : DateTime.parse(j['archived_at'] as String),
        linkedGoalIds: ((j['habit_goals'] as List?) ?? [])
            .map((g) => (g as Map)['goal_id'] as String)
            .toList(),
      );
}

class HabitLog {
  final String id;
  final String userId;
  final String habitId;
  final DateTime logDate;
  final bool completed;
  final num? value;
  final String? note;

  HabitLog({
    required this.id,
    required this.userId,
    required this.habitId,
    required this.logDate,
    required this.completed,
    this.value,
    this.note,
  });

  factory HabitLog.fromJson(Map<String, dynamic> j) => HabitLog(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        habitId: j['habit_id'] as String,
        logDate: DateTime.parse(j['log_date'] as String),
        completed: j['completed'] as bool? ?? false,
        value: j['value'] as num?,
        note: j['note'] as String?,
      );
}

class Goal {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final GoalStatus status;
  final DateTime startDate;
  final DateTime? targetDate;
  final num? targetValue;
  final String? targetUnit;
  final String? color;

  Goal({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.status,
    required this.startDate,
    this.targetDate,
    this.targetValue,
    this.targetUnit,
    this.color,
  });

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: GoalStatusDb.fromDb(j['status'] as String),
        startDate: DateTime.parse(j['start_date'] as String),
        targetDate: j['target_date'] == null
            ? null
            : DateTime.parse(j['target_date'] as String),
        targetValue: j['target_value'] as num?,
        targetUnit: j['target_unit'] as String?,
        color: j['color'] as String?,
      );
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
