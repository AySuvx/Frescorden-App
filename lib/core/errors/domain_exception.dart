// Excepciones de reglas de negocio del dominio — independientes de la causa
// técnica (Firestore, red, etc.). Los Use Cases las lanzan cuando una
// entrada viola una regla (ver Sección 23 de la guía de arquitectura:
// "Si la cantidad es menor o igual a cero → no permitir registro").

abstract class DomainException implements Exception {
  final String message;
  const DomainException(this.message);

  @override
  String toString() => message;
}

/// Entrada que no cumple una regla de negocio (p. ej. cantidad <= 0).
class ValidationException extends DomainException {
  const ValidationException(super.message);
}
