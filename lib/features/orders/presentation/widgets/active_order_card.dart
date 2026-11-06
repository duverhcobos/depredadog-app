import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/catalog_assets.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/product_image.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/customer_order.dart';
import '../cubit/orders_cubit.dart';
import 'order_cancel_dialog.dart';
import 'order_status_chip.dart';
import 'order_status_stepper.dart';

/// Card straddle del pedido "En curso" (§023 — cada pedido activo es
/// su propia card, decisión del usuario por revisor-estetico): la
/// imagen del primer ítem flota a caballo del borde izquierdo —
/// misma firma visual de product/category/cart tiles, apetito +
/// reconocimiento inmediato. Contenido: servicio + chip de estado,
/// stepper, resumen de ítems, entrega (referencia o local), pago y
/// observación. Tap → detalle (`/orders/:id`, drill-down con extra).
/// "Cancelar pedido" solo vive en "Recibido" (regla backend: cancel
/// en pending) con diálogo de confirmación — decisión del usuario:
/// la cancelación no es un botón permanente.
class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({required this.order, super.key});

  final CustomerOrder order;

  /// Alto del recuadro flotante — 80px, el mismo de cart_item_tile
  /// (pulido revisor-estetico §020).
  static const double _imageSize = 80;

  /// Cancela tras el diálogo compartido y avisa con AppToast — el
  /// feedback efímero es el mínimo de la familia ante una
  /// destrucción sin deshacer (revisor-ui §023, igual que cart §020).
  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showOrderCancelDialog(context);
    if (confirmed && context.mounted) {
      context.read<OrdersCubit>().cancelOrder(order.id);
      AppToast.info(context, AppLocalizations.of(context)!.orderCancelledToast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final cardLeft =
              c.maxWidth * kSignatureStripFraction * kCardStripInset;
          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: cardLeft,
                  right: blackZoneMargin(c.maxWidth),
                ),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: colors.surfaceContainerLow,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    onTap: () => context.push(
                      '${AuthGuard.ordersRoute}/${order.id}',
                      extra: order,
                    ),
                    child: Padding(
                      // Texto anclado al marco: borde derecho del
                      // recuadro + gap (regla de product/cart).
                      padding: const EdgeInsets.only(
                        left: _imageSize - kFrameOverhang + kFrameTextGap,
                        right: 14,
                        top: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDelivery
                                    ? Icons.moped_rounded
                                    : Icons.storefront_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isDelivery
                                    ? l10n.orderServiceDelivery
                                    : l10n.orderServicePickup,
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              OrderStatusChip(order: order),
                            ],
                          ),
                          const SizedBox(height: 14),
                          OrderStatusStepper(order: order),
                          const SizedBox(height: 12),
                          // Resumen: "2× El Cachorro, 1× La Trampa" + total.
                          Text(
                            order.items
                                .map((i) => '${i.quantity}× ${i.name}')
                                .join(', '),
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _DeliveryLine(order: order)),
                              const SizedBox(width: 8),
                              Text(
                                formatCop(order.total),
                                style: text.titleSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _PaymentLine(order: order),
                          if (order.isCancellable) ...[
                            // Aire real antes del destructivo: su hit
                            // area (48dp padded) no debe invadir la
                            // línea de pago (revisor-ui §023).
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _confirmCancel(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.error,
                                  minimumSize: const Size(0, 36),
                                ),
                                child: Text(l10n.orderCancelCta),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Recuadro flotante a caballo del borde de la card —
              // centrado vertical, mismo gesto firma de cart_tile.
              if (order.items.isNotEmpty)
                Positioned(
                  left: cardLeft - kFrameOverhang,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IgnorePointer(
                      child: ProductImage(
                        asset: CatalogAssets.productAsset(
                          order.items.first.productSlug,
                        ),
                        size: _imageSize,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Línea de entrega: domicilio = referencia (+ pin si adjunto);
/// local = la referencia real del negocio (revisor-estetico §023 —
/// la frase genérica duplicaba el header "Local").
class _DeliveryLine extends StatelessWidget {
  const _DeliveryLine({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    if (order.serviceType == OrderServiceType.pickup) {
      return Row(
        children: [
          // Pin, no storefront — el header del servicio ya lleva la
          // tienda (revisor-ui §023: ícono repetido a ~150dp).
          Icon(Icons.place_outlined, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              order.storeReference ?? l10n.orderPickupAtStore,
              style: text.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.place_outlined, size: 14, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [
                  if (order.addressLabel != null) order.addressLabel!,
                  if (order.landmark != null) order.landmark!,
                ].join(' — '),
                style: text.bodySmall?.copyWith(color: muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (order.hasLocationPin)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              l10n.orderWithLocationPin,
              style: text.labelSmall?.copyWith(color: colors.primary),
            ),
          ),
      ],
    );
  }
}

/// Línea de pago: método + estado ("Nequi · pagado" / "Pagas al
/// recibir" / "Nequi · pago pendiente").
class _PaymentLine extends StatelessWidget {
  const _PaymentLine({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final label = switch ((order.paymentMethod, order.paymentStatus)) {
      (OrderPaymentMethod.nequi, OrderPaymentStatus.paid) =>
        l10n.orderPaymentNequiPaid,
      (OrderPaymentMethod.nequi, _) => l10n.orderPaymentNequiPending,
      (OrderPaymentMethod.onDelivery, _) => l10n.orderPaymentOnDelivery,
    };
    return Row(
      children: [
        Icon(
          order.paymentMethod == OrderPaymentMethod.nequi
              ? Icons.smartphone_rounded
              : Icons.payments_rounded,
          size: 14,
          color: muted,
        ),
        const SizedBox(width: 6),
        Text(label, style: text.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}
