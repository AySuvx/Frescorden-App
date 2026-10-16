// Acceso restringido al UID declarado en kAdminUid (config/app_config.dart)
// — cualquier otro usuario autenticado ve un aviso de acceso denegado, sin
// llegar a consultar AdminProvider (y por lo tanto sin disparar ninguna
// lectura a Firestore que igual sería rechazada por firestore.rules).
//
// Métricas mostradas: total de usuarios, total de hogares y estadísticas
// agregadas de uso (miembros totales/promedio por hogar, hogares con
// código de invitación vencido) — ver AdminRepositoryImpl.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/admin_stats.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/admin_report_generator.dart';
import '../widgets/common/animated_counter.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administrativo'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Generar reporte PDF',
              onPressed: () => _generateReport(context),
            ),
        ],
      ),
      body: isAdmin ? const _AdminStatsView() : const _AccessDenied(),
    );
  }

  /// Arma el PDF del lado del celular (sin servidor, ver
  /// AdminReportGenerator) a partir de las métricas que ya están cargadas
  /// en pantalla, y abre el selector nativo de Android para que el
  /// administrador elija dónde guardarlo o a quién compartirlo.
  Future<void> _generateReport(BuildContext context) async {
    final stats = context.read<AdminProvider>().stats;
    final bytes = await AdminReportGenerator.generate(stats);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'frescorden-reporte-${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Acceso denegado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Este panel está reservado para el administrador de la app.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStatsView extends StatefulWidget {
  const _AdminStatsView();

  @override
  State<_AdminStatsView> createState() => _AdminStatsViewState();
}

class _AdminStatsViewState extends State<_AdminStatsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final AdminStats stats = provider.stats;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'No se pudieron cargar las métricas globales.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.read<AdminProvider>().loadStats(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<AdminProvider>().loadStats(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            'Usuarios',
            'Altas y actividad reciente',
          ),
          _buildStatCard(
            icon: Icons.people_alt,
            color: Colors.blue,
            label: 'Usuarios registrados',
            value: '${stats.totalUsers}',
            numericValue: stats.totalUsers,
            subtitle: '+${stats.newUsersLast7Days} en los últimos 7 días',
          ),
          _buildStatCard(
            icon: Icons.bolt,
            color: Colors.amber.shade800,
            label: 'Usuarios activos',
            value: '${stats.activeUsersLast7Days}',
            numericValue: stats.activeUsersLast7Days,
            subtitle:
                'Últimos 7 días — ${stats.activeUsersLast30Days} en 30 días',
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(
            'Hogares',
            'Estructura del Módulo de Grupos Familiares',
          ),
          _buildStatCard(
            icon: Icons.home_filled,
            color: Colors.green,
            label: 'Hogares creados',
            value: '${stats.totalHouseholds}',
            numericValue: stats.totalHouseholds,
          ),
          _buildStatCard(
            icon: Icons.groups,
            color: Colors.teal,
            label: 'Miembros totales en hogares',
            value: '${stats.totalHouseholdMembers}',
            numericValue: stats.totalHouseholdMembers,
            subtitle:
                'Promedio: ${stats.averageMembersPerHousehold.toStringAsFixed(1)} por hogar',
          ),
          _buildStatCard(
            icon: Icons.timer_off,
            color: Colors.deepOrange,
            label: 'Hogares con código vencido',
            value: '${stats.householdsWithExpiredInviteCode}',
            numericValue: stats.householdsWithExpiredInviteCode,
            subtitle: 'Código de invitación sin renovar',
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(
            'Impacto real (últimos 30 días)',
            'Aprovechamiento agregado de TODOS los hogares',
          ),
          _buildStatCard(
            icon: Icons.eco,
            color: Colors.green,
            label: 'Aprovechamiento global',
            value: stats.globalWasteReductionPercentageLast30Days == null
                ? 'Sin datos'
                : '${stats.globalWasteReductionPercentageLast30Days!.toStringAsFixed(0)}%',
            numericValue: stats.globalWasteReductionPercentageLast30Days,
            numericSuffix: '%',
            subtitle:
                '${stats.globalConsumedLast30Days} consumidos vs. '
                '${stats.globalDiscardedLast30Days} desperdiciados',
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(
            'Asistente Culinario',
            'Adopción de la función IA (últimos 30 días)',
          ),
          _buildStatCard(
            icon: Icons.smart_toy,
            color: Colors.purple,
            label: 'Consultas exitosas',
            value: '${stats.assistantQueriesLast30Days}',
            numericValue: stats.assistantQueriesLast30Days,
            subtitle:
                '${stats.householdsUsingAssistantLast30Days} hogares distintos lo usaron',
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(
            'Usabilidad (SUS + NPS)',
            '${stats.usabilitySurveyResponses} '
                '${stats.usabilitySurveyResponses == 1 ? "respuesta" : "respuestas"} '
                'recibidas',
          ),
          _buildStatCard(
            icon: Icons.fact_check,
            color: Colors.indigo,
            label: 'Puntaje SUS promedio',
            value: stats.averageSusScore == null
                ? 'Sin datos'
                : stats.averageSusScore!.toStringAsFixed(1),
            numericValue: stats.averageSusScore,
            subtitle: stats.averageSusScore == null
                ? 'Nadie ha respondido la encuesta todavía'
                : '0-100 · arriba de 68 se considera por encima del '
                    'promedio (escala académica estándar)',
          ),
          _buildStatCard(
            icon: Icons.thumb_up_alt_outlined,
            color: Colors.pink,
            label: 'Net Promoter Score (NPS)',
            value: stats.netPromoterScore == null
                ? 'Sin datos'
                : stats.netPromoterScore!.toStringAsFixed(0),
            numericValue: stats.netPromoterScore,
            subtitle: stats.netPromoterScore == null
                ? 'Nadie ha respondido la encuesta todavía'
                : '-100 a 100 · % promotores menos % detractores',
          ),
        ]
            .animate(interval: 60.ms)
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? subtitle,
    // Igual criterio que AnalyticsScreen._buildKpiCard: si se da, el valor
    // se anima contando desde 0 — solo para KPIs genuinamente numéricos.
    num? numericValue,
    String numericSuffix = '',
  }) {
    const valueStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 26,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  numericValue == null
                      ? Text(value, style: valueStyle)
                      : AnimatedCounter(
                          value: numericValue,
                          suffix: numericSuffix,
                          style: valueStyle,
                        ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
