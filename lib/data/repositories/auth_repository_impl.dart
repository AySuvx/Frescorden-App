// lib/data/repositories/auth_repository_impl.dart
//
// Implementación concreta de IAuthRepository usando FirebaseAuth y
// GoogleSignIn. Replica 1:1 el comportamiento que antes vivía embebido en
// login_screen.dart y settings_screen.dart:
//  - signInWithEmail exige correo verificado (cierra la sesión si no lo está).
//  - registerWithEmail envía el correo de verificación y cierra la sesión.
//  - signInWithGoogle cierra la sesión de Google previa antes de elegir cuenta.
//  - deleteAccount borra primero el documento Firestore del usuario.
//
// Las excepciones de Firebase (FirebaseAuthException) se dejan propagar tal
// cual para que la presentación conserve los mismos mensajes de error.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _db;

  AuthRepositoryImpl({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _db = db ?? FirebaseFirestore.instance;

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (!userCredential.user!.emailVerified) {
      await _auth.signOut();
      throw const AuthException(
        'Por favor, verifica tu correo electrónico para iniciar sesión.',
      );
    }
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await userCredential.user!.sendEmailVerification();
    await _auth.signOut();
  }

  @override
  Future<void> signInWithGoogle() async {
    await _googleSignIn.signOut(); // Asegura elegir cuenta nueva
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // Usuario canceló el selector

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('usuarios').doc(user.uid).delete();
    await user.delete();
  }
}
