import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/supabase.dart';

class MyJournalApp extends ConsumerWidget {
  const MyJournalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'MyJournal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
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
      GoRoute(
        path: '/',
        builder: (_, _) => const _HomePlaceholder(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (_, _) => const _SignInPlaceholder(),
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

class _HomePlaceholder extends ConsumerWidget {
  const _HomePlaceholder();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('MyJournal')),
      body: Center(child: Text('Signed in as ${user?.email ?? '...'}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(supabaseProvider).auth.signOut(),
        child: const Icon(Icons.logout),
      ),
    );
  }
}

class _SignInPlaceholder extends ConsumerWidget {
  const _SignInPlaceholder();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: const Center(child: Text('Auth UI goes here')),
    );
  }
}
