// Métricas agregadas de toda la app — no de un hogar en particular.
// Calculado por AdminRepositoryImpl a partir de las colecciones raíz
// `usuarios`/`households` y de los collectionGroup `product_history` /
// `assistant_usage` de todos los hogares.
//
// `newUsersLast7Days`/`activeUsers*` dependen de `createdAt`/`lastActiveAt`
// en `usuarios/{uid}` (ver HouseholdProvider.setUid) — cuentas que no
// vuelvan a iniciar sesión no tendrán esos campos y no se contarán como
// activas hasta que lo hagan. Es una limitación esperada, no un error de
// cálculo.

class AdminStats {
  /// Total de cuentas de usuario registradas (colección `usuarios`).
  final int totalUsers;

  /// Cuentas nuevas (primer `createdAt` registrado) en los últimos 7 días.
  final int newUsersLast7Days;

  /// Usuarios con `lastActiveAt` dentro de los últimos 7 / 30 días —
  /// proxy de WAU/MAU (no hay sesión "activa" real, es la última vez que
  /// se resolvió sesión: login o restauración silenciosa al abrir la app).
  final int activeUsersLast7Days;
  final int activeUsersLast30Days;

  /// Total de hogares creados (colección `households`).
  final int totalHouseholds;

  /// Suma de miembros de todos los hogares (un usuario en 2 hogares cuenta
  /// 2 veces — refleja el uso real del inventario compartido).
  final int totalHouseholdMembers;

  /// Cantidad de hogares cuyo código de invitación ya expiró (nadie lo ha
  /// renovado) — señal simple de actividad/mantenimiento del hogar.
  final int householdsWithExpiredInviteCode;

  /// Aprovechamiento GLOBAL (todos los hogares) en el último mes: % de
  /// productos resueltos que se consumieron en vez de desperdiciarse.
  /// `null` si no hay historial en la ventana.
  final double? globalWasteReductionPercentageLast30Days;
  final int globalConsumedLast30Days;
  final int globalDiscardedLast30Days;

  /// Adopción del Asistente Culinario: consultas exitosas y hogares
  /// distintos que lo usaron en los últimos 30 días.
  final int assistantQueriesLast30Days;
  final int householdsUsingAssistantLast30Days;

  /// Encuesta de usabilidad (ver UsabilitySurveyResponse) — cuántas
  /// personas respondieron, su puntaje SUS promedio (0-100, instrumento
  /// académico estándar) y el índice NPS (-100 a 100, fórmula estándar:
  /// % promotores - % detractores, NO un simple promedio). `null` en
  /// ambos si todavía nadie respondió.
  final int usabilitySurveyResponses;
  final double? averageSusScore;
  final double? netPromoterScore;

  /// Distribución de puntajes SUS (0-100) en 5 franjas de 20 puntos —
  /// [0-20), [20-40), [40-60), [60-80), [80-100] — para el histograma del
  /// Panel Administrativo. Lista vacía si nadie ha respondido todavía.
  final List<int> susScoreHistogram;

  /// Desglose NPS por categoría (fórmula estándar: promotor 9-10, pasivo
  /// 7-8, detractor 0-6) — netPromoterScore ya es la resta de porcentajes;
  /// estos tres conteos son para el gráfico de barras del Panel.
  final int npsPromoters;
  final int npsPassives;
  final int npsDetractors;

  /// Promedio (escala Likert 1-5) de cada uno de los 10 ítems del SUS, en
  /// el mismo orden del instrumento — permite identificar qué aspecto de
  /// usabilidad puntúa peor/mejor. Lista vacía si nadie ha respondido.
  final List<double> susItemAverages;

  const AdminStats({
    required this.totalUsers,
    required this.newUsersLast7Days,
    required this.activeUsersLast7Days,
    required this.activeUsersLast30Days,
    required this.totalHouseholds,
    required this.totalHouseholdMembers,
    required this.householdsWithExpiredInviteCode,
    required this.globalWasteReductionPercentageLast30Days,
    required this.globalConsumedLast30Days,
    required this.globalDiscardedLast30Days,
    required this.assistantQueriesLast30Days,
    required this.householdsUsingAssistantLast30Days,
    this.usabilitySurveyResponses = 0,
    this.averageSusScore,
    this.netPromoterScore,
    this.susScoreHistogram = const [],
    this.npsPromoters = 0,
    this.npsPassives = 0,
    this.npsDetractors = 0,
    this.susItemAverages = const [],
  });

  /// Promedio de miembros por hogar. `0` si todavía no hay hogares.
  double get averageMembersPerHousehold =>
      totalHouseholds == 0 ? 0 : totalHouseholdMembers / totalHouseholds;

  factory AdminStats.empty() => const AdminStats(
        totalUsers: 0,
        newUsersLast7Days: 0,
        activeUsersLast7Days: 0,
        activeUsersLast30Days: 0,
        totalHouseholds: 0,
        totalHouseholdMembers: 0,
        householdsWithExpiredInviteCode: 0,
        globalWasteReductionPercentageLast30Days: null,
        globalConsumedLast30Days: 0,
        globalDiscardedLast30Days: 0,
        assistantQueriesLast30Days: 0,
        householdsUsingAssistantLast30Days: 0,
      );
}
