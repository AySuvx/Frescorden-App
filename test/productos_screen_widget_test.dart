// test/productos_screen_widget_test.dart
//
// Widget tests de estabilidad visual (Fase 6, Módulo 3): verifican que
// ProductosScreen renderiza sin excepciones en sus estados reales —
// cargando (SkeletonLoader), inventario vacío e inventario con productos
// (CustomCard) — usando ProductProvider real con FakeProductRepository en
// vez de Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/widgets/common/skeleton_loader.dart';
import 'package:frescorden/screens/productos_screen.dart';

import 'support/fake_repositories.dart';

Widget _wrap(ProductProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<ProductProvider>.value(
      value: provider,
      child: ProductosScreen(onEdit: (_) {}),
    ),
  );
}

void main() {
  group('Estabilidad visual: ProductosScreen', () {
    late FakeProductRepository repo;
    late ProductProvider provider;

    setUp(() {
      repo = FakeProductRepository();
      provider = ProductProvider(repo);
    });

    tearDown(() {
      provider.dispose();
      repo.dispose();
    });

    /// Viewport de tamaño de teléfono real: el default de flutter_test
    /// (800x600 lógicos) es más corto que cualquier teléfono real y hace
    /// desbordar layouts ya verificados en dispositivo físico (Fase 6,
    /// Módulo 1) — no es un bug de la pantalla, es el tamaño de ventana de
    /// test.
    void useRealisticPhoneViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets(
      'Escenario: mientras el inventario está cargando, se muestra '
      'SkeletonLoader sin excepciones',
      (tester) async {
        useRealisticPhoneViewport(tester);

        // Dado un hogar activo cuyo primer snapshot todavía no llegó
        provider.setActiveHousehold('hogar-1');

        // Cuando se renderiza la pantalla
        await tester.pumpWidget(_wrap(provider));
        await tester.pump();

        // Entonces se muestra el SkeletonLoader, sin ninguna excepción
        expect(find.byType(SkeletonLoader), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con el inventario vacío, se muestra el estado vacío '
      'sin excepciones',
      (tester) async {
        useRealisticPhoneViewport(tester);

        // Dado un hogar activo con inventario vacío
        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', []);

        // Cuando se renderiza la pantalla
        await tester.pumpWidget(_wrap(provider));
        await tester.pump();

        // Entonces no aparece el SkeletonLoader y no hay excepciones
        expect(find.byType(SkeletonLoader), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con productos reales en el inventario, la lista '
      'renderiza sin excepciones',
      (tester) async {
        useRealisticPhoneViewport(tester);

        // Dado un hogar activo con productos (sin foto local, para no
        // depender de archivos reales en el entorno de test)
        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [
          Product(
            id: 'p1',
            name: 'Arroz',
            quantity: 2,
            unit: 'kg',
            entryDate: DateTime(2026, 1, 1),
          ),
          Product(
            id: 'p2',
            name: 'Leche',
            quantity: 1,
            unit: 'litro',
            entryDate: DateTime(2026, 1, 1),
          ),
        ]);

        // Cuando se renderiza la pantalla — se deja correr el tiempo
        // suficiente para que la animación de entrada por ítem
        // (_FadeSlideIn, hasta 300ms de retraso escalonado + 350ms de
        // animación) termine del todo; si no, su AnimationController queda
        // con un Timer pendiente al terminar el test.
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        // Entonces ambos productos aparecen y no hay excepciones
        expect(find.text('Arroz'), findsOneWidget);
        expect(find.text('Leche'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
