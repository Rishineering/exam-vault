import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/welcome_screen.dart';

class ExamVaultApp extends StatefulWidget {
  const ExamVaultApp({super.key});

  @override
  State<ExamVaultApp> createState() => _ExamVaultAppState();
}

class _ExamVaultAppState extends State<ExamVaultApp> {
  late final AppState _state;
  bool _initialized = false;
  Widget _home = const WelcomeScreen();

  @override
  void initState() {
    super.initState();
    _state = AppState();
    _state.refresh();
    _resolveHome();
  }

  Future<void> _resolveHome() async {
    final complete = await _state.isOnboardingComplete();
    if (!mounted) return;
    setState(() {
      _home = complete ? const HomeScreen() : const WelcomeScreen();
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3554D1);

    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'ExamVault',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: _buildTheme(seed, Brightness.light),
        darkTheme: _buildTheme(seed, Brightness.dark),
        home: _initialized ? _home : const WelcomeScreen(),
      ),
    );
  }

  ThemeData _buildTheme(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

/// Provides [AppState] to the widget tree and rebuilds dependents when it
/// changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree.');
    return scope!.notifier!;
  }

  /// Reads the state without subscribing to changes (for callbacks).
  static AppState read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'AppScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}
