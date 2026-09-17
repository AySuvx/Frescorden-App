// lib/presentation/screens/splash/splash_screen.dart
//
// Pantalla de entrada. Antes, la decisión inicial
// (Login vs. Inicio) vivía en un StreamBuilder<AppUser?> directo en
// MyApp.home (ver main.dart): apenas resolvía el primer estado de
// autenticación, mostraba una pantalla u otra sin transición. Ahora esa
// decisión se amplía a 3 destinos (Onboarding / Login / Inicio) y vive acá,
// con una animación de marca mientras se resuelven en paralelo las dos
// fuentes de verdad que la deciden.
//
// El fondo de este Scaffold no fija un color propio: hereda
// `scaffoldBackgroundColor` de AppTheme (`colorScheme.surface`, que ya es
// AppColors.backgroundLight/backgroundDark según el modo) — así no hay
// salto de color entre el `launch_background` nativo de Android (ver
// android/app/src/main/res/drawable-v21/launch_background.xml, que también
// resuelve a oscuro/claro vía `?android:colorBackground` y no fija blanco)
// y el primer frame de Flutter.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/theme/app_spacing.dart';
import '../../../routes.dart';
import '../../../screens/inicio_screen.dart';
import '../../../screens/login_screen.dart';
import '../../providers/auth_provider.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _onboardingCompletedKey = 'onboarding_completed';

  /// Piso de tiempo visible de la marca: aunque Firebase Auth + prefs
  /// resuelvan en pocos milisegundos, un splash que parpadea <100ms en un
  /// dispositivo rápido se ve como un glitch, no como una pantalla de
  /// entrada. 1200ms es suficiente para leer el nombre sin sentirse una
  /// demora artificial.
  static const _minDisplayTime = Duration(milliseconds: 1200);

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(curved);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _controller.forward();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();

    final prefs = SharedPreferences.getInstance();
    // authStateChanges().first (no el getter síncrono `currentUser`):
    // recién después de Firebase.initializeApp() la sesión persistida
    // todavía puede no estar restaurada — `currentUser` leído demasiado
    // pronto puede dar `null` para un usuario que sí tiene sesión válida.
    // El stream, en cambio, emite su primer valor solo cuando esa
    // restauración ya resolvió (mismo criterio que el StreamBuilder
    // anterior en main.dart, solo que esperado una vez en vez de
    // reconstruir la UI reactivamente).
    final authFirstState = context.read<AuthProvider>().authStateChanges.first;

    final results = await Future.wait([prefs, authFirstState]);
    final onboardingCompleted =
        (results[0] as SharedPreferences).getBool(_onboardingCompletedKey) ??
        false;
    final isAuthenticated = results[1] != null;

    final elapsed = stopwatch.elapsed;
    if (elapsed < _minDisplayTime) {
      await Future.delayed(_minDisplayTime - elapsed);
    }
    if (!mounted) return;
    _navigateToDestination(
      onboardingCompleted: onboardingCompleted,
      isAuthenticated: isAuthenticated,
    );
  }

  void _navigateToDestination({
    required bool onboardingCompleted,
    required bool isAuthenticated,
  }) {
    final Widget destination;
    final String routeName;
    if (!onboardingCompleted) {
      destination = const OnboardingScreen();
      routeName = AppRoutes.onboarding;
    } else if (!isAuthenticated) {
      destination = const LoginScreen();
      routeName = AppRoutes.login;
    } else {
      destination = const InicioScreen();
      routeName = AppRoutes.inicio;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: RouteSettings(name: routeName),
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: destination),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/manzana.png', width: 96, height: 96),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Fresc(o)rden',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
