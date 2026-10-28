import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/verify_email_cubit.dart';
import '../cubit/verify_email_state.dart';

const int _kCodeLength = 6;
const double _kCellWidth = 48;
const double _kCellHeight = 56;

/// SOLID (SRP): el campo de código vive aquí — la pantalla solo orquesta
/// (bloc-patterns: sin BlocBuilder de campos inline). Casillas separadas
/// implementadas a mano: un TextField invisible cubre la fila y captura el
/// teclado; las casillas son puro render. `pinput` se descartó porque v7 exige
/// un ancestro `Material` del paquete material_ui (Material desacoplado),
/// incompatible con el Scaffold clásico del proyecto (decisión del usuario).
class VerifyEmailFormFields extends StatefulWidget {
  const VerifyEmailFormFields({
    super.key,
    required this.codeFocus,
    required this.onSubmit,
  });

  final FocusNode codeFocus;
  final VoidCallback onSubmit;

  @override
  State<VerifyEmailFormFields> createState() => _VerifyEmailFormFieldsState();
}

class _VerifyEmailFormFieldsState extends State<VerifyEmailFormFields> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    context.read<VerifyEmailCubit>().codeChanged(value);
    if (value.length == _kCodeLength) widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sync del controller del TextField oculto: si el state pierde el código
    // por algo ajeno al tipeo (resend() lo limpia), el campo debe vaciarse —
    // si no, al teclear reaparecerían los dígitos viejos pegados.
    return BlocListener<VerifyEmailCubit, VerifyEmailState>(
      listenWhen: (p, c) => p.code.value != c.code.value,
      listener: (context, state) {
        if (_controller.text != state.code.value) {
          _controller.text = state.code.value;
        }
      },
      // ListenableBuilder: el borde "activo" de la casilla depende del foco —
      // el FocusNode es ChangeNotifier, BlocBuilder solo ve cambios del state.
      child: ListenableBuilder(
        listenable: widget.codeFocus,
        builder: (context, _) => BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
          buildWhen: (p, c) =>
              p.code != c.code ||
              p.showCodeError != c.showCodeError ||
              p.isInProgress != c.isInProgress,
          builder: (context, state) {
            final code = state.code.value;
            final hasError = state.showCodeError && state.code.isNotValid;
            final isFocused = widget.codeFocus.hasFocus;
            return SizedBox(
              height: _kCellHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Semántica para TalkBack: el grupo se anuncia como "código
                  // de verificación, X de 6" — las casillas solas no dicen nada.
                  Semantics(
                    label: AppLocalizations.of(context)!
                        .verifyEmailCodeSemantics(code.length),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_kCodeLength, (i) {
                          final isActive =
                              isFocused &&
                              i == code.length.clamp(0, _kCodeLength - 1);
                          return Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                            child: _PinCell(
                              digit: i < code.length ? code[i] : '',
                              isActive: isActive,
                              hasError: hasError,
                              theme: theme,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    // TextField invisible: captura teclado/autofill; el texto
                    // transparente no se pinta — las casillas hacen el render.
                    // OJO: el inputDecorationTheme global trae filled+bordes
                    // por estado — hay que anularlos EXPLÍCITAMENTE o pinta
                    // una barra encima de las casillas (InputBorder.none solo
                    // en `border` no basta; bug encontrado por revisor-ui).
                    child: TextField(
                      controller: _controller,
                      focusNode: widget.codeFocus,
                      autofocus: true,
                      enabled: !state.isInProgress,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_kCodeLength),
                      ],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      showCursor: false,
                      // enableInteractiveSelection queda en true (default):
                      // el menú contextual permite PEGAR un código copiado —
                      // el formatter igual lo limita a 6 dígitos (revisor-ui).
                      style: const TextStyle(color: Colors.transparent),
                      decoration: const InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onChanged,
                      onSubmitted: (_) => widget.onSubmit(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Una casilla del código — puro render (estado vacío/activo/error).
class _PinCell extends StatelessWidget {
  const _PinCell({
    required this.digit,
    required this.isActive,
    required this.hasError,
    required this.theme,
  });

  final String digit;
  final bool isActive;
  final bool hasError;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? theme.colorScheme.error
        : isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: _kCellWidth,
      height: _kCellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        // 14 = radius del sistema (inputs/botones) — no 12 (revisor-ui).
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isActive || hasError ? 1.6 : 1.0,
        ),
      ),
      child: Text(
        digit,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
