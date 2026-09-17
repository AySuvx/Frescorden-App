// lib/main.dart
//
// Clean Architecture:
// Se reemplaza el ChangeNotifierProvider único por MultiProvider y se
// registran ProductProvider y AuthProvider con su cadena de dependencias
// inyectadas:
//
//   ProductProvider
//     └─ ProductRepositoryImpl
//          └─ FirestoreProductDataSource
//               └─ FirebaseFirestore.instance (externo)
//
//   AuthProvider
//     └─ AuthRepositoryImpl
//          └─ FirebaseAuth.instance / GoogleSignIn() / FirebaseFirestore.instance (externos)
//
// Ninguna pantalla instancia estas clases directamente; las obtienen a
// través de context.read<...>() / context.watch<...>().

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:provider/provider.dart';

import 'config/theme/app_theme.dart';
import 'config/theme/theme_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';

// Capa de datos (instanciada aquí, no en las pantallas)
import 'data/datasources/firestore_product_datasource.dart';
import 'data/repositories/product_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/datasources/recipe_local_datasource.dart';
import 'data/repositories/recipe_repository_impl.dart';
import 'data/datasources/shopping_local_datasource.dart';
import 'data/repositories/shopping_repository_impl.dart';
import 'data/datasources/firestore_product_history_datasource.dart';
import 'data/repositories/product_history_repository_impl.dart';
import 'data/repositories/analytics_repository_impl.dart';
import 'data/datasources/firestore_household_datasource.dart';
import 'data/repositories/household_repository_impl.dart';
import 'data/datasources/gemini_assistant_data_source.dart';
import 'data/repositories/assistant_repository_impl.dart';
import 'data/datasources/firestore_activity_log_datasource.dart';
import 'data/repositories/activity_log_repository_impl.dart';
import 'data/datasources/firestore_admin_datasource.dart';
import 'data/repositories/admin_repository_impl.dart';
import 'data/datasources/firestore_assistant_usage_datasource.dart';
import 'data/repositories/assistant_usage_repository_impl.dart';

// Capa de dominio
import 'domain/repositories/i_activity_log_repository.dart';
import 'domain/repositories/i_assistant_usage_repository.dart';
import 'domain/usecases/get_analytics_usecase.dart';
import 'domain/usecases/get_admin_stats_usecase.dart';

