import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import 'wizard_stepper.dart';

/// Stepper del wizard de registro (propuesta 009): wrapper fino que lee
/// `RegisterCubit` y delega el render al genérico `WizardStepper`
/// (extraído en la propuesta 011 para compartirlo con /forgot-password).
class RegisterStepper extends StatelessWidget {
  const RegisterStepper({super.key});

  static const int _steps = 3;

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
      builder: (context, state) => WizardStepper(
        labels: labels,
        currentStep: state.currentStep,
        progressLabel: l10n.registerStepProgress(state.currentStep + 1, _steps),
      ),
    );
  }
}
