import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _signUpMode = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final auth = ref.read(supabaseProvider).auth;
    try {
      if (_signUpMode) {
        final res = await auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (res.session == null && mounted) {
          setState(() => _info =
              "Almost there — check your inbox for a confirmation link 💌");
        }
      } else {
        await auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: JournalPalette.sageLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🌱', style: TextStyle(fontSize: 48)),
                      ),
                    ).animate().scale(
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                          begin: const Offset(0.6, 0.6),
                        ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'MyJournal',
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                  const SizedBox(height: 6),
                  Text(
                    _signUpMode
                        ? 'A quiet place to tend your days 🌿'
                        : 'Welcome back — your garden missed you 🌸',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: JournalPalette.inkSoft,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !_busy,
                  ).animate().slideX(
                        delay: 500.ms,
                        duration: 400.ms,
                        begin: -0.05,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    enabled: !_busy,
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ).animate().slideX(
                        delay: 600.ms,
                        duration: 400.ms,
                        begin: -0.05,
                        curve: Curves.easeOutCubic,
                      ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _Banner(
                      text: _error!,
                      color: JournalPalette.terracotta,
                      icon: Icons.error_outline,
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 14),
                    _Banner(
                      text: _info!,
                      color: JournalPalette.sageDark,
                      icon: Icons.mark_email_read_outlined,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_signUpMode ? 'Plant your journal 🌱' : 'Open my journal'),
                  ).animate().fadeIn(delay: 700.ms),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _signUpMode = !_signUpMode;
                              _error = null;
                              _info = null;
                            }),
                    child: Text(
                      _signUpMode
                          ? 'Already have an account? Sign in'
                          : "New here? Plant a journal",
                      style: TextStyle(color: JournalPalette.terracotta),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
