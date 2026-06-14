import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase.dart';
import 'core/theme.dart';
import 'data/repositories.dart';
import 'features/auth/auth_screen.dart';
import 'features/entries/entries_list_screen.dart';
import 'features/entries/entry_edit_screen.dart';
import 'features/entries/today_screen.dart';
import 'features/goals/goals_screens.dart';
import 'features/habits/habits_screens.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/shell.dart';
import 'features/templates/templates_screens.dart';

class MyJournalApp extends ConsumerStatefulWidget {
  const MyJournalApp({super.key});
  @override
  ConsumerState<MyJournalApp> createState() => _MyJournalAppState();
}

class _MyJournalAppState extends ConsumerState<MyJournalApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(supabaseProvider).auth;
    _seedIfSignedIn();
    _authSub = auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.initialSession) {
        _seedIfSignedIn();
      }
    });
  }

  Future<void> _seedIfSignedIn() async {
    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) return;
    try {
      await ref.read(templateRepoProvider).seedDefaultsIfEmpty();
      if (mounted) ref.invalidate(templatesProvider);
    } catch (_) {
      // best-effort; ignore
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'MyJournal',
      theme: buildJournalTheme(),
      routerConfig: router,
    );
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final loggedIn = user != null;
      final goingToAuth = state.matchedLocation == '/sign-in';
      if (!loggedIn && !goingToAuth) return '/sign-in';
      if (loggedIn && goingToAuth) return '/';
      return null;
    },
    refreshListenable: GoRouterRefreshStream(
      ref.watch(supabaseProvider).auth.onAuthStateChange,
    ),
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const AuthScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TodayScreen()),
          GoRoute(
              path: '/templates',
              builder: (_, _) => const TemplatesListScreen()),
          GoRoute(
              path: '/habits',
              builder: (_, _) => const HabitsListScreen()),
          GoRoute(
              path: '/goals',
              builder: (_, _) => const GoalsListScreen()),
          GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/templates/new',
        builder: (_, _) => const TemplateEditScreen(),
      ),
      GoRoute(
        path: '/templates/:id',
        builder: (_, s) =>
            TemplateEditScreen(templateId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/habits/new',
        builder: (_, _) => const HabitEditScreen(),
      ),
      GoRoute(
        path: '/goals/new',
        builder: (_, _) => const GoalEditScreen(),
      ),
      GoRoute(
        path: '/goals/:id',
        builder: (_, s) => GoalDetailScreen(goalId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/entries',
        builder: (_, _) => const EntriesListScreen(),
      ),
      GoRoute(
        path: '/entries/:id',
        builder: (_, s) => EntryEditScreen(entryId: s.pathParameters['id']!),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
