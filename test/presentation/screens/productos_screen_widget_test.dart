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

import 'package:frescorden/domain/entities/food_category.dart';
import 'package:frescorden/domain/entities/product.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';
import 'package:frescorden/presentation/widgets/common/skeleton_loader.dart';
import 'package:frescorden/presentation/screens/productos_screen.dart';

import '../../support/fake_repositories.dart';
import '../../support/fake_services.dart';

Widget _wrap(ProductProvider provider, {void Function(Map<String, dynamic>)? onEdit}) {
  return MaterialApp(
    home: ChangeNotifierProvider<ProductProvider>.value(
      value: provider,
      child: ProductosScreen(onEdit: onEdit ?? (_) {}),
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

    /// Viewport mucho más alto: la hoja de filtros (categorías + stock
    /// bajo + 3 opciones de orden) no entra completa en un alto de
    /// teléfono normal, y un tap fuera de los límites de la ventana de
    /// test no llega al widget (falla en silencio, ver warnIfMissed).
    void useTallViewportForFilterSheet(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 9000);
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

    testWidgets(
      'Escenario: el buscador filtra la lista por nombre',
      (tester) async {
        useRealisticPhoneViewport(tester);
        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [
          Product(id: 'p1', name: 'Arroz', quantity: 2, unit: 'kg', entryDate: DateTime(2026, 1, 1)),
          Product(id: 'p2', name: 'Leche', quantity: 1, unit: 'litro', entryDate: DateTime(2026, 1, 1)),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.enterText(find.byType(TextField), 'arr');
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.text('Arroz'), findsOneWidget);
        expect(find.text('Leche'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: el filtro por categoría muestra solo esa categoría',
      (tester) async {
        useTallViewportForFilterSheet(tester);
        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [
          Product(
            id: 'p1', name: 'Arroz', quantity: 2, unit: 'kg',
            entryDate: DateTime(2026, 1, 1), category: FoodCategory.panaderia,
          ),
          Product(
            id: 'p2', name: 'Leche', quantity: 1, unit: 'litro',
            entryDate: DateTime(2026, 1, 1), category: FoodCategory.lacteos,
          ),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byIcon(Icons.filter_list));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, FoodCategory.lacteos.label));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Leche'), findsOneWidget);
        expect(find.text('Arroz'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: el filtro "Solo stock bajo" oculta los productos que '
      'no están en stock bajo',
      (tester) async {
        useTallViewportForFilterSheet(tester);
        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [
          Product(
            id: 'p1', name: 'Arroz', quantity: 1, unit: 'kg',
            entryDate: DateTime(2026, 1, 1), minStock: 2,
          ),
          Product(
            id: 'p2', name: 'Leche', quantity: 5, unit: 'litro',
            entryDate: DateTime(2026, 1, 1),
          ),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byIcon(Icons.filter_list));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Solo stock bajo'));
        await tester.pump(const Duration(milliseconds: 300));
        // Cierra la hoja de filtros (como haría la persona al deslizarla
        // hacia abajo) antes de verificar la lista ya filtrada debajo.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Arroz'), findsOneWidget);
        expect(find.text('Leche'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: ordenar por cantidad (mayor a menor) reordena la lista',
      (tester) async {
        useTallViewportForFilterSheet(tester);
        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [
          Product(id: 'p1', name: 'Arroz', quantity: 1, unit: 'kg', entryDate: DateTime(2026, 1, 1)),
          Product(id: 'p2', name: 'Leche', quantity: 9, unit: 'litro', entryDate: DateTime(2026, 1, 1)),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byIcon(Icons.filter_list));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cantidad (mayor a menor)'));
        await tester.pump(const Duration(milliseconds: 700));

        final arrozY = tester.getTopLeft(find.text('Arroz')).dy;
        final lecheY = tester.getTopLeft(find.text('Leche')).dy;
        expect(lecheY, lessThan(arrozY));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: ordenar por fecha de expiración (más cercana primero)',
      (tester) async {
        useTallViewportForFilterSheet(tester);
        provider.setActiveHousehold('hogar-1');
        repo.emit('hogar-1', [
          Product(
            id: 'p1', name: 'Arroz', quantity: 1, unit: 'kg',
            entryDate: DateTime(2026, 1, 1),
            expirationDate: DateTime.now().add(const Duration(days: 30)),
          ),
          Product(
            id: 'p2', name: 'Leche', quantity: 1, unit: 'litro',
            entryDate: DateTime(2026, 1, 1),
            expirationDate: DateTime.now().add(const Duration(days: 2)),
          ),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byIcon(Icons.filter_list));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fecha de expiración (más cercana)'));
        await tester.pump(const Duration(milliseconds: 700));

        final arrozY = tester.getTopLeft(find.text('Arroz')).dy;
        final lecheY = tester.getTopLeft(find.text('Leche')).dy;
        expect(lecheY, lessThan(arrozY));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Estabilidad visual: ProductosScreen — tarjeta de producto', () {
    late FakeProductRepository repo;
    late ProductProvider provider;

    void useRealisticPhoneViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    setUp(() {
      repo = FakeProductRepository();
      provider = ProductProvider(
        repo,
        null,
        null,
        FakeNotificationService(),
        FakeAnalyticsService(),
      );
      provider.setActiveHousehold('hogar-1');
    });

    tearDown(() {
      provider.dispose();
      repo.dispose();
    });

    testWidgets(
      'Escenario: un producto en stock bajo muestra el badge '
      '"Stock bajo"',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(
            id: 'p1', name: 'Arroz', quantity: 1, unit: 'kg',
            entryDate: DateTime(2026, 1, 1), minStock: 2,
          ),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.text('Stock bajo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: un producto a granel muestra hace cuántos días está '
      'almacenado',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(
            id: 'p1', name: 'Tomate', quantity: 3, unit: 'kg',
            entryDate: DateTime.now().subtract(const Duration(days: 2)),
            isBulk: true,
          ),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.textContaining('Almacenado hace 2 días'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: un producto a granel con 5 o más días almacenado '
      'muestra el aviso crítico',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(
            id: 'p1', name: 'Tomate', quantity: 3, unit: 'kg',
            entryDate: DateTime.now().subtract(const Duration(days: 6)),
            isBulk: true,
          ),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byIcon(Icons.warning_amber), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: tocar el ícono de editar invoca onEdit con el producto',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(id: 'p1', name: 'Arroz', quantity: 2, unit: 'kg', entryDate: DateTime(2026, 1, 1)),
        ]);
        Map<String, dynamic>? edited;
        await tester.pumpWidget(_wrap(provider, onEdit: (p) => edited = p));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pump();

        expect(edited?['id'], 'p1');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: descontar 1 unidad de un producto con más de 1 llama a '
      'decrementQuantity sin abrir el diálogo de retiro',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(id: 'p1', name: 'Arroz', quantity: 2, unit: 'kg', entryDate: DateTime(2026, 1, 1)),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byTooltip('Descontar 1'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Retirar producto'), findsNothing);
        expect(repo.updated.single.quantity, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: descontar la última unidad abre el diálogo de retiro '
      'en vez de dejarla en 0',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(id: 'p1', name: 'Arroz', quantity: 1, unit: 'kg', entryDate: DateTime(2026, 1, 1)),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byTooltip('Descontar 1'));
        await tester.pumpAndSettle();

        expect(find.text('Retirar producto'), findsOneWidget);
        expect(repo.updated, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: retirar un producto y marcarlo "Consumido" lo elimina '
      'con ese resultado y muestra la confirmación',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(id: 'p1', name: 'Arroz', quantity: 1, unit: 'kg', entryDate: DateTime(2026, 1, 1)),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Consumido'));
        await tester.pumpAndSettle();

        expect(repo.deletedIds, ['p1']);
        expect(find.text('Producto marcado como consumido'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: retirar un producto y marcarlo "Desperdiciado" lo '
      'elimina con ese resultado y muestra la confirmación',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(id: 'p1', name: 'Arroz', quantity: 1, unit: 'kg', entryDate: DateTime(2026, 1, 1)),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Desperdiciado / Botado'));
        await tester.pumpAndSettle();

        expect(repo.deletedIds, ['p1']);
        expect(
          find.text('Producto marcado como desperdiciado'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: cancelar el diálogo de retiro no elimina el producto',
      (tester) async {
        useRealisticPhoneViewport(tester);
        repo.emit('hogar-1', [
          Product(id: 'p1', name: 'Arroz', quantity: 1, unit: 'kg', entryDate: DateTime(2026, 1, 1)),
        ]);
        await tester.pumpWidget(_wrap(provider));
        await tester.pump(const Duration(milliseconds: 700));

        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(repo.deletedIds, isEmpty);
        expect(find.text('Retirar producto'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
