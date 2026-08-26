import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'inicio_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
      try {
        await _googleSignIn.signOut(); // Asegura elegir cuenta nueva
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const InicioScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error con Google: $e')),
          );
        }
      }
    }

  // Registro / Login con correo y contraseña
    Future<void> submitEmailPassword() async {
      try {
        if (!_isLogin) {
          // Validar los requisitos de la contraseña
          if (_passwordCriteria.values.contains(false)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('La contraseña no cumple con los requisitos.')),
              );
            }
            return;
          }
        }

        if (_isLogin) {
          final userCredential = await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

          // Verificar si el correo está verificado
          if (!userCredential.user!.emailVerified) {
            await _auth.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Por favor, verifica tu correo electrónico para iniciar sesión.')),
              );
            }
            return;
          }
        } else {
          final userCredential = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

          // Enviar correo de verificación
          await userCredential.user!.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Se ha enviado un correo de verificación. Por favor, revisa tu bandeja de entrada.')),
            );
          }

          await _auth.signOut(); // Cerrar sesión después del registro
        }

        if (mounted && _isLogin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const InicioScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Error desconocido')),
          );
        }
      }
    }
    // FIX M2: evaluatePassword() eliminado (código muerto — la lógica vive en el onChanged del campo contraseña)

 Future<void> resetPassword() async {
  try {
    if (_emailController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, ingresa tu correo electrónico.')),
        );
      }
      return;
    }

    await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se ha enviado un correo para restablecer tu contraseña.')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),

              // Logo o título animado
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                child: Text(
                  _isLogin ? 'Bienvenido A Fresc(o)rden' : 'Crea tu Cuenta',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
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
                  fillColor: Colors.white,
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
                      'Una letra mayúscula': password.contains(RegExp(r'[A-Z]')),
                      'Un número': password.contains(RegExp(r'[0-9]')),
                      'Un carácter especial': password.contains(RegExp(r'[!@#\$&*~]')),
                    };
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              // Password Criteria
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isLogin ? 0 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _passwordCriteria.entries.map((entry) {
                    return Row(
                      children: [
                        Icon(
                          entry.value ? Icons.check_circle : Icons.cancel,
                          color: entry.value ? Colors.green : Colors.red,
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
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Botón de login/registro
              ElevatedButton(
                onPressed: submitEmailPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isLogin ? 'Iniciar Sesión' : 'Registrarse',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
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
                  style: const TextStyle(color: Colors.green),
                ),
              ),

              const Divider(height: 32),

              // Google Sign-in
              ElevatedButton.icon(
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Ingresar con Google'),
                onPressed: signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}