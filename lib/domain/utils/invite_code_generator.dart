// lib/domain/utils/invite_code_generator.dart
//
// Utilidad pura (sin dependencias de Firestore) para generar el código de
// invitación de un Household: 6 caracteres alfanuméricos en mayúsculas,
// excluyendo los que se confunden fácilmente a simple vista (O/0, I/1, S/5),
// ya que el código se comparte de viva voz o por mensaje corto.

import 'dart:math';

class InviteCodeGenerator {
  InviteCodeGenerator._();

  static const int codeLength = 6;
  static const Duration validity = Duration(hours: 24);

  static const String _alphabet = 'ABCDEFGHJKLMNPQRTUVWXYZ2346789';

  static final Random _random = Random.secure();

  /// Genera un código nuevo de [codeLength] caracteres (ej. 'F83K92').
  static String generate() {
    return List.generate(
      codeLength,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }

  /// Fecha de expiración para un código generado ahora mismo: 24h después.
  static DateTime newExpiryDate() => DateTime.now().add(validity);
}
