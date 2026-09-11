import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/entities/chat_message.dart';
import '../presentation/providers/assistant_provider.dart';
import '../presentation/utils/quota_service.dart';

/// Enlaces de Video para Recetas (Fase 4.5, Módulo 4): detecta enlaces
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

  Widget _buildQuotaBadge(int remaining) {
    return Container(
      width: double.infinity,
      color: Colors.green.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'Consultas de hoy: $remaining/${QuotaService.dailyLimit}',
        style: TextStyle(fontSize: 12, color: Colors.green.shade800),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión — el chat con el asistente necesita internet.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool limitReached) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          const Text(
            'Pregúntame sobre recetas, conservación de alimentos o cómo usar Frescorden.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Text(
            'Has alcanzado el límite diario. Tus consultas se renuevan en:',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green.shade900),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCountdown(timeUntilReset),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.green : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _buildMessageContent(message.text, isUser),
      ),
    );
  }

  /// Renderiza [text] como texto plano, salvo los enlaces Markdown
  /// `[texto](url)` (ver _markdownLinkPattern) — esos se muestran
  /// subrayados y abren en la app nativa de YouTube o el navegador al
  /// tocarlos (ver _openLink). No es un renderer de Markdown completo:
  /// solo intercepta enlaces, que es todo lo que el asistente produce hoy.
  Widget _buildMessageContent(String text, bool isUser) {
    final baseStyle = TextStyle(color: isUser ? Colors.white : Colors.black87);
    final matches = _markdownLinkPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final linkStyle = baseStyle.copyWith(
      color: isUser ? Colors.white : Colors.blue.shade800,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Escribiendo...'),
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
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: disabled ? null : () => _send(),
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
