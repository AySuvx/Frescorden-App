// Tutorial de ayuda reabrible en cualquier momento desde el ícono "?" del
// AppBar de InicioScreen — a diferencia de OnboardingScreen (una sola vez,
// bloqueante), este se puede cerrar en cualquier página con el botón "X".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme/app_spacing.dart';
import '../widgets/common/primary_button.dart';

class _TutorialSlide {
  const _TutorialSlide({
    required this.sticker,
    required this.title,
    required this.description,
    this.isImportant = false,
  });

  final String sticker;
  final String title;
  final String description;

  /// `true` solo para la recomendación de batería/segundo plano — se
  /// resalta distinto (no es una explicación de una función, es una
  /// acción que el usuario debería hacer en Ajustes del sistema).
  final bool isImportant;
}

const _slides = [
  _TutorialSlide(
    sticker: 'assets/Frescorden-logo/stickers/sticker-fresh.png',
    title: 'Controla tu inventario',
    description: 'Registra lo que tienes con el botón "+" y te avisamos '
        'antes de que algo se venza.',
  ),
  _TutorialSlide(
    sticker: 'assets/Frescorden-logo/stickers/sticker-think.png',
    title: 'Pregúntale al Asistente de IA',
    description:
        'Cuéntale qué tienes o qué se te antoja: te sugiere recetas '
        'priorizando lo que está por vencer en tu inventario.',
  ),
  _TutorialSlide(
    sticker: 'assets/Frescorden-logo/stickers/sticker-love.png',
    title: 'Arma tu Lista de Compras',
    description:
        'Elige tu nivel de presupuesto y cuántas personas comen en casa. '
        'Cuando ya tengas algo de la lista, deslízalo hacia la izquierda '
        'para quitarlo.',
  ),
  _TutorialSlide(
    sticker: 'assets/Frescorden-logo/stickers/sticker-joy.png',
    title: 'Comparte tu hogar',
    description:
        'Invita a tu familia con un código desde "Mi Hogar": todos ven y '
        'editan el mismo inventario, sin duplicar el trabajo.',
  ),
  _TutorialSlide(
    sticker: 'assets/Frescorden-logo/stickers/sticker-warn.png',
    title: 'Mantén las alertas activas',
    description:
        'Para que los avisos de vencimiento suenen incluso con la pantalla '
        'apagada, ve a Configuración y activa "Alertas en segundo plano": '
        'desactiva el ahorro de batería y el autoinicio para '
        'Fresc(o)rden. Si no lo haces, el sistema puede cerrar la app y '
        'no avisarte a tiempo.',
    isImportant: true,
  ),
];

class HomeTutorialScreen extends StatefulWidget {
  const HomeTutorialScreen({super.key});

  @override
  State<HomeTutorialScreen> createState() => _HomeTutorialScreenState();
}

class _HomeTutorialScreenState extends State<HomeTutorialScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _slides.length - 1;

  void _goToNextPage() {
    HapticFeedback.lightImpact();
    if (_isLastPage) {
      Navigator.of(context).pop();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
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
                  return _TutorialSlideView(slide: _slides[index]);
                },
              ),
            ),
            _DotsIndicator(count: _slides.length, currentIndex: _currentPage),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PrimaryButton(
                label: _isLastPage ? 'Entendido' : 'Siguiente',
                onPressed: _goToNextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialSlideView extends StatelessWidget {
  const _TutorialSlideView({required this.slide});

  final _TutorialSlide slide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // LayoutBuilder + ConstrainedBox/IntrinsicHeight: centra el contenido
    // cuando sí cabe (como antes), pero deja hacer scroll cuando no — la
    // ficha "Importante" (chip extra + descripción más larga) se salía de
    // la pantalla en celulares con menos alto disponible.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: slide.isImportant
                          ? BoxDecoration(
                              color: colorScheme.errorContainer,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Image.asset(
                        slide.sticker,
                        width: 160,
                        height: 160,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (slide.isImportant) ...[
                    Chip(
                      avatar: Icon(
                        Icons.priority_high,
                        size: 18,
                        color: colorScheme.onErrorContainer,
                      ),
                      label: Text(
                        'Importante',
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: colorScheme.errorContainer,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
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
            ),
          ),
        );
      },
    );
  }
}

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
