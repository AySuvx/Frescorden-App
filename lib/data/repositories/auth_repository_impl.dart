// Implementación concreta de IAuthRepository usando FirebaseAuth y
// GoogleSignIn:
//  - signInWithEmail exige correo verificado (cierra la sesión si no lo está).
//  - registerWithEmail envía el correo de verificación y cierra la sesión.
//  - signInWithGoogle cierra la sesión de Google previa antes de elegir cuenta.
//  - deleteAccount borra primero el documento Firestore del usuario.
//
// google_sign_in v7: API rediseñada como singleton (`GoogleSignIn.instance`,
// ya no `GoogleSignIn()`), separa autenticación (idToken) de autorización
// (scopes/accessToken) — `GoogleSignInAuthentication` ya solo expone
// `idToken`. `signIn()` se reemplaza por `authenticate()`, que lanza
// `GoogleSignInException` en vez de devolver `null` al cancelar.
//
// Las excepciones de Firebase (FirebaseAuthException) se capturan acá y se
// traducen a subtipos de DomainException (ver
// lib/core/errors/auth_exceptions.dart) antes de propagarse — Presentation
// (login_screen.dart) ya no necesita importar firebase_auth (ADR-005).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors/auth_exceptions.dart';
import '../../core/errors/domain_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _db;
  bool _googleSignInReady = false;

  AuthRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  Future<void> _ensureGoogleSignInReady() async {
    if (_googleSignInReady) return;
    await _googleSignIn.initialize();
    _googleSignInReady = true;
  }

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      emailVerified: user.emailVerified,
    );
  }

  /// Traduce un FirebaseAuthException al subtipo de DomainException que
  /// mejor lo describe (ver lib/core/errors/auth_exceptions.dart). Los
  /// códigos sin mapeo específico conservan el mensaje original de
  /// Firebase en vez de uno genérico.
  DomainException _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return const InvalidCredentialsException();
      case 'user-not-found':
        return const UserNotFoundException();
      case 'email-already-in-use':
        return const EmailAlreadyInUseException();
      case 'weak-password':
        return const WeakPasswordException();
      default:
        return AuthOperationException(
          e.message ?? 'Error de autenticación.',
        );
    }
  }

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        throw const UnverifiedEmailException();
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user!.sendEmailVerification();
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    await _ensureGoogleSignInReady();
    await _googleSignIn.signOut(); // Asegura elegir cuenta nueva

    try {
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return; // Usuario canceló
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _ensureGoogleSignInReady();
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
