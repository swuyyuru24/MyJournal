import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final habitLogsAsync = ref.watch(habitLogsForTodayProvider);
    final recentLogsAsync = ref.watch(recentHabitLogsProvider);
    final user = ref.watch(currentUserProvider);
    final today = DateTime.now();
    final name = (user?.email?.split('@').first ?? 'friend');

    return Scaffold(
      body: RefreshIndicator(
        color: JournalPalette.sageDark,
        onRefresh: () async {
          ref.invalidate(templatesProvider);
          ref.invalidate(habitsProvider);
          ref.invalidate(habitLogsForTodayProvider);
          ref.invalidate(recentHabitLogsProvider);
          ref.invalidate(entriesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _Greeting(name: name, date: today),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _SectionLabel('Today\'s reviews'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(
                child: templatesAsync.when(
                  loading: () => const _Loader(),
                  error: (e, _) => _ErrorTile(text: '$e'),
                  data: (templates) {
                    final daily = templates
                        .where((t) =>
                            t.scheduleKind == ScheduleKind.daily)
                        .toList();
                    if (daily.isEmpty) {
                      return _EmptyCard(
                        emoji: '🪴',
                        title: 'Plant your first review',
                        body:
                            'Set up a Morning Review or Evening Reflection to give your days a gentle shape.',
                        cta: 'Go to templates',
                        onTap: () => context.go('/templates'),
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < daily.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                                bottom: i == daily.length - 1 ? 0 : 10),
                            child: _TodayTemplateCard(
                              template: daily[i],
                              date: today,
                            )
                                .animate()
                                .fadeIn(delay: (100 * i).ms, duration: 350.ms)
                                .slideY(begin: 0.05),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionLabel('Habits growing'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
              sliver: SliverToBoxAdapter(
                child: habitsAsync.when(
                  loading: () => const _Loader(),
                  error: (e, _) => _ErrorTile(text: '$e'),
                  data: (habits) {
                    if (habits.isEmpty) {
                      return _EmptyCard(
                        emoji: '🌱',
                        title: 'No habits yet',
                        body:
                            'Tiny actions repeated kindly become who you are. Start with one.',
                        cta: 'Sow a habit',
                        onTap: () => context.go('/habits'),
                      );
                    }
                    return habitLogsAsync.when(
                      loading: () => const _Loader(),
                      error: (e, _) => _ErrorTile(text: '$e'),
                      data: (todayLogs) => recentLogsAsync.when(
                        loading: () => const _Loader(),
                        error: (e, _) => _ErrorTile(text: '$e'),
                        data: (recentLogs) => Column(
                          children: [
                            for (var i = 0; i < habits.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                    bottom:
                                        i == habits.length - 1 ? 0 : 10),
                                child: _TodayHabitTile(
                                  habit: habits[i],
                                  log: todayLogs
                                      .where((l) => l.habitId == habits[i].id)
                                      .firstOrNull,
                                  streak: computeStreak(
                                      habits[i].id, recentLogs),
                                  date: today,
                                )
                                    .animate()
                                    .fadeIn(
                                        delay: (60 * i).ms, duration: 300.ms)
                                    .slideX(begin: -0.05),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.date});
  final String name;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final greet = greeting(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$greet, ',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Flexible(
              child: Text(
                name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: JournalPalette.terracotta,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          prettyDate(date),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: JournalPalette.inkSoft,
              ),
        ).animate().fadeIn(delay: 150.ms, duration: 500.ms),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: JournalPalette.inkSoft,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
      ),
    );
  }
}

class _TodayTemplateCard extends ConsumerWidget {
  const _TodayTemplateCard({required this.template, required this.date});
  final Template template;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(
      FutureProvider.autoDispose<Entry?>((ref) {
        return ref
            .watch(entryRepoProvider)
            .findForTemplateAndDate(template.id, date);
      }),
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final repo = ref.read(entryRepoProvider);
          final existing =
              await repo.findForTemplateAndDate(template.id, date);
          final entry =
              existing ?? await repo.createForTemplate(template, date);
          if (context.mounted) {
            context.push('/entries/${entry.id}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              entryAsync.maybeWhen(
                data: (e) => _StatusBubble(
                  emoji: e?.completedAt != null
                      ? '✨'
                      : e != null
                          ? '✍️'
                          : '🌱',
                  color: e?.completedAt != null
                      ? JournalPalette.honey
                      : e != null
                          ? JournalPalette.terracottaSoft
                          : JournalPalette.sageLight,
                ),
                orElse: () => const _StatusBubble(
                    emoji: '🌱', color: JournalPalette.sageLight),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    entryAsync.maybeWhen(
                      data: (e) => Text(
                        e == null
                            ? 'Not started — tap to begin'
                            : e.completedAt != null
                                ? 'Complete — well done 🎉'
                                : 'In progress',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      orElse: () => Text('…',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: JournalPalette.sageDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBubble extends StatelessWidget {
  const _StatusBubble({required this.emoji, required this.color});
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

class _TodayHabitTile extends ConsumerWidget {
  const _TodayHabitTile({
    required this.habit,
    required this.log,
    required this.streak,
    required this.date,
  });
  final Habit habit;
  final HabitLog? log;
  final int streak;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = log?.completed ?? false;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await ref.read(habitRepoProvider).upsertLog(
                habitId: habit.id,
                date: date,
                completed: !completed,
                value: habit.kind == HabitKind.numeric
                    ? (!completed ? habit.targetPerOccurrence : null)
                    : null,
              );
          ref.invalidate(habitLogsForTodayProvider);
          ref.invalidate(recentHabitLogsProvider);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AnimatedContainer(
                duration: 250.ms,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: completed
                      ? JournalPalette.sageDark
                      : JournalPalette.sageLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: completed
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 24)
                    : Text(streakPlant(streak),
                        style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: completed
                                ? JournalPalette.inkSoft
                                : JournalPalette.ink,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streak == 0
                          ? 'New seed — let it sprout 🌱'
                          : streak == 1
                              ? '1 day strong'
                              : '$streak day streak ${streakPlant(streak)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: JournalPalette.sageDark),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text,
            style: const TextStyle(color: JournalPalette.terracotta)),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });
  final String emoji;
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: JournalPalette.inkSoft,
                    )),
            const SizedBox(height: 16),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: JournalPalette.sageLight,
                foregroundColor: JournalPalette.sageDark,
              ),
              onPressed: onTap,
              child: Text(cta),
            ),
          ],
        ),
      ),
    );
  }
}
