import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../home/presentation/widgets/customization_section.dart';
import '../../domain/entities/saved_address.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/checkout_state.dart';
import 'checkout_option_row.dart';

/// Bloque de entrega del checkout en modo domicilio (§022): filas de
/// ubicaciones guardadas (ícono por tipo + label + detalle + círculo
/// de selección — mismo idioma OptionRow) + "Nueva ubicación" como
/// toggle de expandir/colapsar (§022d — el segundo tap NO desmarca,
/// solo colapsa; la selección sobrevive) con AnimatedSize 180ms
/// easeOutCubic top-anchored. Debajo, separada por hairline, vive la
/// fila del pin de Google del PEDIDO (§022d — sirve para dirección
/// nueva o guardada).
///
/// La zona no tiene nomenclatura de calles (§022a): el form pide el
/// PUNTO DE REFERENCIA (único requerido) y barrio/sector opcional.
///
/// Errores inline al confirmar: sin selección → texto bajo el bloque;
/// form nuevo incompleto → error en el campo requerido (sin toast) y
/// el form se reabre solo aunque esté colapsado.
class DeliveryAddressBlock extends StatefulWidget {
  const DeliveryAddressBlock({super.key});

  @override
  State<DeliveryAddressBlock> createState() => _DeliveryAddressBlockState();
}

class _DeliveryAddressBlockState extends State<DeliveryAddressBlock> {
  late final TextEditingController _landmark;
  late final TextEditingController _neighborhood;
  late final TextEditingController _labelController;
  late final FocusNode _landmarkFocus = FocusNode();
  late final FocusNode _neighborhoodFocus = FocusNode();
  late final FocusNode _labelFocus = FocusNode();
  final GlobalKey _saveRowKey = GlobalKey();
  bool _didAutoScrollForm = false;

  @override
  void initState() {
    super.initState();
    // Siembra desde el estado (mismo patrón del celular Nequi): el
    // bloque se desmonta al alternar Recoger↔Domicilio y los
    // controllers se recrean — sin esto el texto seguía en el cubit
    // pero el form reaparecía vacío y podía validar una dirección
    // invisible al usuario (revisor-ui).
    final state = context.read<CheckoutCubit>().state;
    _landmark = TextEditingController(text: state.newLandmark);
    _neighborhood = TextEditingController(text: state.newNeighborhood);
    _labelController = TextEditingController(text: state.newAddressLabel);
  }

  @override
  void dispose() {
    _landmark.dispose();
    _neighborhood.dispose();
    _labelController.dispose();
    _landmarkFocus.dispose();
    _neighborhoodFocus.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  IconData _iconFor(SavedAddressType type) => switch (type) {
    SavedAddressType.home => Icons.home_rounded,
    SavedAddressType.work => Icons.work_rounded,
    SavedAddressType.other => Icons.place_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cubit = context.watch<CheckoutCubit>();
    final state = cubit.state;
    final isNew = state.addressId == kCheckoutNewAddressId;
    final formOpen = isNew && state.newAddressExpanded;
    // Al abrir el form, el checkbox "Guardar esta dirección" nace
    // bajo el fold — ensureVisible cuando termina la animación del
    // AnimatedSize (180ms) para que sea descubrible (revisor-ui).
    if (formOpen && !_didAutoScrollForm) {
      _didAutoScrollForm = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 220), () {
          final ctx = _saveRowKey.currentContext;
          if (ctx != null && ctx.mounted) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.85,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          }
        });
      });
    } else if (!formOpen) {
      _didAutoScrollForm = false;
    }
    return BlocListener<CheckoutCubit, CheckoutState>(
      // Foco al primer inválido tras un confirm fallido — mismo
      // patrón de login/register (revisor-ui).
      listenWhen: (prev, curr) =>
          !prev.showAddressError && curr.showAddressError,
      listener: (context, state) {
        if (state.addressId != kCheckoutNewAddressId) return;
        // El único requerido del form es el punto de referencia (§022a).
        if (state.newLandmark.trim().isEmpty) _landmarkFocus.requestFocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          for (final address in state.savedAddresses)
            CheckoutOptionRow(
              icon: _iconFor(address.type),
              title: address.label,
              subtitle: address.detail,
              selected: state.addressId == address.id,
              onTap: () => cubit.selectAddress(address.id),
            ),
          CheckoutOptionRow(
            icon: Icons.add_location_alt_rounded,
            title: l10n.checkoutNewAddress,
            selected: isNew,
            // §022d: la fila es toggle de SOLO expandir/colapsar —
            // tocarla ya seleccionada colapsa el form pero la opción
            // QUEDA marcada; desmarcar es tocar otra dirección.
            onTap: cubit.toggleNewAddress,
          ),
          // Sin selección (no debería ocurrir con el prefill — defensa):
          // error a nivel sección bajo la lista.
          if (state.showAddressError && state.addressId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                l10n.checkoutAddressRequired,
                style: text.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: formOpen
                ? _NewAddressForm(
                    landmarkController: _landmark,
                    neighborhoodController: _neighborhood,
                    labelController: _labelController,
                    landmarkFocus: _landmarkFocus,
                    neighborhoodFocus: _neighborhoodFocus,
                    labelFocus: _labelFocus,
                    saveRowKey: _saveRowKey,
                  )
                : const SizedBox.shrink(),
          ),
          // §022d — división del pin de Google del PEDIDO: adjuntarlo
          // sirve para cualquier dirección escogida (nueva o
          // guardada), así que vive fuera del form, al pie del bloque.
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: colors.outlineVariant,
          ),
          const _DeliveryLocationPin(),
        ],
      ),
    );
  }
}

/// Fila del pin de Google Maps del pedido (§022d): botón outlined
/// "Adjuntar ubicación de Google" → estado adjunto (check primary +
/// link + ✕ quitar). Order-level: el punto exacto aplica a la
/// dirección que esté marcada — nueva o guardada (mock: link fijo).
class _DeliveryLocationPin extends StatelessWidget {
  const _DeliveryLocationPin();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<CheckoutCubit>();
    final link = cubit.state.deliveryLocationLink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: link == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: cubit.attachDeliveryLocation,
                icon: const Icon(Icons.pin_drop_rounded, size: 18),
                label: Text(l10n.checkoutAttachLocation),
              ),
            )
          : Semantics(
              label: '${l10n.checkoutLocationAttached}: $link',
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.checkoutLocationAttached,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: l10n.checkoutRemoveLocation,
                    onPressed: cubit.removeDeliveryLocation,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
    );
  }
}

/// Form inline de "Nueva ubicación" (§022a): PUNTO DE REFERENCIA* es
/// lo único requerido (la zona no tiene direcciones formales), barrio/
/// sector opcional + checkbox "Guardar esta ubicación". El pin de
/// Google vive FUERA del form, al pie del bloque — es del pedido, no
/// de la dirección nueva (§022d). El error de requerido aparece al
/// confirmar con el campo vacío (flag del estado, CustomTextField lo
/// pinta).
class _NewAddressForm extends StatelessWidget {
  const _NewAddressForm({
    required this.landmarkController,
    required this.neighborhoodController,
    required this.labelController,
    required this.landmarkFocus,
    required this.neighborhoodFocus,
    required this.labelFocus,
    required this.saveRowKey,
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
