import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';

/// Título + subtítulo del paso actual del wizard (propuesta 009). El paso 3
/// personaliza con el primer nombre tipeado ("Todo listo, Ana") — confirma
/// visualmente que quedó bien antes de crear la cuenta.
class RegisterStepHeader extends StatelessWidget {
  const RegisterStepHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return BlocBuilder<RegisterCubit, RegisterState>(
      // El título del paso 3 depende del nombre — solo se observa en ese
      // paso (los tecleos del paso 1 no reconstruyen el header).
      buildWhen: (p, c) =>
          p.currentStep != c.currentStep ||
          (c.currentStep == 2 && p.firstName.value != c.firstName.value),
      builder: (context, state) {
        final (String title, String subtitle) = switch (state.currentStep) {
          0 => (l10n.registerStep1Title, l10n.registerStep1Subtitle),
          1 => (l10n.registerStep2Title, l10n.registerStep2Subtitle),
          _ => (
            l10n.registerStep3Title(state.firstName.value.trim()),
            l10n.registerStep3Subtitle,
          ),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        );
      },
    );
  }
}
