import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';

/// Indicador visual del wizard de registro (propuesta 009): 3 círculos
/// numerados + líneas conectoras + labels. Actual = círculo lleno de marca
/// con el número; completado = círculo tenue con check; pendiente = outline
/// gris. SOLO visual — la navegación es por flecha/botón, el stepper no
/// responde a taps.
class RegisterStepper extends StatelessWidget {
  const RegisterStepper({super.key});

  static const int _steps = 3;
  static const double _circleSize = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.registerStepDataLabel,
      l10n.registerStepAccountLabel,
      l10n.registerStepReviewLabel,
    ];
    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) => p.currentStep != c.currentStep,
      builder: (context, state) {
        return Semantics(
          // Anuncia el progreso al cambiar de paso (accesibilidad).
          label: l10n.registerStepProgress(state.currentStep + 1, _steps),
          liveRegion: true,
          // Cada paso ocupa un segmento Expanded: el conector se dibuja en
          // dos mitades (derecha del ítem i + izquierda del i+1), ambas del
          // tono del tramo — así toca el borde del círculo y el label queda
          // centrado bajo su círculo sin trucos de overflow.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _steps; i++)
                Expanded(
                  child: _StepSegment(
                    index: i,
                    label: labels[i],
                    state: _StepTone.from(i, state.currentStep),
                    isFirst: i == 0,
                    isLast: i == _steps - 1,
                    leftConnectorDone: i - 1 < state.currentStep,
                    rightConnectorDone: i < state.currentStep,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Estado visual de un paso del stepper.
enum _StepTone {
  completed,
  current,
  pending;

  static _StepTone from(int index, int currentStep) {
    if (index < currentStep) return _StepTone.completed;
    if (index == currentStep) return _StepTone.current;
    return _StepTone.pending;
  }
}

/// Un segmento del stepper: [media línea + círculo + media línea] arriba y
/// el label centrado debajo. Como el segmento es Expanded, el label se
/// centra bajo el círculo automáticamente.
class _StepSegment extends StatelessWidget {
  const _StepSegment({
    required this.index,
    required this.label,
    required this.state,
    required this.isFirst,
    required this.isLast,
    required this.leftConnectorDone,
    required this.rightConnectorDone,
  });

  final int index;
  final String label;
  final _StepTone state;
  final bool isFirst;
  final bool isLast;

  /// Tono de cada mitad del conector: llena cuando el tramo ya quedó atrás.
  final bool leftConnectorDone;
  final bool rightConnectorDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isCompleted = state == _StepTone.completed;
    final isCurrent = state == _StepTone.current;

    final Color? fill;
    final Color contentColor;
    final BoxBorder? border;
    switch (state) {
      case _StepTone.current:
        fill = colors.primary;
        contentColor = colors.onPrimary;
        border = null;
      case _StepTone.completed:
        fill = colors.primary.withValues(alpha: 0.2);
        contentColor = colors.primary;
        border = null;
      case _StepTone.pending:
        fill = null;
        contentColor = colors.onSurface.withValues(alpha: 0.65);
        border = Border.all(color: colors.onSurface.withValues(alpha: 0.45));
    }

    // TalkBack: "Paso 1: Datos, completado" — el estado visual (check /
    // número / outline) también se anuncia; `selected` marca el actual.
    final statusLabel = switch (state) {
      _StepTone.completed => l10n.registerStepStatusCompleted,
      _StepTone.current => l10n.registerStepStatusCurrent,
      _StepTone.pending => l10n.registerStepStatusPending,
    };
    return Semantics(
      label: l10n.registerStepItemLabel(index + 1, label, statusLabel),
      selected: isCurrent,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: RegisterStepper._circleSize,
            child: Row(
              children: [
                Expanded(
                  child: isFirst
                      ? const SizedBox.shrink()
                      : _Connector(done: leftConnectorDone),
                ),
                Container(
                  width: RegisterStepper._circleSize,
                  height: RegisterStepper._circleSize,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: border,
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check, size: 18, color: contentColor)
                        : Text(
                            '${index + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: contentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : _Connector(done: rightConnectorDone),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isCurrent
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.65),
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Media línea conectora entre un círculo y el borde de su segmento.
class _Connector extends StatelessWidget {
  const _Connector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 2,
      color: done
          ? colors.primary.withValues(alpha: 0.6)
          : colors.onSurface.withValues(alpha: 0.25),
    );
  }
}