// Capa de presentación
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/recipe_provider.dart';
import 'presentation/providers/shopping_provider.dart';
import 'presentation/providers/analytics_provider.dart';
import 'presentation/providers/household_provider.dart';
import 'presentation/providers/assistant_provider.dart';
import 'presentation/providers/admin_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Persistencia offline nativa: el inventario queda disponible sin
  // conexión y las escrituras se encolan hasta reconectar. En Android ya
  // viene activada por defecto, pero se declara explícito para que el
  // comportamiento no dependa de un default de la plataforma.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  // Firebase AI Logic exige App Check. En debug se usa el proveedor debug
  // (requiere registrar el token que imprime logcat en la consola de
  // Firebase); en release, Play Integrity.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );
  await AndroidAlarmManager.initialize();

  runApp(
    MultiProvider(
      providers: [
        // Tema oscuro/claro
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),

        // AuthProvider con inyección de dependencias
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(AuthRepositoryImpl()),
        ),

        // HouseholdProvider — Módulo de Grupos Familiares. Escucha
        // directo authStateChanges (no ChangeNotifierProxyProvider: ver
        // nota de diseño en household_provider.dart) para saber qué hogar
        // activo mostrar apenas resuelve la sesión. Debe registrarse antes
        // que ProductProvider: este último lo lee vía ProxyProvider.
        ChangeNotifierProvider<HouseholdProvider>(
          create: (context) => HouseholdProvider(
            HouseholdRepositoryImpl(FirestoreHouseholdDataSource()),
            context.read<AuthProvider>().authStateChanges,
          ),
        ),

        // IActivityLogRepository — log de auditoría del inventario.
        // Provider simple (no ChangeNotifier: solo
        // envuelve llamadas a Firestore, sin estado propio). Se registra
        // antes que ProductProvider para poder inyectarlo ahí, y también
        // lo leen las pantallas directamente (ver HouseholdScreen) para
        // mostrar el historial de actividad con un StreamBuilder.
        Provider<IActivityLogRepository>(
          create: (_) => ActivityLogRepositoryImpl(
            FirestoreActivityLogDataSource(),
          ),
        ),

        // IAssistantUsageRepository — adopción del asistente culinario.
        // Mismo criterio que IActivityLogRepository:
        // provider simple, se registra antes que AssistantProvider para
        // poder inyectarlo ahí.
        Provider<IAssistantUsageRepository>(
          create: (_) => AssistantUsageRepositoryImpl(
            FirestoreAssistantUsageDataSource(),
          ),
        ),

        // ProductProvider con inyección de dependencias.
        // recibe también IProductHistoryRepository para registrar cada
        // eliminación en el historial, e IActivityLogRepository para el
        // log de actividad del hogar (ver ProductProvider.deleteProduct /
        // saveProduct).
        //
        // ChangeNotifierProxyProvider en vez de ChangeNotifierProvider: el
        // inventario ahora es por-hogar (households/{id}/productos), así
        // que ProductProvider necesita enterarse cada vez que cambia el
        // `activeHouseholdId` de HouseholdProvider (login, logout, creó o
        // se unió a un hogar) para (re)suscribir su stream al hogar
        // correcto — ver ProductProvider.setActiveHousehold.
        ChangeNotifierProxyProvider<HouseholdProvider, ProductProvider>(
          create: (context) => ProductProvider(
            ProductRepositoryImpl(
              FirestoreProductDataSource(),
            ),
            ProductHistoryRepositoryImpl(
              FirestoreProductHistoryDataSource(),
              ShoppingLocalDataSource(), // Opción A: catálogo de precios
            ),
            context.read<IActivityLogRepository>(),
          ),
          update: (_, householdProvider, productProvider) {
            return productProvider!
              ..setActiveHousehold(householdProvider.activeHouseholdId);
          },
        ),

        // RecipeProvider — catálogo de recetas (fuente local, ver
        // RecipeLocalDataSource) + fallback de IA:
        // GeminiAssistantDataSource() propia, independiente de la del
        // AssistantProvider de más abajo (esta no mantiene conversación).
        ChangeNotifierProvider<RecipeProvider>(
          create: (_) => RecipeProvider(
            RecipeRepositoryImpl(
              RecipeLocalDataSource(),
              GeminiAssistantDataSource(),
            ),
          ),
        ),

        // ShoppingProvider — canastas por nivel de presupuesto (fuente
        // local) cruzadas dinámicamente contra el inventario real.
        ChangeNotifierProvider<ShoppingProvider>(
          create: (_) => ShoppingProvider(
            ShoppingRepositoryImpl(ShoppingLocalDataSource()),
          ),
        ),

        // AnalyticsProvider — KPIs calculados a partir del historial de
        // productos resueltos del hogar activo (ver AnalyticsRepositoryImpl /
        // GetAnalyticsUseCase). ChangeNotifierProxyProvider igual que
        // ProductProvider: el resumen es por-hogar, así que necesita
        // enterarse cada vez que cambia `activeHouseholdId`.
        ChangeNotifierProxyProvider<HouseholdProvider, AnalyticsProvider>(
          create: (_) => AnalyticsProvider(
            GetAnalyticsUseCase(
              AnalyticsRepositoryImpl(FirestoreProductHistoryDataSource()),
            ),
          ),
          update: (_, householdProvider, analyticsProvider) {
            return analyticsProvider!
              ..setActiveHousehold(householdProvider.activeHouseholdId);
          },
        ),

        // AssistantProvider — asistente culinario (Gemini vía firebase_ai).
        ChangeNotifierProvider<AssistantProvider>(
          create: (context) => AssistantProvider(
            AssistantRepositoryImpl(GeminiAssistantDataSource()),
            context.read<ProductProvider>(),
            context.read<IAssistantUsageRepository>(),
          ),
        ),

        // AdminProvider — Panel Administrativo Global.
        // `lazy` por defecto en Provider: no consulta Firestore hasta que
        // AdminDashboardScreen lo lea (y esa pantalla ya filtró por
        // kAdminUid antes de hacerlo) — ningún costo para el resto de
        // usuarios.
        ChangeNotifierProvider<AdminProvider>(
          create: (_) => AdminProvider(
            GetAdminStatsUseCase(
              AdminRepositoryImpl(FirestoreAdminDataSource()),
            ),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Frescorden',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      // Rutas nombradas (ver lib/routes.dart): cada Navigator.push de la
      // app pasa un RouteSettings.name explícito — el observer de Analytics
      // ya puede reportar qué pantalla se abrió en vez de "desconocida".
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      // La decisión inicial (Onboarding / Login / Inicio)
      // ya no vive acá — SplashScreen la resuelve (esperando el primer
      // estado de AuthProvider.authStateChanges + la bandera de
      // SharedPreferences) mientras anima el logo de marca. login_screen.dart
      // ya navega explícitamente a InicioScreen tras un login exitoso, así
      // que no depender de este StreamBuilder para ese caso no es una
      // regresión.
      home: const SplashScreen(),
    );
  }
}
