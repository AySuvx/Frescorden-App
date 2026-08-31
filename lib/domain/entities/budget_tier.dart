// lib/domain/entities/budget_tier.dart
//
// FASE 2 (Fresc-O-rden) — Módulo de Compras Inteligentes:
// Enum de dominio con los niveles de presupuesto para la canasta básica
// familiar. Reemplaza los 3 títulos de texto hardcodeados
// ("Lista básica (Presupuesto: $50,000 COP)", etc.) que antes vivían
// directamente en ShoppingListScreen.
//
// `budgetCap` es el techo en COP contra el cual ShoppingProvider compara
// el costo total estimado de la canasta (suma de ShoppingItem.estimatedPrice).

enum BudgetTier {
  basica,
  familiar,
  saludable;

  String get label {
    switch (this) {
      case BudgetTier.basica:
        return 'Lista básica';
      case BudgetTier.familiar:
        return 'Lista familiar';
      case BudgetTier.saludable:
        return 'Lista saludable';
    }
  }

  /// Techo de presupuesto en COP para este nivel. Mismos valores que las
  /// 3 canastas fijas del mock original.
  int get budgetCap {
    switch (this) {
      case BudgetTier.basica:
        return 50000;
      case BudgetTier.familiar:
        return 100000;
      case BudgetTier.saludable:
        return 80000;
    }
  }

  static BudgetTier fromName(String? name) {
    return BudgetTier.values.firstWhere(
      (t) => t.name == name,
      orElse: () => BudgetTier.basica,
    );
  }
}
