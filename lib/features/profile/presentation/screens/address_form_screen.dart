import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../checkout/domain/entities/saved_address.dart';
import '../../../home/presentation/widgets/customization_section.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/profile_addresses_cubit.dart';

/// Form compartido crear/editar de dirección guardada (§030 —
/// /profile/addresses/new|edit, hija de addresses): mismo esquema de
/// campos que el `NewAddressForm` del checkout — chips tipo
/// Casa/Trabajo/Otro (SelectChip de la casa), PUNTO DE REFERENCIA
/// requerido, barrio opcional y nombre propio solo para "Otro".
///
/// Estado LOCAL (controllers + type + flag de errores — sin cubit
/// propio): el upsert escribe sobre el ProfileAddressesCubit de la
/// lista que queda debajo en el stack — el singleton compartido hace
/// que la fila nueva/editada aparezca al volver (mismo truco que
/// order_detail sobre OrdersCubit).
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({this.editing, super.key});

  /// Dirección en edición — null = modo crear.
  final SavedAddress? editing;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  late final TextEditingController _landmark;
  late final TextEditingController _neighborhood;
  late final TextEditingController _label;
  late final FocusNode _landmarkFocus = FocusNode();
  late final FocusNode _neighborhoodFocus = FocusNode();
  late final FocusNode _labelFocus = FocusNode();
  late SavedAddressType _type;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    // Prefill del modo edición — el SavedAddress llega como extra de
    // la ruta (patrón cart/edit).
    final editing = widget.editing;
    _type = editing?.type ?? SavedAddressType.home;
    _landmark = TextEditingController(text: editing?.landmark ?? '');
    _neighborhood = TextEditingController(text: editing?.neighborhood ?? '');
    _label = TextEditingController(text: editing?.label ?? '');
  }

  @override
  void dispose() {
    _landmark.dispose();
    _neighborhood.dispose();
    _label.dispose();
    _landmarkFocus.dispose();
    _neighborhoodFocus.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  /// Valida inline (landmark requerido; nombre requerido solo para
  /// "Otro") y hace el upsert sobre el cubit de la lista — crear:
  /// id mock + default si es la primera (regla del backend, fase 2);
  /// editar: copyWith que preserva el isDefault (marcar/quitar
  /// default es la acción del ⋮, no del form).
  void _save() {
    final landmark = _landmark.text.trim();
    final needsLabel = _type == SavedAddressType.other;
    final landmarkEmpty = landmark.isEmpty;
    final labelEmpty = needsLabel && _label.text.trim().isEmpty;
    if (landmarkEmpty || labelEmpty) {
      setState(() => _showErrors = true);
      // Foco al primer inválido — mismo patrón de login/checkout.
      (landmarkEmpty ? _landmarkFocus : _labelFocus).requestFocus();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ProfileAddressesCubit>();
    // Casa/Trabajo se nombran solos con el texto del chip — la capa
    // de integración traduce al label del recurso (fase 1 = mock).
    final resolvedLabel = switch (_type) {
      SavedAddressType.home => l10n.checkoutAddressTypeHome,
      SavedAddressType.work => l10n.checkoutAddressTypeWork,
      SavedAddressType.other => _label.text.trim(),
    };
    final editing = widget.editing;
    final address = editing != null
        ? editing.copyWith(
            label: resolvedLabel,
            landmark: landmark,
            neighborhood: _neighborhood.text.trim(),
            type: _type,
          )
        : SavedAddress(
            id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
            label: resolvedLabel,
            landmark: landmark,
            neighborhood: _neighborhood.text.trim(),
            type: _type,
            // Primera dirección guardada → nace default (el backend
            // la marca; fase 1 lo refleja el mock).
            isDefault: cubit.state.addresses.isEmpty,
          );
    cubit.upsert(address);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final editing = widget.editing != null;
    SelectChip chip(SavedAddressType type, String label) => SelectChip(
      label: label,
      selected: _type == type,
      // Al cambiar de tipo los errores de un "Guardar" fallido se
      // lavan — sin el reset, el campo recién revelado de "Otro"
      // nacía ya marcado sin que el usuario lo tocara.
      onTap: () => setState(() {
        _type = type;
        _showErrors = false;
      }),
    );
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _FormTitle(editing: editing),
                    // Card straddle de la familia — la misma cuna que
                    // la sección del checkout donde viven estos campos.
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: LayoutBuilder(
                        builder: (context, c) => Padding(
                          padding: EdgeInsets.only(
                            left:
                                c.maxWidth *
                                kSignatureStripFraction *
                                kCardStripInset,
                            right: blackZoneMargin(c.maxWidth),
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            color: colors.surfaceContainerLow,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.checkoutAddressTypeLabel,
                                    style: text.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      chip(
                                        SavedAddressType.home,
                                        l10n.checkoutAddressTypeHome,
                                      ),
                                      chip(
                                        SavedAddressType.work,
                                        l10n.checkoutAddressTypeWork,
                                      ),
                                      chip(
                                        SavedAddressType.other,
                                        l10n.checkoutAddressTypeOther,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  CustomTextField(
                                    label: l10n.addressesLandmarkLabel,
                                    controller: _landmark,
                                    focusNode: _landmarkFocus,
                                    hintText: l10n.checkoutLandmarkHint,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    errorText:
                                        _showErrors &&
                                            _landmark.text.trim().isEmpty
                                        ? l10n.addressesLandmarkRequired
                                        : null,
                                    // Rebuild al teclear: el error se
                                    // limpia en vivo (igual que el
                                    // estado del checkout).
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  CustomTextField(
                                    label: l10n.addressesNeighborhoodLabel,
                                    controller: _neighborhood,
                                    focusNode: _neighborhoodFocus,
                                    hintText: l10n.checkoutNeighborhoodHint,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: needsLabel
                                        ? TextInputAction.next
                                        : TextInputAction.done,
                                    onChanged: (_) {},
                                  ),
                                  // "Otro" necesita el nombre propio —
                                  // la lista lo mostrará tal cual
                                  // ("Mamá", "casa de mi novia"). Misma
                                  // física de reveal del checkout.
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment.topCenter,
                                    clipBehavior: Clip.hardEdge,
                                    child: needsLabel
                                        ? CustomTextField(
                                            label: l10n.addressesLabelLabel,
                                            controller: _label,
                                            focusNode: _labelFocus,
                                            hintText:
                                                l10n.checkoutAddressNameHint,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            textInputAction:
                                                TextInputAction.done,
                                            errorText:
                                                _showErrors &&
                                                    _label.text.trim().isEmpty
                                                ? l10n.addressesLabelRequired
                                                : null,
                                            onChanged: (_) => setState(() {}),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Footer fijo del CTA primario — misma convención de
              // cart/checkout/detalle (fondo opaco + SafeArea).
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        child: Text(l10n.addressFormSave),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 4,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colors.onPrimary),
              tooltip: l10n.catalogBackTooltip,
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  bool get needsLabel => _type == SavedAddressType.other;
}

/// Título naciente del form — "Nueva dirección" o "Editar dirección"
/// según el modo (scrolling_title, primer hijo del ListView).
class _FormTitle extends StatelessWidget {
  const _FormTitle({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.602,
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              editing ? l10n.addressesEditTitle : l10n.addressesNewTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
