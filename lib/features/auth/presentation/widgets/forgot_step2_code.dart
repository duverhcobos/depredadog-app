import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';
import 'six_digit_code_field.dart';

const int _kCodeLength = 6;

/// Paso 2 "Revisa tu correo" (propuesta 011): el OTP de 6 casillas
/// (`SixDigitCodeField` genérico) + reenvío con cooldown de 60s — mismo
/// patrón que verify-email. El subtítulo lleva el correo tipeado en el
/// paso 1. Auto-avanza al completar el 6to dígito (igual que verify) —
/// el "envío" del código y el "check" son simulados, solo validación local.
/// SIN autofocus: el wizard nunca abre el teclado al cambiar de paso
/// (decisión del usuario) — solo al tocar el campo o al fallar validación.
class ForgotStep2Code extends StatefulWidget {
  const ForgotStep2Code({
    super.key,
    required this.codeFocus,
    required this.onVerify,
  });

  /// Lo posee la pantalla: el listener de failure lo usa para enfocar el
  /// código al fallar la validación (convención de foco al primer inválido).
  final FocusNode codeFocus;

  /// "Verificar" del paso = nextStep() de la pantalla (también dispara al
  /// completar los 6 dígitos y con el "done" del teclado).
  final VoidCallback onVerify;

  @override
  State<ForgotStep2Code> createState() => _ForgotStep2CodeState();
}

class _ForgotStep2CodeState extends State<ForgotStep2Code> {
  // Controller del TextField oculto — vive acá igual que en verify-email:
  // la pantalla no necesita su texto (el cubit guarda el CodeInput).
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    context.read<ForgotPasswordCubit>().codeChanged(value);
    if (value.length == _kCodeLength) widget.onVerify();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Sync del controller del TextField oculto: si el state pierde el
    // código por algo ajeno al tipeo (resend() lo limpia), el campo debe
    // vaciarse — si no, al teclear reaparecerían los dígitos viejos.
    // isResending también escucha: durante el reenvío el IME puede pintar
    // dígitos que codeChanged (guard) no deja entrar al state — al
    // terminar el resend este listener los borra (dígitos fantasma,
    // MENOR revisor-ui).
    return BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
      listenWhen: (p, c) =>
          p.code.value != c.code.value || p.isResending != c.isResending,
      listener: (context, state) {
        if (_controller.text != state.code.value) {
          _controller.text = state.code.value;
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.forgotCodeTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // El correo destino viaja desde el paso 1 — mismo copy que
          // verify-email (clave l10n compartida).
          BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
            buildWhen: (p, c) => p.email.value != c.email.value,
            builder: (context, state) => Text(
              l10n.verifyEmailSubtitle(state.email.value),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
          BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
            buildWhen: (p, c) =>
                p.code != c.code ||
                p.showCodeError != c.showCodeError ||
                p.isInProgress != c.isInProgress ||
                p.isResending != c.isResending,
            builder: (context, state) {
              // Convención loading: IgnorePointer bloquea sin atenuar.
              // isResending también bloquea: teclear durante el reenvío
              // sería texto que el éxito de ese resend borra (verify).
              return IgnorePointer(
                ignoring: state.isInProgress || state.isResending,
                child: SixDigitCodeField(
                  controller: _controller,
                  focusNode: widget.codeFocus,
                  // Sin autofocus: entrar al paso no abre el teclado.
                  hasError: state.showCodeError && state.code.isNotValid,
                  // Semántica propia del flujo: "restablecimiento", no
                  // "verificación" — TalkBack anuncia el propósito real.
                  semanticsLabel: (filled) => l10n.forgotCodeSemantics(filled),
                  onChanged: _onChanged,
                  onSubmitted: widget.onVerify,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
            buildWhen: (p, c) =>
                p.resendCooldown != c.resendCooldown ||
                p.isResending != c.isResending ||
                p.isInProgress != c.isInProgress,
            builder: (context, state) {
              // Loading: IgnorePointer bloquea sin atenuar (convención).
              // El disabled visible queda solo para el cooldown — es su
              // estado semántico, no un bloqueo de loading (verify).
              return IgnorePointer(
                ignoring: state.isInProgress,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.verifyEmailResendQuestion,
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: state.canResend
                          ? () => context.read<ForgotPasswordCubit>().resend()
                          : null,
                      child: Text(
                        state.resendCooldown > 0
                            ? l10n.verifyEmailResendIn(state.resendCooldown)
                            : l10n.verifyEmailResend,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
