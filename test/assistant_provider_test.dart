// test/assistant_provider_test.dart
//
// BDD de AssistantProvider (lib/presentation/providers/assistant_provider.dart)
// con dobles de prueba en vez de Gemini/SharedPreferences/Firebase reales:
// FakeAssistantRepository, FakeQuotaService, FakeAssistantAnalyticsService,
// FakeAssistantUsageRepository y ProductProvider con FakeProductRepository.

import 'package:flutter_test/flutter_test.dart';

import 'package:frescorden/domain/entities/chat_message.dart';
import 'package:frescorden/presentation/providers/assistant_provider.dart';
import 'package:frescorden/presentation/providers/product_provider.dart';

import 'support/fake_repositories.dart';

void main() {
  late FakeAssistantRepository repo;
  late FakeQuotaService quota;
  late FakeAssistantAnalyticsService analytics;
  late FakeAssistantUsageRepository usageRepo;
  late ProductProvider productProvider;

  setUp(() {
    repo = FakeAssistantRepository();
    quota = FakeQuotaService();
    analytics = FakeAssistantAnalyticsService();
    usageRepo = FakeAssistantUsageRepository();
    productProvider = ProductProvider(FakeProductRepository());
  });

  AssistantProvider buildProvider() => AssistantProvider(
    repo,
    productProvider,
    usageRepo,
    quota,
    analytics,
  );

  group('Historia de Usuario: Como usuario, quiero conversar con el '
      'Asistente Culinario dentro de mi cuota diaria', () {
    test(
      'Escenario: al crearse, carga la cuota restante desde el servicio',
      () async {
        quota.remaining = 3;
        final provider = buildProvider();

        await Future<void>.delayed(Duration.zero);

        expect(provider.remainingQueries, 3);
        expect(provider.isLimitReached, isFalse);
      },
    );

    test(
      'Escenario: un mensaje vacío no se envía ni consume cuota',
      () async {
        final provider = buildProvider();
        await Future<void>.delayed(Duration.zero);

        await provider.sendMessage('   ');

        expect(provider.messages, isEmpty);
        expect(repo.promptsSent, isEmpty);
      },
    );

    test(
      'Escenario: un mensaje exitoso agrega la respuesta, descuenta la '
      'cuota y registra el evento de analítica',
      () async {
        repo.replyToReturn = 'Puedes preparar un arroz con pollo.';
        final provider = buildProvider();
        await Future<void>.delayed(Duration.zero);

        await provider.sendMessage('¿Qué cocino hoy?');

        expect(provider.messages.length, 2);
        expect(provider.messages.first.role, ChatRole.user);
        expect(provider.messages.last.role, ChatRole.model);
        expect(provider.messages.last.text, 'Puedes preparar un arroz con pollo.');
        expect(provider.error, isNull);
        expect(quota.recordedQueries, 1);
        expect(analytics.loggedQueries, 1);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'Escenario: si el hogar activo está definido, registra la consulta '
      'en el repositorio de uso',
      () async {
        productProvider.setActiveHousehold('hogar-1');
        final provider = buildProvider();
        await Future<void>.delayed(Duration.zero);

        await provider.sendMessage('¿Qué cocino hoy?');
        await Future<void>.delayed(Duration.zero);

        expect(usageRepo.loggedHouseholdIds, ['hogar-1']);
      },
    );

    test(
      'Escenario: un fallo del repositorio deja un mensaje de error y no '
      'descuenta la cuota',
      () async {
        repo.sendMessageError = Exception('Gemini caído');
        final provider = buildProvider();
        await Future<void>.delayed(Duration.zero);

        await provider.sendMessage('¿Qué cocino hoy?');

        expect(provider.error, isNotNull);
        expect(
          provider.messages.last.text,
          'Ocurrió un error al responder. Intenta de nuevo.',
        );
        expect(quota.recordedQueries, 0);
        expect(analytics.loggedQueries, 0);
      },
    );

    test(
      'Escenario: con la cuota agotada, no se envían más mensajes',
      () async {
        quota.remaining = 0;
        final provider = buildProvider();
        await Future<void>.delayed(Duration.zero);

        await provider.sendMessage('¿Qué cocino hoy?');

        expect(provider.isLimitReached, isTrue);
        expect(repo.promptsSent, isEmpty);
      },
    );

    test(
      'Escenario: clearConversation limpia el historial, el error y '
      'reinicia la conversación en el repositorio',
      () async {
        repo.sendMessageError = Exception('Gemini caído');
        final provider = buildProvider();
        await Future<void>.delayed(Duration.zero);
        await provider.sendMessage('¿Qué cocino hoy?');

        provider.clearConversation();

        expect(provider.messages, isEmpty);
        expect(provider.error, isNull);
        expect(repo.resetConversationCalled, isTrue);
      },
    );
  });
}
