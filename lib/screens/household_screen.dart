// lib/screens/household_screen.dart
//
// Módulo de Grupos Familiares (Household) — pantalla "Mi Hogar":
//  a) Nombre del hogar y lista de miembros (email si se conoce, uid si no
//     — ver Household.memberEmails).
//  b) Código de invitación de 6 caracteres: copiar y renovar si expiró.
//  c) "Unirse a un Hogar": campo para ingresar el código de otra persona.
//
// 100% reactiva: context.watch<HouseholdProvider>() — si el hogar cambia
// (alguien más se une, el código se rota desde otro dispositivo, etc.) la
// pantalla se actualiza sola, sin recargar nada a mano.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/entities/activity_log_entry.dart';
import '../domain/entities/household.dart';
import '../domain/repositories/i_activity_log_repository.dart';
import '../domain/repositories/i_household_repository.dart';
import '../presentation/providers/household_provider.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _joinCodeController = TextEditingController();
  bool _isJoining = false;
  bool _isRegeneratingCode = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Extrae el mensaje de una [HouseholdException] si aplica; para
  /// cualquier otro error deja un mensaje genérico (mismo criterio que
  /// AddProductScreen._guardarProducto: no exponer excepciones crudas).
  String _messageFor(Object error, String fallback) {
    return error is HouseholdException ? error.message : fallback;
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showSnack('Código copiado: $code');
  }

  Future<void> _regenerateCode() async {
    setState(() => _isRegeneratingCode = true);
    try {
      final code = await context.read<HouseholdProvider>().generateNewInviteCode();
      _showSnack('Código nuevo generado: $code');
    } catch (e) {
      _showSnack(_messageFor(e, 'No se pudo generar un código nuevo. Intenta de nuevo.'));
    } finally {
      if (mounted) setState(() => _isRegeneratingCode = false);
    }
  }

  Future<void> _confirmRemoveMember(String memberUid, String memberLabel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expulsar miembro'),
        content: Text('¿Quitar a "$memberLabel" del hogar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Expulsar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await context.read<HouseholdProvider>().removeMember(memberUid);
      _showSnack('Miembro expulsado.');
    } catch (e) {
      _showSnack(_messageFor(e, 'No se pudo expulsar al miembro.'));
    }
  }

  Future<void> _confirmLeaveHousehold() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir del hogar'),
        content: const Text(
          '¿Salir de este hogar? Dejarás de ver su inventario compartido; '
          'se te asignará uno personal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await context.read<HouseholdProvider>().leaveHousehold();
      _showSnack('Saliste del hogar.');
    } catch (e) {
      _showSnack(_messageFor(e, 'No se pudo salir del hogar.'));
    }
  }

  Future<void> _joinHousehold() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showSnack('El código debe tener 6 caracteres.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isJoining = true);
    try {
      await context.read<HouseholdProvider>().joinHousehold(code);
      _joinCodeController.clear();
      _showSnack('Te uniste al hogar correctamente.');
    } catch (e) {
      _showSnack(
        _messageFor(e, 'No se pudo unir al hogar. Verifica el código e intenta de nuevo.'),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HouseholdProvider>();
    final household = provider.household;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Hogar'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (household != null) ...[
              _buildHouseholdInfo(household, provider),
              const SizedBox(height: 20),
              _buildInviteCodeSection(household),
              if (provider.currentUid != household.createdBy) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmLeaveHousehold,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Salir del Hogar',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _buildActivityLogSection(household.id),
              const SizedBox(height: 24),
            ] else if (provider.isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no tienes un hogar activo. Se creará uno automáticamente, '
                  'o puedes unirte al de otra persona con su código.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Divider(),
            const SizedBox(height: 16),
            _buildJoinSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdInfo(Household household, HouseholdProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.home, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                household.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${household.members.length} '
          '${household.members.length == 1 ? 'miembro' : 'miembros'}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final uid in household.members)
                _buildMemberTile(household, provider, uid),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(
    Household household,
    HouseholdProvider provider,
    String uid,
  ) {
    final isYou = uid == provider.currentUid;
    final isAdmin = uid == household.createdBy;
    final iAmAdmin = provider.currentUid == household.createdBy;
    // Fallback al uid si todavía no se conoce el email (p. ej. hogares
    // creados antes de que memberEmails existiera) — mejor mostrar algo
    // que ocultar al miembro.
    final label = household.memberEmails[uid] ?? uid;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.shade100,
        child: Icon(Icons.person, color: Colors.green.shade800),
      ),
      title: Text(label, overflow: TextOverflow.ellipsis),
      subtitle: isAdmin ? const Text('Administrador') : null,
      trailing: isYou
          ? const Chip(label: Text('Tú'))
          : (iAmAdmin
              ? IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.red),
                  tooltip: 'Expulsar',
                  onPressed: () => _confirmRemoveMember(uid, label),
                )
              : null),
    );
  }

  Widget _buildInviteCodeSection(Household household) {
    final expired = household.isInviteCodeExpired;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Código de invitación',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              expired
                  ? 'Este código ya expiró — genera uno nuevo para invitar a alguien.'
                  : 'Válido hasta las ${_formatTime(household.codeExpiresAt)}.',
              style: TextStyle(
                fontSize: 12,
                color: expired ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: expired ? Colors.red.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      household.inviteCode,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: expired ? Colors.red : Colors.black87,
                        decoration: expired ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copiar código',
                  onPressed: expired ? null : () => _copyCode(household.inviteCode),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isRegeneratingCode ? null : _regenerateCode,
                icon: _isRegeneratingCode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(expired ? 'Generar código nuevo' : 'Renovar código'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: expired ? Colors.red : Colors.green,
                  side: BorderSide(color: expired ? Colors.red : Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogSection(String householdId) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.history, color: Colors.green),
        title: const Text(
          'Historial de Actividad',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          StreamBuilder<List<ActivityLogEntry>>(
            stream: context
                .read<IActivityLogRepository>()
                .watchRecentActivity(householdId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final entries = snapshot.data ?? const [];
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Todavía no hay actividad registrada.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return Column(
                children: [
                  for (final entry in entries) _buildActivityTile(entry),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(ActivityLogEntry entry) {
    final (icon, color) = switch (entry.action) {
      ActivityAction.creado => (Icons.add_circle_outline, Colors.green),
      ActivityAction.editado => (Icons.edit_outlined, Colors.blue),
      ActivityAction.consumido => (Icons.check_circle_outline, Colors.teal),
      ActivityAction.eliminado => (Icons.delete_outline, Colors.red),
    };

    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text('${entry.action.label}: ${entry.productName}'),
      subtitle: Text(entry.userEmail ?? 'Miembro del hogar'),
      trailing: Text(
        _formatLogTime(entry.timestamp),
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );
  }

  String _formatLogTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (sameDay) return '$hh:$mm';
    return '${local.day}/${local.month} $hh:$mm';
  }

  Widget _buildJoinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unirse a un Hogar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ingresa el código de 6 caracteres que te compartió otra persona. '
          'Esto reemplaza tu hogar activo actual.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                enabled: !_isJoining,
                decoration: const InputDecoration(
                  hintText: 'Ej: F83K92',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                ),
                onSubmitted: (_) => _isJoining ? null : _joinHousehold(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _joinHousehold,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Unirse',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
