import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/customization_section.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/customer_order.dart';
import '../../domain/failures/orders_failure.dart';
import '../cubit/orders_cubit.dart';
import '../cubit/orders_state.dart';
import '../utils/format_order_date.dart';
import '../utils/format_phone.dart';
import '../widgets/order_cancel_dialog.dart';
import '../widgets/order_item_detail_panel.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/order_status_stepper.dart';

/// Detalle del pedido (§023/§027 — drill-down del tab, push slideUp
/// como cart/checkout): estado con stepper (o chip + razón si
/// cancelado), ítems completos con modificadores, entrega + pago,
/// observación y totales. El `extra` de la ruta es el snapshot
/// instantáneo; el pedido se resuelve FRESCO por id desde el
/// OrdersCubit (refreshOrder al abrir trae estado + modifiers — la
/// ventana de cancelar desaparece sola si el admin ya confirmó). El
/// back regresa al tab. SIN "volver a pedir" — descartado por el
/// usuario para el MVP.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({required this.order, super.key});

  /// Snapshot de la lista que abrió el detalle — fallback instantáneo
  /// mientras el refresh trae la entidad completa del cubit.
  final CustomerOrder order;

  /// La entidad viva del cubit (active o history) — o el snapshot si
  /// aún no llega / ya no está en ninguna lista.
  CustomerOrder _resolve(OrdersState state) {
    for (final list in [state.active, state.history]) {
      for (final o in list) {
        if (o.id == order.id) return o;
      }
    }
    return order;
  }

  /// Cancela desde el detalle (revisor-ui §023 — el drill-down no
  /// puede ser MENOS capaz que la card): confirma → cancel real
  /// (POST /orders/:id/cancel, §027) → éxito: toast + pop al tab;
  /// failure: toast l10n propio y SIN pop (el pedido se ve con su
  /// estado real tras el resync silencioso del cubit — el mensaje
  /// del servidor viene en inglés y no se muestra, revisor §027).
  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showOrderCancelDialog(context);
    if (!confirmed || !context.mounted) return;
    final failure = await context.read<OrdersCubit>().cancelOrder(order.id);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (failure == null) {
      AppToast.info(context, l10n.orderCancelledToast);
      context.pop();
    } else {
      AppToast.info(
        context,
        failure is OrdersCancelRejectedFailure
            ? l10n.ordersCancelRejected
            : l10n.ordersCancelError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<OrdersCubit, OrdersState>(
            builder: (context, state) {
              final order = _resolve(state);
              final isCancelled = order.status == OrderStatus.cancelled;
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const _DetailTitle(),
                  CustomizationSection(
                    title: l10n.orderDetailStatusSection,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  // "Pedido el 8 nov · 12:40 p. m." —
                                  // placedAt bajo "Estado" se leía como
                                  // fecha del cambio de estado
                                  // (revisor-ui §023).
                                  child: Text(
                                    l10n.orderPlacedAt(
                                      formatOrderDate(order.placedAt),
                                    ),
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                                OrderStatusChip(order: order),
                              ],
                            ),
                            if (!isCancelled) ...[
                              const SizedBox(height: 14),
                              OrderStatusStepper(order: order),
                            ],
                            if (isCancelled && order.cancelReason != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                order.cancelReason!,
                                style: text.bodySmall?.copyWith(
                                  color: colors.error.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                            if (order.isCancellable) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _confirmCancel(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.error,
                                  ),
                                  child: Text(l10n.orderCancelCta),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  CustomizationSection(
                    title: l10n.orderDetailItemsSection,
                    children: [
                      for (final item in order.items) _ItemLine(item: item),
                      Divider(
                        height: 24,
                        indent: 14,
                        endIndent: 14,
                        color: colors.outlineVariant.withValues(alpha: 0.4),
                      ),
                      _Totals(order: order),
                    ],
                  ),
                  CustomizationSection(
                    title: l10n.orderDetailDeliverySection,
                    children: [_DeliveryDetail(order: order)],
                  ),
                  if (order.note != null && order.note!.isNotEmpty)
                    CustomizationSection(
                      title: l10n.orderDetailNoteSection,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 16,
                                color: colors.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.note!,
                                  style: text.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
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
}

/// Título "Detalle del pedido" — mismo patrón scrolling_title que
/// cart/checkout: PRIMER hijo del ListView (sale al bajar, vuelve al
/// subir — revisor-estetico §023: fijo contradecía a la familia).
class _DetailTitle extends StatelessWidget {
  const _DetailTitle();

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
              l10n.orderDetailTitle,
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

/// Ítem del pedido: "2× El Cachorro" + chip "Detalle" que despliega
/// la personalización por secciones — el MISMO idioma del tile del
/// carrito (§021b/§023): el cliente verifica qué quedó en cada perro.
/// Solo lectura — sin Editar (el pedido ya se cobró).
class _ItemLine extends StatefulWidget {
  const _ItemLine({required this.item});

  final OrderItem item;

  @override
  State<_ItemLine> createState() => _ItemLineState();
}

class _ItemLineState extends State<_ItemLine> {
  /// Detalle desplegado por tap — arranca colapsado (§021).
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantity}× ${item.name}',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // Solo con qty>1: con 1 duplicaba el lineTotal
                    // (revisor-ui §020 — misma regla del cart tile).
                    if (item.quantity > 1)
                      Text(
                        formatCop(item.unitPrice),
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chip "Detalle" — píldora outlined con el chevron
              // dentro; idéntica a la del cart tile.
              Semantics(
                container: true,
                button: true,
                expanded: _expanded,
                label: l10n.cartItemDetailToggle,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  customBorder: const StadiumBorder(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.cartItemDetail,
                              style: text.labelSmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 1),
                            Icon(
                              _expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCop(item.lineTotal),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          // AnimatedSize — la misma física del panel del carrito.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: _expanded
                ? OrderItemDetailPanel(item: item)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Subtotal / domicilio ("Gratis" primary) / total — mismo idioma del
/// resumen del checkout.
class _Totals extends StatelessWidget {
  const _Totals({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        children: [
          // Subtotal solo cuando el desglose separa algo — en pickup
          // (sin fila Domicilio) Subtotal==Total duplica la cifra
          // (regla "no duplicar números" §020 — igual que el _Totals
          // admin §037).
          if (order.serviceType == OrderServiceType.delivery)
            _row(
              text,
              colors,
              l10n.orderSummarySubtotal,
              formatCop(order.subtotal),
            ),
          if (order.serviceType == OrderServiceType.delivery)
            _row(
              text,
              colors,
              l10n.orderSummaryDelivery,
              order.deliveryFee == 0
                  ? l10n.orderSummaryFree
                  : formatCop(order.deliveryFee),
              valuePrimary: order.deliveryFee == 0,
            ),
          const SizedBox(height: 4),
          _row(
            text,
            colors,
            l10n.orderSummaryTotal,
            formatCop(order.total),
            total: true,
          ),
        ],
      ),
    );
  }

  Widget _row(
    TextTheme text,
    ColorScheme colors,
    String label,
    String value, {
    bool valuePrimary = false,
    bool total = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: (total ? text.titleSmall : text.bodySmall)?.copyWith(
              color: total
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.7),
              fontWeight: total ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: (total ? text.titleSmall : text.bodySmall)?.copyWith(
            color: valuePrimary || total ? colors.primary : colors.onSurface,
            fontWeight: total || valuePrimary
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// Bloque "Entrega y pago" del detalle: servicio + referencia completa
/// (etiqueta / punto de referencia / barrio / pin / celular de quién
/// recibe §024) o local, y método + estado de pago.
class _DeliveryDetail extends StatelessWidget {
  const _DeliveryDetail({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDelivery ? Icons.moped_rounded : Icons.storefront_rounded,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isDelivery
                    ? l10n.orderServiceDelivery
                    : l10n.orderServicePickup,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isDelivery) ...[
            if (order.addressLabel != null)
              Text(order.addressLabel!, style: text.bodyMedium),
            if (order.landmark != null)
              Text(
                order.landmark!,
                style: text.bodyMedium?.copyWith(color: muted),
              ),
            if (order.neighborhood != null)
              Text(
                order.neighborhood!,
                style: text.bodySmall?.copyWith(color: muted),
              ),
            if (order.hasLocationPin)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.orderWithLocationPin,
                      style: text.bodySmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            // §024 — a quién llamar si nadie sale (solo delivery).
            if (order.contactPhone != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 16, color: muted),
                    const SizedBox(width: 8),
                    Text(
                      l10n.orderContactPhone(formatPhone(order.contactPhone!)),
                      style: text.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
          ] else
            Text(
              order.storeReference ?? l10n.orderPickupAtStore,
              style: text.bodyMedium?.copyWith(color: muted),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                order.paymentMethod == OrderPaymentMethod.nequi
                    ? Icons.smartphone_rounded
                    : Icons.payments_rounded,
                size: 16,
                color: muted,
              ),
              const SizedBox(width: 8),
              Text(switch ((order.paymentMethod, order.paymentStatus)) {
                (OrderPaymentMethod.nequi, OrderPaymentStatus.paid) =>
                  l10n.orderPaymentNequiPaid,
                (OrderPaymentMethod.nequi, _) => l10n.orderPaymentNequiPending,
                // En terminales (entregado/cancelado) la obligación ya
                // pasó — "Pagaste", no "Pagas" (revisor-ui §023).
                (OrderPaymentMethod.onDelivery, _) =>
                  order.isTerminal
                      ? l10n.orderPaymentOnDeliveryPast
                      : l10n.orderPaymentOnDelivery,
              }, style: text.bodyMedium?.copyWith(color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}
