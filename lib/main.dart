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
import 'package:firebase_core/firebase_core.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:provider/provider.dart';

import 'theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/inicio_screen.dart';

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

// Capa de dominio
import 'domain/entities/app_user.dart';
import 'domain/usecases/get_analytics_usecase.dart';

// Capa de presentación
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/recipe_provider.dart';
import 'presentation/providers/shopping_provider.dart';
import 'presentation/providers/analytics_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AndroidAlarmManager.initialize();

  runApp(
    MultiProvider(
      providers: [
        // Tema oscuro/claro
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),

        // ProductProvider con inyección de dependencias.
        // recibe también IProductHistoryRepository para registrar
        // cada eliminación en el historial (ver ProductProvider.deleteProduct).
        ChangeNotifierProvider<ProductProvider>(
          create: (_) => ProductProvider(
            ProductRepositoryImpl(
              FirestoreProductDataSource(),
            ),
            ProductHistoryRepositoryImpl(
              FirestoreProductHistoryDataSource(),
              ShoppingLocalDataSource(), // Opción A: catálogo de precios
            ),
          ),
        ),

        // AuthProvider con inyección de dependencias
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(AuthRepositoryImpl()),
        ),

        // RecipeProvider — catálogo de recetas (fuente local, ver
        // RecipeLocalDataSource)
        ChangeNotifierProvider<RecipeProvider>(
          create: (_) => RecipeProvider(
            RecipeRepositoryImpl(RecipeLocalDataSource()),
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
        // productos resueltos (ver AnalyticsRepositoryImpl / GetAnalyticsUseCase).
        ChangeNotifierProvider<AnalyticsProvider>(
          create: (_) => AnalyticsProvider(
            GetAnalyticsUseCase(
              AnalyticsRepositoryImpl(FirestoreProductHistoryDataSource()),
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
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
      ),
      themeMode:
          themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: StreamBuilder<AppUser?>(
        stream: context.read<AuthProvider>().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            return const InicioScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
