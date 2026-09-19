// lib/domain/entities/product_freshness.dart
//
// Regla de negocio: clasificación del estado de vencimiento de un producto.
// Vivía en presentation/widgets/common/status_badge.dart — se traslada aquí
// porque es una decisión de dominio (qué cuenta como "por vencer"), no un
// detalle de presentación; status_badge.dart pasa a solo consumirla.

enum ProductFreshness {
  fresh,
  expiringSoon,
  expired;

  /// Deriva el estado a partir de los días restantes para el vencimiento.
  /// Mismo umbral que usaba el código anterior (<=3 días = "por vencer").
  static ProductFreshness fromDaysRemaining(int daysRemaining) {
    if (daysRemaining < 0) return ProductFreshness.expired;
    if (daysRemaining <= 3) return ProductFreshness.expiringSoon;
    return ProductFreshness.fresh;
  }
}
