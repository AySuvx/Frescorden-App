// lib/presentation/screens/onboarding/onboarding_screen.dart
//
// Tutorial interactivo de 3 tarjetas para usuarios
// nuevos. Solo lo ve quien todavía no tiene la bandera persistente
// `onboarding_completed` en SharedPreferences (ver SplashScreen, que decide
// si esta pantalla se muestra) — al terminar u omitir, la guarda en `true`
// y no vuelve a aparecer.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/theme/app_spacing.dart';
import '../../../routes.dart';
import '../inicio_screen.dart';
import '../login_screen.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/primary_button.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.inventory_2_outlined,
    title: 'Control de Inventario y Desperdicio Cero',
    description:
        'Registra lo que tienes en casa y recibe alertas antes de que se '
        'venza — nada se pierde por olvido.',
  ),
  _OnboardingSlide(
    icon: Icons.smart_toy_outlined,
    title: 'Asistente Culinario IA con Recetas Personalizadas',
    description:
        'Pregúntale qué cocinar: prioriza lo que está por vencer y arma '
        'recetas con lo que ya tienes en casa.',
  ),
  _OnboardingSlide(
    icon: Icons.groups_outlined,
    title: 'Gestión Colaborativa en el Hogar',
    description:
        'Comparte el inventario con tu familia — todos ven y editan en '
        'tiempo real, desde cualquier dispositivo.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _onboardingCompletedKey = 'onboarding_completed';

  final _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _slides.length - 1;

  void _goToNextPage() {
    HapticFeedback.lightImpact();
    if (_isLastPage) {
      _completeOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Persiste la bandera y navega — mismo criterio de destino que
  /// SplashScreen (Login vs. Inicio), pero acá `currentUser` síncrono ya es
  /// seguro: para cuando el usuario llega a esta pantalla, SplashScreen ya
  /// esperó la restauración de la sesión de Firebase Auth.
  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    if (!mounted) return;

    final isAuthenticated = context.read<AuthProvider>().currentUser != null;
    final destination = isAuthenticated
        ? const InicioScreen()
        : const LoginScreen();
    final routeName = isAuthenticated ? AppRoutes.inicio : AppRoutes.login;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => destination,
        settings: RouteSettings(name: routeName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: AppSpacing.buttonHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: Visibility(
                  visible: !_isLastPage,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, AppSpacing.buttonHeight),
                      ),
                      onPressed: _isCompleting ? null : _completeOnboarding,
                      child: const Text('Omitir'),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _OnboardingSlideView(
                    slide: _slides[index],
                    accent: _accentFor(index, colorScheme),
                  );
                },
              ),
            ),
            _DotsIndicator(count: _slides.length, currentIndex: _currentPage),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PrimaryButton(
                label: _isLastPage ? 'Comenzar' : 'Siguiente',
                isLoading: _isCompleting,
                onPressed: _goToNextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Un acento distinto por slide (dentro de la paleta ya definida por el
  /// tema, sin introducir hex nuevos) — ayuda a distinguir las 3 tarjetas
  /// de un vistazo, además del ícono y el texto.
  Color _accentFor(int index, ColorScheme scheme) {
    return switch (index) {
      0 => scheme.primary,
      1 => scheme.tertiary,
      _ => scheme.secondary,
    };
  }
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({required this.slide, required this.accent});

  final _OnboardingSlide slide;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 64, color: accent),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador de páginas (dots): el activo se alarga en vez de solo cambiar
/// de color — más perceptible que un simple cambio de tono, sobre todo
/// para quien tiene dificultad para distinguir colores.
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
        );
      }),
    );
  }
}
