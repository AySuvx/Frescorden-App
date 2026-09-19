import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_spacing.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/assistant_provider.dart';
import '../utils/quota_service.dart';
import '../widgets/common/glass_card.dart';

/// Enlaces de Video para Recetas: detecta enlaces
/// Markdown `[texto](url)` en la respuesta del asistente — hoy solo los usa
/// el enlace de YouTube que GeminiAssistantDataSource agrega al final de
/// cada receta, pero funciona para cualquier enlace con ese formato.
final _markdownLinkPattern = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)');

const _suggestions = [
  'Recetas con lo que vence pronto',
  '¿Cómo conservar verduras?',
  '¿Cómo uso la app?',
];

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _connectivity.checkConnectivity().then(_updateOffline);
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_updateOffline);
  }

  void _updateOffline(List<ConnectivityResult> result) {
    if (!mounted) return;
    setState(() => _isOffline = !result.hasConnectivity);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final value = text ?? _controller.text;
    if (value.trim().isEmpty) return;
    context.read<AssistantProvider>().sendMessage(value);
    _controller.clear();
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssistantProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente Culinario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reiniciar conversación',
            onPressed: provider.messages.isEmpty
                ? null
                : () => context.read<AssistantProvider>().clearConversation(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuotaBadge(provider.remainingQueries),
          if (_isOffline) _buildOfflineBanner(),
          Expanded(
            child: provider.messages.isEmpty
                ? _buildEmptyState(provider.isLimitReached)
                : ListView.builder(
                    controller: _scrollController,
                    // Scroll elástico estilo iOS.
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.messages.length + (provider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildBubble(provider.messages[index]);
                    },
                  ),
          ),
          if (provider.isLimitReached)
            _buildLimitReachedCard(provider.timeUntilReset),
          _buildInputBar(provider.isLoading || _isOffline || provider.isLimitReached),
        ],
      ),
    );
  }

  // Barra superior con acabado de cristal — es la
  // única franja que "flota" sobre el chat en esta pantalla, así que es
  // la candidata natural para el efecto glass sin volverlo omnipresente.
  Widget _buildQuotaBadge(int remaining) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: GlassCard(
        borderRadius: AppSpacing.sm,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined, size: 14, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Consultas de hoy: $remaining/${QuotaService.dailyLimit}',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 18, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sin conexión — el chat con el asistente necesita internet.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool limitReached) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 48, color: colorScheme.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pregúntame sobre recetas, conservación de alimentos o cómo usar Frescorden.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (!limitReached) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: _isOffline ? null : () => _send(s),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitReachedCard(Duration timeUntilReset) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        children: [
          Text(
            'Has alcanzado el límite diario. Tus consultas se renuevan en:',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatCountdown(timeUntilReset),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCountdown(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  Widget _buildBubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: _buildMessageContent(message.text, isUser, colorScheme),
      ),
    );
  }

  /// Renderiza [text] como texto plano, salvo los enlaces Markdown
  /// `[texto](url)` (ver _markdownLinkPattern) — esos se muestran
  /// subrayados y abren en la app nativa de YouTube o el navegador al
  /// tocarlos (ver _openLink). No es un renderer de Markdown completo:
  /// solo intercepta enlaces, que es todo lo que el asistente produce hoy.
  Widget _buildMessageContent(String text, bool isUser, ColorScheme colorScheme) {
    final baseStyle = TextStyle(
      color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
    );
    final matches = _markdownLinkPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final linkStyle = baseStyle.copyWith(
      color: isUser ? colorScheme.onPrimary : colorScheme.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final label = match.group(1)!;
      final url = match.group(2)!;
      spans.add(
        TextSpan(
          text: label,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _openLink(url),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  Widget _buildTypingIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Escribiendo...'),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool disabled) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !disabled,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu consulta...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Sin backgroundColor explícito: IconButton.filled ya toma
            // colorScheme.primary/onPrimary por defecto en Material3 — un
            // override fijo aquí solo repetía lo que el tema ya resuelve.
            IconButton.filled(
              onPressed: disabled ? null : () => _send(),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
