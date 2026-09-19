// Tema Material3 de la app:
//
//  1. Fija la paleta de marca (AppColors) como semilla real,
//     con `contrastLevel` de Material3 elevado a 0.5 (tier "medium
//     contrast" de la especificación) para un contraste AA riguroso en
//     TODOS los pares on*/container generados, no solo primary/onPrimary.
//  2. Toma `error` (Coral) y `tertiary` (Ámbar) de sus propias semillas —
//     `ColorScheme.fromSeed` no acepta una key color separada para esos
//     roles — y los injerta sobre el esquema principal, así cada uno
//     conserva el algoritmo tonal completo (container + on*Container)
//     en vez de un hex fijo sin pareja de contraste calculada.
//  3. Fuerza los fondos literales del brief (fondo de pantalla y tarjeta)
//     en vez de dejar que el tono `surface` derivado del seed los
//     reemplace — en modo oscuro en particular, así se logra el fondo
//     "casi negro" pensado para OLED en vez del gris-verdoso que
//     produciría el tono `surface` estándar de Material3.
//  4. `surfaceTintColor: Colors.transparent` en Card/AppBar: sin esto,
//     Material3 tiñe cualquier superficie elevada con un velo del color
//     `primary` (más notorio cuanto más alta la elevación), lo que
//     correría los hex exactos de AppColors hacia un verde no deseado.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Transición global de navegación: desvanecimiento +
/// deslizamiento sutil con `Curves.fastOutSlowIn`, en vez del "slide desde
/// la derecha" por defecto de Android. Se aplica una sola vez acá (vía
/// `PageTransitionsTheme`) y cubre automáticamente cualquier
/// `MaterialPageRoute` de la app — no hace falta tocar cada
/// `Navigator.push`. No se usa el paquete `animations` (SharedAxis/Fade
/// ThroughTransition): esta curva + fade simple ya da el efecto pedido sin
/// sumar una dependencia nueva.
class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.fastOutSlowIn,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _buildColorScheme(brightness);
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: _buildTextTheme(brightness, colorScheme),

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        // Sombra ligera en claro; en oscuro la separación la da el propio
        // color de tarjeta (#1E1E1E) contra el fondo (#121212) — "elevación
        // tonal" en vez de sombra, que en OLED apenas se percibe.
        elevation: isDark ? 0 : 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: isDark
              ? BorderSide(color: colorScheme.outlineVariant)
              : BorderSide.none,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          // Size(64, buttonHeight), NO Size.fromHeight(buttonHeight):
          // fromHeight fija el ancho en double.infinity. Dentro de un
          // contenedor con ancho acotado (Column, SizedBox) eso se recorta
          // sin drama y el botón queda full-width — pero un ElevatedButton
          // suelto dentro de un Row/Wrap SIN Expanded recibe del padre un
          // ancho genuinamente no acotado en su eje principal: el mínimo
          // infinito ya no tiene nada contra qué recortarse, la restricción
          // de layout resultante es infinita y ese subárbol deja de
          // pintarse por completo (sin excepción visible en consola) — así
          // se rompían "Tomar Foto" en AddProductScreen y cualquier otro
          // botón suelto en un Row. 64dp de ancho mínimo es el piso
          // estándar de Material, sin ese riesgo.
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: buttonShape,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: buttonShape,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: _FadeSlidePageTransitionsBuilder(),
        },
      ),

      // Estandariza TODOS los AlertDialog de la app (expulsar miembro,
      // salir del hogar, eliminar cuenta, permisos, etc.) desde un único
      // lugar — AlertDialog hereda shape/backgroundColor/elevación de acá
      // salvo que una instancia puntual los pise explícitamente (ninguna
      // lo hace hoy).
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 4 : 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
    );
  }

  /// Par tipográfico "Soft Rounded" (recomendación ui-ux-pro-max para marcas
  /// cálidas/orgánicas, ver búsqueda `--domain typography`): Varela Round en
  /// titulares (terminales redondeadas → coherente con la paleta orgánica y
  /// los 16dp de radio de [CustomCard]) y Nunito Sans en cuerpo de texto
  /// (alta legibilidad en tamaños pequeños). Reemplaza al `GoogleFonts
  /// .poppins()` puntual que solo existía en login_screen.dart — una sola
  /// fuente de verdad tipográfica para toda la app.
  static TextTheme _buildTextTheme(Brightness brightness, ColorScheme scheme) {
    final base = ThemeData(brightness: brightness).textTheme;
    final bodyTheme = GoogleFonts.nunitoSansTextTheme(base);
    final headingStyles = <String, TextStyle?>{
      'displayLarge': bodyTheme.displayLarge,
      'displayMedium': bodyTheme.displayMedium,
      'displaySmall': bodyTheme.displaySmall,
      'headlineLarge': bodyTheme.headlineLarge,
      'headlineMedium': bodyTheme.headlineMedium,
      'headlineSmall': bodyTheme.headlineSmall,
      'titleLarge': bodyTheme.titleLarge,
    };
    return bodyTheme
        .copyWith(
          displayLarge: GoogleFonts.varelaRound(
            textStyle: headingStyles['displayLarge'],
          ),
          displayMedium: GoogleFonts.varelaRound(
            textStyle: headingStyles['displayMedium'],
          ),
          displaySmall: GoogleFonts.varelaRound(
            textStyle: headingStyles['displaySmall'],
          ),
          headlineLarge: GoogleFonts.varelaRound(
            textStyle: headingStyles['headlineLarge'],
          ),
          headlineMedium: GoogleFonts.varelaRound(
            textStyle: headingStyles['headlineMedium'],
          ),
          headlineSmall: GoogleFonts.varelaRound(
            textStyle: headingStyles['headlineSmall'],
          ),
          titleLarge: GoogleFonts.varelaRound(
            textStyle: headingStyles['titleLarge'],
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  static ColorScheme _buildColorScheme(Brightness brightness) {
    const contrastLevel = 0.5; // Material3 "medium contrast" — WCAG AA

    final errorSeed = ColorScheme.fromSeed(
      seedColor: AppColors.error,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );
    final warningSeed = ColorScheme.fromSeed(
      seedColor: AppColors.warning,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );

    return ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      contrastLevel: contrastLevel,
      surface:
          brightness == Brightness.dark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
    ).copyWith(
      error: errorSeed.primary,
      onError: errorSeed.onPrimary,
      errorContainer: errorSeed.primaryContainer,
      onErrorContainer: errorSeed.onPrimaryContainer,
      tertiary: warningSeed.primary,
      onTertiary: warningSeed.onPrimary,
      tertiaryContainer: warningSeed.primaryContainer,
      onTertiaryContainer: warningSeed.onPrimaryContainer,
    );
  }
}
