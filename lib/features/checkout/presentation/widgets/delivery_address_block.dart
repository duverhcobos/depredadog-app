import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/saved_address.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/checkout_state.dart';
import 'checkout_option_row.dart';
import 'delivery_address/addresses_status_rows.dart';
import 'delivery_address/contact_phone_field.dart';
import 'delivery_address/delivery_location_pin.dart';
import 'delivery_address/new_address_form.dart';

/// Bloque de entrega del checkout en modo domicilio (§022 + §025):
/// filas de ubicaciones guardadas (ícono por tipo + label + detalle +
/// círculo de selección — mismo idioma OptionRow) + "Nueva ubicación"
/// como toggle de expandir/colapsar (§022d — el segundo tap NO
/// desmarca, solo colapsa; la selección sobrevive) con AnimatedSize
/// 180ms easeOutCubic top-anchored. Debajo, separadas por hairline, la
/// fila del pin de Google del PEDIDO y el celular de quién recibe
/// (§024). Mientras corre la carga inicial (§025) la zona de filas
/// muestra un spinner chico; si GET /addresses falla, aviso inline
/// con retry y "Nueva ubicación" como única opción.
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
          // §025 — mientras corre GET /addresses + /store/config la
          // zona de filas es un placeholder (el CTA también espera).
          if (state.dataLoading)
            const AddressesLoading()
          else ...[
            // §025 — GET /addresses falló: aviso inline con retry y
            // "Nueva ubicación" como única opción (pickup no se
            // bloquea).
            if (state.addressesFailed) const AddressesErrorNotice(),
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
          ],
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
                ? NewAddressForm(
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
          const DeliveryLocationPin(),
          // §024 — tercera división del bloque (mismo patrón hairline
          // del pin): "dónde entrego" → "a quién llamo".
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: colors.outlineVariant,
          ),
          const ContactPhoneField(),
        ],
      ),
    );
  }
}
