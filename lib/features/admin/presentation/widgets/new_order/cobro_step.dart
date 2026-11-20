import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../../cart/presentation/widgets/cart_item_tile.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../../home/presentation/widgets/signature_strip.dart';
import '../../../domain/entities/admin_order.dart';
import '../../cubit/admin_new_order_cubit.dart';
import '../../cubit/admin_new_order_state.dart';
import 'new_order_title.dart';
import 'table_picker.dart';

/// Paso 2 de la comanda (§042): "Revisar y cobrar" — ticket con
/// las filas reutilizadas del carrito (qty stepper + quitar +
/// detalle "Lleva:" desplegable), chips de servicio [Mesa | Para
/// llevar] + picker de mesas (ocupada "#N" disabled, inactiva
/// atenuada), chips de pago [Efectivo | Transf.] + celular visible
/// solo en Transf. con validación tras salir del campo, y nota
/// opcional del pedido (maxLength 500; items[].notes fuera de
/// alcance §042).
class CobroStep extends StatelessWidget {
  const CobroStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = context.watch<AdminNewOrderCubit>().state;
    return LayoutBuilder(
      builder: (context, c) {
        // Zona negra para las secciones planas (labels mostaza y
        // chips con tinte primario se camuflan sobre la franja —
        // en todas las pantallas el texto plano vive en zona negra
        // y solo las CARDS stradlean; la del ticket ya lo hace).
        // El riel derecho iguala blackZoneMargin: el filo de la
        // nota y los chips termina en el mismo filo de la card del
        // ticket (revisor-ui §042).
        final left = c.maxWidth * kSignatureStripFraction + 16;
        final right = blackZoneMargin(c.maxWidth);
        final zone = EdgeInsets.only(left: left, right: right);
        // ChipWrap inyecta +14 propios: el padding compensa para
        // que los chips arranquen en el MISMO riel que labels y
        // campos, no 14dp corridos (revisor-ui §042).
        final chipZone = EdgeInsets.only(
          left: left > 14 ? left - 14 : 0,
          right: right > 14 ? right - 14 : 0,
        );
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            NewOrderTitle(text: l10n.adminNewOrderReviewTitle),
            const SizedBox(height: 4),
            // Ticket — mismas filas del carrito (straddle propio).
            if (state.items.isEmpty)
              Padding(
                padding: zone.copyWith(top: 12),
                child: Text(
                  l10n.adminNewOrderTicketEmpty,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              )
            else
              for (final item in state.items)
                CartItemTile(
                  key: ValueKey(item.id),
                  item: item,
                  onQuantityChanged: (q) =>
                      context.read<AdminNewOrderCubit>().setItemQty(item.id, q),
                  onRemove: () =>
                      context.read<AdminNewOrderCubit>().removeItem(item.id),
                ),
            const SizedBox(height: 24),
            // Servicio — [Mesa | Para llevar] + mesas solo en dineIn.
            _CobroSection(
              zone: zone,
              label: l10n.adminNewOrderService,
              childPadding: chipZone,
              child: ChipWrap(
                children: [
                  SelectChip(
                    label: l10n.adminNewOrderDineIn,
                    selected: state.serviceType == AdminServiceType.dineIn,
                    onTap: () => context
                        .read<AdminNewOrderCubit>()
                        .toggleService(AdminServiceType.dineIn),
                  ),
                  SelectChip(
                    label: l10n.adminNewOrderPickup,
                    selected: state.serviceType == AdminServiceType.pickup,
                    onTap: () => context
                        .read<AdminNewOrderCubit>()
                        .toggleService(AdminServiceType.pickup),
                  ),
                ],
              ),
            ),
            // Reveal suave de la familia (AnimatedSize 180 easeOut).
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: state.serviceType == AdminServiceType.dineIn
                  ? Padding(
                      padding: zone,
                      child: TablePicker(
                        tables: state.tables,
                        selectedTableId: state.selectedTableId,
                        onSelect: context
                            .read<AdminNewOrderCubit>()
                            .selectTable,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Pago — [Efectivo | Transf.] + celular solo en Transf.
            _CobroSection(
              zone: zone,
              label: l10n.adminNewOrderPayment,
              childPadding: chipZone,
              child: ChipWrap(
                children: [
                  SelectChip(
                    label: l10n.adminPaymentCash,
                    selected: state.paymentMethod == AdminPaymentMethod.cash,
                    onTap: () => context.read<AdminNewOrderCubit>().setPayment(
                      AdminPaymentMethod.cash,
                    ),
                  ),
                  SelectChip(
                    label: l10n.adminPaymentTransfer,
                    selected:
                        state.paymentMethod == AdminPaymentMethod.transfer,
                    onTap: () => context.read<AdminNewOrderCubit>().setPayment(
                      AdminPaymentMethod.transfer,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: state.paymentMethod == AdminPaymentMethod.transfer
                  ? Padding(
                      padding: zone,
                      child: _PayerPhoneField(state: state),
                    )
                  : const SizedBox.shrink(),
            ),
            // Nota del pedido completo — opcional, maxLength 500.
            Padding(
              padding: zone.copyWith(top: 12),
              child: TextFormField(
                initialValue: state.notes,
                maxLength: 500,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onChanged: context.read<AdminNewOrderCubit>().setNotes,
                decoration: InputDecoration(
                  labelText: l10n.adminNewOrderNote,
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Celular del push transfer (§042) — CustomTextField de la casa
/// (reserva la línea de error: no re-fluye al aparecer). El error
/// se muestra tras SALIR del campo con dígitos inválidos, no desde
/// el primer keystroke (convención del checkout — revisor-ui §042);
/// el CTA queda disabled mientras el número no cumpla ^3\d{9}$.
class _PayerPhoneField extends StatefulWidget {
  const _PayerPhoneField({required this.state});

  final AdminNewOrderState state;

  @override
  State<_PayerPhoneField> createState() => _PayerPhoneFieldState();
}

class _PayerPhoneFieldState extends State<_PayerPhoneField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Marca el primer blur — el error no se muestra mientras el
  /// usuario sigue tipeando dentro del campo (revisor-ui §042).
  bool _blurred = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.payerPhone);
    _focusNode = FocusNode()
      ..addListener(() {
        if (!_focusNode.hasFocus && !_blurred) {
          setState(() => _blurred = true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final phone = widget.state.payerPhone;
    return CustomTextField(
      label: l10n.adminNewOrderPayerPhone,
      controller: _controller,
      focusNode: _focusNode,
      hintText: l10n.adminNewOrderPhoneHint,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      onChanged: context.read<AdminNewOrderCubit>().setPayerPhone,
      errorText: _blurred && phone.isNotEmpty && !widget.state.isPayerPhoneValid
          ? l10n.adminNewOrderPhoneError
          : null,
    );
  }
}

/// Sección del cobro — label mostaza pesada + contenido, acotada
/// a la zona negra (misma geometría de los bloques del detalle).
/// `childPadding` permite compensar el padding propio de chips
/// para que arranquen en el riel del label (revisor-ui §042).
class _CobroSection extends StatelessWidget {
  const _CobroSection({
    required this.zone,
    required this.label,
    required this.child,
    this.childPadding,
  });

  final EdgeInsets zone;
  final String label;
  final Widget child;

  /// Padding del contenido — default = zone; las secciones de
  /// chips pasan la zona compensada (−14 por lado del ChipWrap).
  final EdgeInsets? childPadding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: zone.copyWith(top: 8),
          child: Text(
            label,
            style: text.titleSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(padding: childPadding ?? zone, child: child),
      ],
    );
  }
}
