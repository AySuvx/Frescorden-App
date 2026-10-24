// Encuesta de usabilidad del piloto: System Usability Scale (SUS, Brooke
// 1986) + una pregunta de Net Promoter Score (NPS) aparte. Las 10
// afirmaciones del SUS van SIEMPRE en este orden y sin editar — acortar o
// reordenar el instrumento invalida la posibilidad de comparar el
// resultado contra la escala académica establecida (ver nota en
// UsabilitySurveyResponse.susScore).
//
// Disponible en cualquier momento desde el menú de Inicio, más un aviso
// automático la primera vez que se cumplen las condiciones de
// InicioScreen._showSurveyIfEligible (ver ese archivo).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../providers/usability_survey_provider.dart';
import '../widgets/common/primary_button.dart';

const _susStatements = [
  'Creo que me gustaría usar Fresc(o)rden frecuentemente.',
  'Encontré la app innecesariamente compleja.',
  'Pensé que la app era fácil de usar.',
  'Creo que necesitaría el apoyo de alguien técnico para poder usarla.',
  'Encontré que las funciones de la app estaban bien integradas entre sí.',
  'Pensé que había demasiada inconsistencia en la app.',
  'Me imagino que la mayoría de la gente aprendería a usar esta app muy '
      'rápidamente.',
  'Encontré la app muy difícil/incómoda de usar.',
  'Me sentí muy seguro usando la app.',
  'Necesité aprender muchas cosas antes de poder usar la app.',
];

const _likertLabels = [
  'Totalmente en desacuerdo',
  'En desacuerdo',
  'Neutral',
  'De acuerdo',
  'Totalmente de acuerdo',
];

class UsabilitySurveyScreen extends StatefulWidget {
  const UsabilitySurveyScreen({super.key});

  @override
  State<UsabilitySurveyScreen> createState() => _UsabilitySurveyScreenState();
}

class _UsabilitySurveyScreenState extends State<UsabilitySurveyScreen> {
  final List<int?> _susAnswers = List<int?>.filled(_susStatements.length, null);
  int? _npsScore;

  bool get _isComplete =>
      _susAnswers.every((a) => a != null) && _npsScore != null;

  Future<void> _submit() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || !_isComplete) return;

    final ok = await context.read<UsabilitySurveyProvider>().submit(
          uid: uid,
          susAnswers: _susAnswers.cast<int>(),
          npsScore: _npsScore!,
        );
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias por tus respuestas!')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar la encuesta. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.watch<UsabilitySurveyProvider>().isSubmitting;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Encuesta de Usabilidad')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Tu opinión nos ayuda a mejorar Fresc(o)rden. Responde con qué '
            'tan de acuerdo estás con cada afirmación — no hay respuestas '
            'correctas o incorrectas.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _susStatements.length; i++)
            _LikertQuestion(
              number: i + 1,
              statement: _susStatements[i],
              value: _susAnswers[i],
              onChanged: (v) => setState(() => _susAnswers[i] = v),
            ),
          const Divider(height: AppSpacing.xl),
          Text(
            '¿Qué tan probable es que recomiendes Fresc(o)rden a un '
            'familiar o amigo?',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: List.generate(11, (score) {
              final selected = _npsScore == score;
              return ChoiceChip(
                label: Text('$score'),
                selected: selected,
                selectedColor: colorScheme.primary,
                labelStyle: TextStyle(
                  color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
                onSelected: (_) => setState(() => _npsScore = score),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Enviar',
            isLoading: isSubmitting,
            onPressed: _isComplete ? _submit : null,
          ),
        ],
      ),
    );
  }
}

class _LikertQuestion extends StatelessWidget {
  const _LikertQuestion({
    required this.number,
    required this.statement,
    required this.value,
    required this.onChanged,
  });

  final int number;
  final String statement;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $statement',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(5, (index) {
              final score = index + 1;
              final selected = value == score;
              return Expanded(
                child: Tooltip(
                  message: _likertLabels[index],
                  child: InkWell(
                    onTap: () => onChanged(score),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
