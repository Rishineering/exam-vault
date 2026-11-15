import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Welcome screen — the first thing users see when they open the app.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.tertiary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.fact_check_rounded,
                      size: 48,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'SetYourRank',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Turn previous-year exam papers into a clean, editable '
                    'question table — one question per row.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      ),
                      icon: const Icon(
                        Icons.login_rounded,
                        size: 20,
                      ),
                      label: const Text(
                        'Get started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.onPrimary,
                        foregroundColor: scheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Offline-first · No account · No server',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
