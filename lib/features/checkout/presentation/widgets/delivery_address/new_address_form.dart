import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../domain/entities/saved_address.dart';
import '../../cubit/checkout_cubit.dart';
import '../../cubit/checkout_state.dart';

/// Form inline de "Nueva ubicación" (§022a): PUNTO DE REFERENCIA* es
/// lo único requerido (la zona no tiene direcciones formales), barrio/
/// sector opcional + checkbox "Guardar esta ubicación". El pin de
/// Google vive FUERA del form, al pie del bloque — es del pedido, no
/// de la dirección nueva (§022d). El error de requerido aparece al
/// confirmar con el campo vacío (flag del estado, CustomTextField lo
/// pinta).
class NewAddressForm extends StatelessWidget {
  const NewAddressForm({
    required this.landmarkController,
    required this.neighborhoodController,
    required this.labelController,
    required this.landmarkFocus,
    required this.neighborhoodFocus,
    required this.labelFocus,
    required this.saveRowKey,
    super.key,
  });

  final TextEditingController landmarkController;
  final TextEditingController neighborhoodController;

  /// Campo del nombre propio cuando el tipo es "Otro" (§022b).
  final TextEditingController labelController;
  final FocusNode landmarkFocus;
  final FocusNode neighborhoodFocus;
  final FocusNode labelFocus;

  /// Key del checkbox "Guardar esta ubicación" — el bloque le hace
  /// ensureVisible al abrirse el form (nace bajo el fold).
  final Key saveRowKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<CheckoutCubit>();
    final state = cubit.state;
    final showErrors = state.showAddressError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            label: l10n.checkoutLandmarkLabel,
            controller: landmarkController,
            focusNode: landmarkFocus,
            hintText: l10n.checkoutLandmarkHint,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            errorText: showErrors && state.newLandmark.trim().isEmpty
                ? l10n.checkoutLandmarkRequired
                : null,
            onChanged: cubit.newLandmarkChanged,
          ),
          CustomTextField(
            label: l10n.checkoutNeighborhoodLabel,
            controller: neighborhoodController,
            focusNode: neighborhoodFocus,
            hintText: l10n.checkoutNeighborhoodHint,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: cubit.newNeighborhoodChanged,
          ),
          InkWell(
            key: saveRowKey,
            onTap: cubit.toggleSaveNewAddress,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    height: 40,
                    width: 40,
                    child: Checkbox(
                      value: state.saveNewAddress,
                      onChanged: (_) => cubit.toggleSaveNewAddress(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.checkoutSaveAddress,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // §022b — el tipo (Casa/Trabajo/Otro) solo se pregunta si la
          // ubicación se va a guardar: es el nombre que la lista
          // mostrará después. Aparece con la física de la familia.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: state.saveNewAddress
                ? _AddressTypePicker(
                    state: state,
                    labelController: labelController,
                    labelFocus: labelFocus,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Selector del tipo de ubicación nueva al guardarla (§022b): chips
/// Casa/Trabajo/Otro — "Otro" revela el campo del nombre propio.
/// Vive detrás del checkbox "Guardar esta ubicación" porque el tipo
/// solo existe para nombrar la guardada.
class _AddressTypePicker extends StatelessWidget {
  const _AddressTypePicker({
    required this.state,
    required this.labelController,
    required this.labelFocus,
  });

  final CheckoutState state;
  final TextEditingController labelController;
  final FocusNode labelFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final cubit = context.read<CheckoutCubit>();
    final selected = state.newAddressType;
    SelectChip chip(SavedAddressType type, String label) => SelectChip(
      label: label,
      selected: selected == type,
      onTap: () => cubit.setNewAddressType(type),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            l10n.checkoutAddressTypeLabel,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(SavedAddressType.home, l10n.checkoutAddressTypeHome),
            chip(SavedAddressType.work, l10n.checkoutAddressTypeWork),
            chip(SavedAddressType.other, l10n.checkoutAddressTypeOther),
          ],
        ),
        // "Otro" necesita el nombre propio — la lista guardada lo
        // mostrará tal cual ("casa de mi mamá").
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: selected == SavedAddressType.other
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CustomTextField(
                    label: l10n.checkoutAddressNameLabel,
                    controller: labelController,
                    focusNode: labelFocus,
                    hintText: l10n.checkoutAddressNameHint,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: cubit.newAddressLabelChanged,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
