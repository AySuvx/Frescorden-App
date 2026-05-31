// lib/main.dart
//
// FASE 2 — Clean Architecture:
// Se reemplaza el ChangeNotifierProvider único por MultiProvider y se
// registra ProductProvider con su cadena de dependencias inyectadas:
//
//   ProductProvider
//     └─ ProductRepositoryImpl
//          └─ FirestoreProductDataSource
//               └─ FirebaseFirestore.instance (externo)
//
// Ninguna pantalla instancia estas clases directamente; las obtienen a
// través de context.read<ProductProvider>() / context.watch<ProductProvider>().

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:provider/provider.dart';

import 'theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/inicio_screen.dart';

// Capa de datos (instanciada aquí, no en las pantallas)
import 'data/datasources/firestore_product_datasource.dart';
import 'data/repositories/product_repository_impl.dart';

// Capa de presentación
import 'presentation/providers/product_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AndroidAlarmManager.initialize();

  runApp(
    MultiProvider(
      providers: [
        // Tema oscuro/claro — sin cambios respecto a Fase 1
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),

        // ProductProvider con inyección de dependencias
        ChangeNotifierProvider<ProductProvider>(
          create: (_) => ProductProvider(
            ProductRepositoryImpl(
              FirestoreProductDataSource(),
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
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
