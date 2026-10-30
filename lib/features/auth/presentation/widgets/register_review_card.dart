import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';

/// Paso 3 del wizard (propuesta 009): tarjeta de revisión SIN inputs —
/// filas label → valor con lo tipeado. El nombre compone los 4 campos
/// no-vacíos unidos por espacio; teléfono vacío muestra "Sin teléfono".
/// La contraseña NUNCA se muestra.
class RegisterReviewCard extends StatelessWidget {
  const RegisterReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) =>
          p.firstName.value != c.firstName.value ||
          p.secondName.value != c.secondName.value ||
          p.firstLastName.value != c.firstLastName.value ||
          p.secondLastName.value != c.secondLastName.value ||
          p.email.value != c.email.value ||
          p.phone.value != c.phone.value,
      builder: (context, state) {
        final fullName = [
          state.firstName.value,
          state.secondName.value,
          state.firstLastName.value,
          state.secondLastName.value,
        ].map((v) => v.trim()).where((v) => v.isNotEmpty).join(' ');
        final phone = state.phone.value.trim();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            children: [
              _ReviewRow(label: l10n.registerReviewName, value: fullName),
              const SizedBox(height: 12),
              _ReviewRow(
                label: l10n.registerReviewEmail,
                value: state.email.value,
              ),
              const SizedBox(height: 12),
              _ReviewRow(
                label: l10n.registerReviewPhone,
                value: phone.isEmpty ? l10n.registerReviewNoPhone : phone,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fila label → valor: label tenue a la izquierda, valor con énfasis a la
/// derecha (alineado al borde para lectura de resumen).
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
