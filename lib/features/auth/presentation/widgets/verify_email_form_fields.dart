import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/failures/auth_failure.dart';
import '../cubit/verify_email_cubit.dart';
import '../cubit/verify_email_state.dart';
import 'six_digit_code_field.dart';

const int _kCodeLength = 6;

/// SOLID (SRP): el campo de código vive aquí — la pantalla solo orquesta
/// (bloc-patterns: sin BlocBuilder de campos inline). El render de las 6
/// casillas es el genérico `SixDigitCodeField` (propuesta 011); este
/// widget lo rebinda al `VerifyEmailCubit`: sync del controller cuando el
/// state pierde el código por fuera del tipeo (resend), hasError local +
/// InvalidCodeFailure, bloqueo por IgnorePointer y auto-submit al 6to
/// dígito.
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
      child: BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
        buildWhen: (p, c) =>
            p.code != c.code ||
            p.showCodeError != c.showCodeError ||
            p.isInProgress != c.isInProgress ||
            p.isResending != c.isResending ||
            p.authFailure != c.authFailure,
        builder: (context, state) {
          // Rojo en validación local O cuando el backend rechazó el
          // código (InvalidCodeFailure) — un código de 6 dígitos errado
          // es formz-válido, así que el flag local no basta.
          final hasError =
              (state.showCodeError && state.code.isNotValid) ||
              state.authFailure is InvalidCodeFailure;
          // Convención loading: bloqueo por IgnorePointer — las casillas
          // conservan su apariencia (no se atenúan); _submit() ya hizo
          // unfocus así que el campo oculto no puede recibir IME.
          // isResending también bloquea: teclear durante el reenvío sería
          // texto que el éxito de ese resend borra en unos segundos.
          return IgnorePointer(
            ignoring: state.isInProgress || state.isResending,
            child: SixDigitCodeField(
              controller: _controller,
              focusNode: widget.codeFocus,
              hasError: hasError,
              autofocus: true,
              semanticsLabel: (filled) =>
                  AppLocalizations.of(context)!
                      .verifyEmailCodeSemantics(filled),
              onChanged: _onChanged,
              onSubmitted: widget.onSubmit,
            ),
          );
        },
      ),
    );
  }
}
