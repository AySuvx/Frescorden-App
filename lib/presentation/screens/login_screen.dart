import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/domain_exception.dart';
import '../../routes.dart';
import '../providers/auth_provider.dart';
import 'inicio_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isPasswordVisible = false;

  Map<String, bool> _passwordCriteria = {
    'Al menos 8 caracteres': false,
    'Una letra mayúscula': false,
    'Un número': false,
    'Un carácter especial': false,
  };

  // Google Sign-In
  Future<void> signInWithGoogle() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.signInWithGoogle();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const InicioScreen(),
            settings: const RouteSettings(name: AppRoutes.inicio),
          ),
        );
      }
    } on DomainException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error con Google: $e')));
      }
    }
  }

  // Registro / Login con correo y contraseña
  Future<void> submitEmailPassword() async {
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // BUG CORREGIDO (hallado en prueba manual en dispositivo): sin esta
    // validación, tocar "Iniciar Sesión" con los campos vacíos llegaba
    // directo a FirebaseAuth.signInWithEmailAndPassword, que en el lado
    // nativo (Android) lanza IllegalArgumentException("Given String is
    // empty or null") — una excepción que no es FirebaseAuthException ni
    // AuthException, así que ninguno de los catch de abajo la atrapaba
    // con un mensaje amigable: el usuario veía el nombre crudo del canal
    // de plataforma ("dev.flutter.pigeon...signInWithEmailAndPassword")
    // en el SnackBar. Cortar acá antes de tocar Firebase evita ese
    // error de plataforma por completo, para login Y registro.
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo y contraseña.')),
      );
      return;
    }

    try {
      if (!_isLogin) {
        // Validar los requisitos de la contraseña
        if (_passwordCriteria.values.contains(false)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('La contraseña no cumple con los requisitos.'),
              ),
            );
          }
          return;
        }
      }

      if (_isLogin) {
        await auth.signInWithEmail(email, password);
      } else {
        await auth.registerWithEmail(email, password);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Se ha enviado un correo de verificación. Por favor, revisa tu bandeja de entrada.',
              ),
            ),
          );
        }
      }

      if (mounted && _isLogin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const InicioScreen(),
            settings: const RouteSettings(name: AppRoutes.inicio),
          ),
        );
      }
    } on DomainException catch (e) {
      // Credenciales inválidas, correo no verificado, etc. — ver
      // lib/core/errors/auth_exceptions.dart (mapeadas en
      // AuthRepositoryImpl a partir de FirebaseAuthException).
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
  // FIX M2: evaluatePassword() eliminado (código muerto — la lógica vive en el onChanged del campo contraseña)

  Future<void> resetPassword() async {
    try {
      if (_emailController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, ingresa tu correo electrónico.'),
            ),
          );
        }
        return;
      }

      await context.read<AuthProvider>().sendPasswordReset(
        _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se ha enviado un correo para restablecer tu contraseña.',
            ),
          ),
        );
      }
    } on DomainException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Banner de marca: "claro" es transparente (texto oscuro,
                // pensado para fondo claro); en modo oscuro ese texto casi
                // negro se perdería contra el scaffold casi negro, así que
                // se usa "mono-blanco" — trae su propio fondo verde sólido
                // horneado en el PNG, no transparente, así que va en su
                // propia tarjeta en vez de flotar directo sobre el fondo.
                if (isDark)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/Frescorden-logo/banners/frescorden-vertical-mono-blanco.png',
                      width: 220,
                    ),
                  )
                else
                  Image.asset(
                    'assets/Frescorden-logo/banners/frescorden-vertical-claro.png',
                    width: 220,
                  ),

                const SizedBox(height: 16),

                // Subtítulo animado
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  child: Text(
                    _isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 30),

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                ),

                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  onChanged: (password) {
                    setState(() {
                      _passwordCriteria = {
                        'Al menos 8 caracteres': password.length >= 8,
                        'Una letra mayúscula': password.contains(
                          RegExp(r'[A-Z]'),
                        ),
                        'Un número': password.contains(RegExp(r'[0-9]')),
                        'Un carácter especial': password.contains(
                          RegExp(r'[!@#\$&*~]'),
                        ),
                      };
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                ),

                const SizedBox(height: 8),

                // Password Criteria
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isLogin ? 0 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _passwordCriteria.entries.map((entry) {
                          return Row(
                            children: [
                              Icon(
                                entry.value ? Icons.check_circle : Icons.cancel,
                                color:
                                    entry.value
                                        ? colorScheme.primary
                                        : colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(entry.key),
                            ],
                          );
                        }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Forgot Password
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: resetPassword,
                      child: Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Botón de login/registro — sin `style` propio: hereda
                // colorScheme.primary/onPrimary de ElevatedButtonThemeData
                // (ver AppTheme), el mismo verde que cualquier otro CTA
                // principal de la app. Antes forzaba fondo blanco mientras
                // el texto heredaba onPrimary (blanco en modo claro) —
                // texto blanco sobre fondo blanco, invisible.
                ElevatedButton(
                  onPressed: submitEmailPassword,
                  child: Text(_isLogin ? 'Iniciar Sesión' : 'Registrarse'),
                ),

                const SizedBox(height: 20),

                // Alternar entre login y registro
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _passwordCriteria = {
                        'Al menos 8 caracteres': false,
                        'Una letra mayúscula': false,
                        'Un número': false,
                        'Un carácter especial': false,
                      };
                      _passwordController.clear();
                    });
                  },
                  child: Text(
                    _isLogin
                        ? '¿No tienes cuenta? Regístrate aquí'
                        : '¿Ya tienes cuenta? Inicia sesión',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),

                const Divider(height: 32),

                // Google Sign-in — fondo blanco fijo a propósito (marca de
                // Google, independiente del tema de la app), pero con
                // foreground explícito: antes lo heredaba de onPrimary
                // (blanco en claro), quedando igual de invisible que el
                // botón de arriba.
                ElevatedButton.icon(
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text('Ingresar con Google'),
                  onPressed: signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
