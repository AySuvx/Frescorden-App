// test/auth_repository_impl_test.dart
//
// BDD de AuthRepositoryImpl (lib/data/repositories/auth_repository_impl.dart)
// con FirebaseAuth/FirebaseFirestore mockeados vía mocktail (inyectados por
// constructor, ver AuthRepositoryImpl({auth, db})). Cubre lo mapeable sin
// tocar plataforma nativa: signInWithEmail, registerWithEmail,
// sendPasswordReset, currentUser, authStateChanges y deleteAccount.
//
// signInWithGoogle/signOut NO se cubren acá: dependen de
// GoogleSignIn.instance (singleton hardcodeado, no inyectable desde este
// repositorio) que dispara canales de plataforma reales en el entorno de
// test.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frescorden/core/errors/auth_exceptions.dart';
import 'package:frescorden/data/repositories/auth_repository_impl.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class FakeFirebaseAuthException extends Fake implements FirebaseAuthException {
  FakeFirebaseAuthException(this.code, [this.message]);

  @override
  final String code;

  @override
  final String? message;
}

void main() {
  late MockFirebaseAuth auth;
  late MockFirebaseFirestore db;
  late AuthRepositoryImpl repository;

  setUp(() {
    auth = MockFirebaseAuth();
    db = MockFirebaseFirestore();
    repository = AuthRepositoryImpl(auth: auth, db: db);
  });

  group('Historia de Usuario: Como usuario, quiero iniciar sesión con '
      'correo y contraseña', () {
    test(
      'Escenario: con correo verificado, el inicio de sesión se completa '
      'sin lanzar excepciones',
      () async {
        final credential = MockUserCredential();
        final user = MockUser();
        when(() => user.emailVerified).thenReturn(true);
        when(() => credential.user).thenReturn(user);
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);

        await repository.signInWithEmail('a@a.com', '123456');

        verifyNever(() => auth.signOut());
      },
    );

    test(
      'Escenario: con correo NO verificado, cierra la sesión y lanza '
      'UnverifiedEmailException',
      () async {
        final credential = MockUserCredential();
        final user = MockUser();
        when(() => user.emailVerified).thenReturn(false);
        when(() => credential.user).thenReturn(user);
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);
        when(() => auth.signOut()).thenAnswer((_) async {});

        await expectLater(
          repository.signInWithEmail('a@a.com', '123456'),
          throwsA(isA<UnverifiedEmailException>()),
        );
        verify(() => auth.signOut()).called(1);
      },
    );

    test(
      'Escenario: credenciales inválidas de Firebase se traducen a '
      'InvalidCredentialsException',
      () async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException('wrong-password'));

        await expectLater(
          repository.signInWithEmail('a@a.com', 'mala'),
          throwsA(isA<InvalidCredentialsException>()),
        );
      },
    );

    test(
      'Escenario: usuario inexistente se traduce a UserNotFoundException',
      () async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException('user-not-found'));

        await expectLater(
          repository.signInWithEmail('nadie@a.com', '123456'),
          throwsA(isA<UserNotFoundException>()),
        );
      },
    );

    test(
      'Escenario: un código sin mapeo específico conserva el mensaje '
      'original de Firebase en AuthOperationException',
      () async {
        when(
          () => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException('network-request-failed', 'Sin conexión'));

        await expectLater(
          repository.signInWithEmail('a@a.com', '123456'),
          throwsA(
            isA<AuthOperationException>().having(
              (e) => e.message,
              'message',
              'Sin conexión',
            ),
          ),
        );
      },
    );
  });

  group('Historia de Usuario: Como usuario nuevo, quiero registrarme con '
      'correo y contraseña', () {
    test(
      'Escenario: el registro exitoso envía el correo de verificación y '
      'cierra la sesión',
      () async {
        final credential = MockUserCredential();
        final user = MockUser();
        when(() => user.sendEmailVerification()).thenAnswer((_) async {});
        when(() => credential.user).thenReturn(user);
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);
        when(() => auth.signOut()).thenAnswer((_) async {});

        await repository.registerWithEmail('nuevo@a.com', '123456');

        verify(() => user.sendEmailVerification()).called(1);
        verify(() => auth.signOut()).called(1);
      },
    );

    test(
      'Escenario: correo ya en uso se traduce a EmailAlreadyInUseException',
      () async {
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException('email-already-in-use'));

        await expectLater(
          repository.registerWithEmail('repetido@a.com', '123456'),
          throwsA(isA<EmailAlreadyInUseException>()),
        );
      },
    );

    test(
      'Escenario: contraseña débil se traduce a WeakPasswordException',
      () async {
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException('weak-password'));

        await expectLater(
          repository.registerWithEmail('a@a.com', '123'),
          throwsA(isA<WeakPasswordException>()),
        );
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero recuperar mi cuenta si '
      'olvido la contraseña', () {
    test(
      'Escenario: el envío del correo de recuperación se completa sin '
      'lanzar excepciones',
      () async {
        when(
          () => auth.sendPasswordResetEmail(email: any(named: 'email')),
        ).thenAnswer((_) async {});

        await expectLater(
          repository.sendPasswordReset('a@a.com'),
          completes,
        );
      },
    );

    test(
      'Escenario: un correo inválido se traduce a InvalidCredentialsException',
      () async {
        when(
          () => auth.sendPasswordResetEmail(email: any(named: 'email')),
        ).thenThrow(FakeFirebaseAuthException('invalid-email'));

        await expectLater(
          repository.sendPasswordReset('no-es-un-correo'),
          throwsA(isA<InvalidCredentialsException>()),
        );
      },
    );
  });

  group('Historia de Usuario: Como app, quiero saber quién es el usuario '
      'actual y reaccionar a cambios de sesión', () {
    test(
      'Escenario: sin usuario autenticado, currentUser es null',
      () {
        when(() => auth.currentUser).thenReturn(null);

        expect(repository.currentUser, isNull);
      },
    );

    test(
      'Escenario: con usuario autenticado, currentUser mapea uid/email/'
      'emailVerified',
      () {
        final user = MockUser();
        when(() => user.uid).thenReturn('uid-1');
        when(() => user.email).thenReturn('a@a.com');
        when(() => user.emailVerified).thenReturn(true);
        when(() => auth.currentUser).thenReturn(user);

        final appUser = repository.currentUser;

        expect(appUser?.uid, 'uid-1');
        expect(appUser?.email, 'a@a.com');
        expect(appUser?.emailVerified, isTrue);
      },
    );

    test(
      'Escenario: authStateChanges mapea cada emisión de FirebaseAuth a '
      'AppUser',
      () async {
        final user = MockUser();
        when(() => user.uid).thenReturn('uid-1');
        when(() => user.email).thenReturn('a@a.com');
        when(() => user.emailVerified).thenReturn(true);
        when(() => auth.authStateChanges()).thenAnswer(
          (_) => Stream.fromIterable([null, user]),
        );

        final emisiones = await repository.authStateChanges().toList();

        expect(emisiones, [null, isA<Object>()]);
        expect(emisiones.last?.uid, 'uid-1');
      },
    );
  });

  group('Historia de Usuario: Como usuario, quiero poder eliminar mi '
      'cuenta', () {
    test(
      'Escenario: sin sesión activa, no hace nada',
      () async {
        when(() => auth.currentUser).thenReturn(null);

        await repository.deleteAccount();

        verifyNever(() => db.collection(any()));
      },
    );

    test(
      'Escenario: con sesión activa, borra el documento de Firestore y '
      'luego la cuenta de Firebase',
      () async {
        final user = MockUser();
        final collection = MockCollectionReference();
        final docRef = MockDocumentReference();
        when(() => user.uid).thenReturn('uid-1');
        when(() => user.delete()).thenAnswer((_) async {});
        when(() => auth.currentUser).thenReturn(user);
        when(() => db.collection('usuarios')).thenReturn(collection);
        when(() => collection.doc('uid-1')).thenReturn(docRef);
        when(() => docRef.delete()).thenAnswer((_) async {});

        await repository.deleteAccount();

        verify(() => docRef.delete()).called(1);
        verify(() => user.delete()).called(1);
      },
    );
  });
}
