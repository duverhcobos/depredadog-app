import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import 'register_field.dart';

/// Sanitización de nombres (propuesta 009): solo letras latinas (con
/// tilde/ñ/ü), espacio y apóstrofe (recto ' y tipográfico ’ de los
/// teclados móviles) — compuestos latinos pasan ("De la Cruz", "O'Neil");
/// dígitos, @, guion y símbolos ni siquiera se teclean.
final _nameCharsOnly = FilteringTextInputFormatter.allow(
  RegExp(r"[A-Za-záéíóúÁÉÍÓÚñÑüÜ'’ ]"),
);

/// Paso 1 "Cuéntanos quién eres" (propuesta 009): los 4 campos de nombre
/// LatAm + teléfono opcional. Controllers/FocusNodes los posee el State de
/// la pantalla — al volver del paso 2 los datos siguen intactos.
/// Convención de loading (ui-design-standard): mientras el submit resuelve,
/// TODO lo interactivo queda BLOQUEADO con IgnorePointer sin atenuar.
class RegisterStep1Fields extends StatelessWidget {
  const RegisterStep1Fields({
    super.key,
    required this.firstNameController,
    required this.secondNameController,
    required this.firstLastNameController,
    required this.secondLastNameController,
    required this.phoneController,
    required this.firstNameFocus,
    required this.secondNameFocus,
    required this.firstLastNameFocus,
    required this.secondLastNameFocus,
    required this.phoneFocus,
    required this.onContinue,
  });

  final TextEditingController firstNameController;
  final TextEditingController secondNameController;
  final TextEditingController firstLastNameController;
  final TextEditingController secondLastNameController;
  final TextEditingController phoneController;
  final FocusNode firstNameFocus;
  final FocusNode secondNameFocus;
  final FocusNode firstLastNameFocus;
  final FocusNode secondLastNameFocus;
  final FocusNode phoneFocus;

  /// Acción "done" del teclado en el último campo = "Continuar".
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) => p.isInProgress != c.isInProgress,
      builder: (context, progressState) {
        return IgnorePointer(
          ignoring: progressState.isInProgress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RegisterField(
                key: const ValueKey('register_first_name'),
                label: l10n.registerFirstNameLabel,
                controller: firstNameController,
                focusNode: firstNameFocus,
                hintText: l10n.registerFirstNameHint,
                prefixIcon: const Icon(Icons.person_outline),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                inputFormatters: [_nameCharsOnly],
                errorText: (s) => switch (s.firstNameErrorKey()) {
                  'empty' => l10n.registerNameRequired,
                  'invalid' => l10n.registerNameInvalid,
                  _ => null,
                },
                onChanged: (v) =>
                    context.read<RegisterCubit>().firstNameChanged(v),
              ),
              const SizedBox(height: 8),
              RegisterField(
                key: const ValueKey('register_second_name'),
                label: l10n.registerSecondNameLabel,
                controller: secondNameController,
                focusNode: secondNameFocus,
                prefixIcon: const Icon(Icons.person_outline),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.middleName],
                inputFormatters: [_nameCharsOnly],
                // Opcional: input siempre válido, nunca muestra error.
                errorText: (s) => null,
                onChanged: (v) =>
                    context.read<RegisterCubit>().secondNameChanged(v),
              ),
              const SizedBox(height: 8),
              RegisterField(
                key: const ValueKey('register_first_last_name'),
                label: l10n.registerLastNameLabel,
                controller: firstLastNameController,
                focusNode: firstLastNameFocus,
                hintText: l10n.registerLastNameHint,
                prefixIcon: const Icon(Icons.person_outline),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                inputFormatters: [_nameCharsOnly],
                errorText: (s) => switch (s.firstLastNameErrorKey()) {
                  'empty' => l10n.registerLastNameRequired,
                  'invalid' => l10n.registerLastNameInvalid,
                  _ => null,
                },
                onChanged: (v) =>
                    context.read<RegisterCubit>().firstLastNameChanged(v),
              ),
              const SizedBox(height: 8),
              RegisterField(
                key: const ValueKey('register_second_last_name'),
                label: l10n.registerSecondLastNameLabel,
                controller: secondLastNameController,
                focusNode: secondLastNameFocus,
                prefixIcon: const Icon(Icons.person_outline),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                // Sin autofillHint: con familyName duplicado GMS rellenaría
                // los DOS apellidos iguales (revisor-ui).
                inputFormatters: [_nameCharsOnly],
                errorText: (s) => null,
                onChanged: (v) =>
                    context.read<RegisterCubit>().secondLastNameChanged(v),
              ),
              const SizedBox(height: 8),
              RegisterField(
                key: const ValueKey('register_phone'),
                label: l10n.registerPhoneLabel,
                controller: phoneController,
                focusNode: phoneFocus,
                hintText: l10n.registerPhoneHint,
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                // Último campo del paso: "done" dispara Continuar.
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                // Celular colombiano (propuesta 009): solo dígitos y
                // máximo 10 — las letras nunca entran al campo; el
                // formato 3XX XXX XXXX lo valida PhoneInput.
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                errorText: (s) => switch (s.phoneErrorKey()) {
                  'invalid' => l10n.registerPhoneInvalid,
                  _ => null,
                },
                onChanged: (v) => context.read<RegisterCubit>().phoneChanged(v),
                onFieldSubmitted: (_) => onContinue(),
              ),
            ],
          ),
        );
      },
    );
  }
}
