import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/catalog_assets.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/product_image.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';
import 'admin_elapsed_text.dart';
import 'admin_order_action.dart';
import 'admin_order_chips.dart';

/// Card straddle del pedido en la cola del local (§034 — mismo gesto
/// firma de la familia orders: la imagen del primer ítem flota a
/// caballo del borde izquierdo). Contenido del AdminOrderResponseDto:
/// chip de servicio + etiqueta de canal en la esquina (+ chip de
/// estado solo fuera de carril — showStatusChip, §036), cliente
/// (nombre o "En el local · Mesa N"), tiempo transcurrido, resumen
/// de ítems, método de pago + chip de pago y total. §035 — fila inferior con el botón de la
/// siguiente acción real (matriz estado×pago, solo en pedidos vivos);
/// tap de la card → detalle /admin/:id (el botón no propaga: es hijo
/// del InkWell con su propio gesto). El terminal queda de solo
/// lectura — sin botón en el historial.
class AdminOrderCard extends StatelessWidget {
  const AdminOrderCard({
    required this.order,
    this.busy = false,
    this.showStatusChip = false,
    super.key,
  });

  final AdminOrder order;

  /// Operación mock en vuelo sobre ESTE pedido — spinner inline del
  /// botón (state.busyOrderIds del cubit; la pantalla lo resuelve).
  final bool busy;

  /// Muestra el chip de estado arriba a la derecha. OFF en los
  /// carriles del kanban (decisión del dueño §036): si la card ya
  /// vive en "Pendiente", repetir "Pendiente" en cada card es
  /// ruido — el carril ES el estado. ON en el historial y en
  /// cualquier lista plana sin contexto de carril.
  final bool showStatusChip;

  /// Alto del recuadro flotante — 80px, el mismo de active_order_card
  /// y cart_item_tile (consistencia de la familia straddle).
  static const double _imageSize = 80;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
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
                      '${AuthGuard.adminRoute}/${order.id}',
                      extra: order,
                    ),
                    child: Padding(
                      // Texto anclado al marco: borde derecho del
                      // recuadro + gap (regla de la familia).
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
                              AdminServiceChip(
                                serviceType: order.serviceType,
                              ),
                              // Canal en la esquina — susurro sin
                              // píldora (§036, decisión del dueño);
                              // cede en angosto (elipsiza, no
                              // revienta la fila).
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: AdminChannelTag(
                                    channel: order.channel,
                                  ),
                                ),
                              ),
                              if (showStatusChip) ...[
                                const SizedBox(width: 8),
                                AdminOrderStatusChip(status: order.status),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          _CustomerLine(order: order),
                          const SizedBox(height: 8),
                          _ItemsSummary(order: order),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _PaymentLine(order: order)),
                              const SizedBox(width: 8),
                              Text(
                                formatCop(order.total),
                                // Cancelado = plata que no entró —
                                // el mostaza w800 lo gritaba como
                                // caja viva (revisor-estetico §035).
                                style: text.titleSmall?.copyWith(
                                  color: order.status == OrderStatus.cancelled
                                      ? colors.onSurface.withValues(alpha: 0.5)
                                      : colors.primary,
                                  fontWeight:
                                      order.status == OrderStatus.cancelled
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          // La acción es el punto de la pantalla —
                          // un toque avanza sin abrir nada; solo en
                          // pedidos vivos (el historial es lectura).
                          // Nequi sin confirmar: rótulo de espera en
                          // el mismo slot — el webhook manda, no el
                          // dueño (§036).
                          if (!order.isTerminal) ...[
                            const SizedBox(height: 10),
                            order.awaitsWebhook
                                ? AdminOrderAwaitingHint(order: order)
                                : AdminOrderActionButton(
                                    order: order,
                                    busy: busy,
                                  ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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

/// Resumen "2× El Depredador, 1× Papas" con recorte honesto: si no
/// cabe en 2 líneas muestra lo que quepa y cierra con "+N más"
/// apagado — en la cola el dueño distingue un pedido de 2 ítems de
/// uno de 7 sin abrir el detalle (decisión §034 — el ellipsis solo
/// escondía cuántos faltaban). La semántica expone la lista
/// completa como antes.
class _ItemsSummary extends StatelessWidget {
  const _ItemsSummary({required this.order});

  final AdminOrder order;

  static const int _maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    final names = [for (final i in order.items) '${i.quantity}× ${i.name}'];
    final full = names.join(', ');
    return LayoutBuilder(
      builder: (context, c) {
        var shown = names.length;
        String? more;
        if (!_fits(context, full, style, c.maxWidth)) {
          for (var k = names.length - 1; k >= 0; k--) {
            more = l10n.adminOrderItemsMore(names.length - k);
            final candidate = k == 0
                ? more
                : '${names.take(k).join(', ')}, $more';
            if (_fits(context, candidate, style, c.maxWidth)) {
              shown = k;
              break;
            }
          }
        }
        return Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: names.take(shown).join(', ')),
              if (more != null) ...[
                if (shown > 0) const TextSpan(text: ', '),
                TextSpan(
                  text: more,
                  style: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
          maxLines: _maxLines,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: full,
        );
      },
    );
  }

  bool _fits(BuildContext context, String s, TextStyle? style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: s, style: style),
      maxLines: _maxLines,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    return !painter.didExceedMaxLines;
  }
}

/// Fila cliente: nombre del registrado o "En el local · Mesa N"
/// (tableLabel) / "En el local" de mostrador + "hace X min" a la
/// derecha — la frescura del pedido es el dato de operación.
class _CustomerLine extends StatelessWidget {
  const _CustomerLine({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final name = order.customerName;
    final table = order.tableLabel;
    final label =
        name ??
        (table != null
            ? l10n.adminOrderAtTable(table)
            : l10n.adminOrderInHouse);
    return Row(
      children: [
        Icon(
          name != null
              ? Icons.person_outline_rounded
              : Icons.table_restaurant_outlined,
          size: 15,
          color: muted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        AdminElapsedText(
          placedAt: order.placedAt,
          style: text.labelSmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

/// Fila de pago: método (Efectivo/Transf./Nequi) + chip del estado
/// del pago — en la cola el "¿me pagó?" es dato de primer nivel.
class _PaymentLine extends StatelessWidget {
  const _PaymentLine({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    // sync_alt = transferencia manual, wallet = Nequi dentro de la
    // app — smartphone ya significa el canal Online en la fila de
    // chips (revisor-ui, doble significado del glifo en la card).
    final (icon, methodLabel) = switch (order.paymentMethod) {
      AdminPaymentMethod.cash => (
        Icons.payments_rounded,
        l10n.adminPaymentCash,
      ),
      AdminPaymentMethod.transfer => (
        Icons.sync_alt_rounded,
        l10n.adminPaymentTransfer,
      ),
      AdminPaymentMethod.nequi => (
        Icons.account_balance_wallet_rounded,
        l10n.adminPaymentNequi,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 13, color: muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            methodLabel,
            style: text.bodySmall?.copyWith(color: muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        // En estado terminal cancelado no hay nada que cobrar — el
        // chip "Pago pendiente" gritaba una deuda fantasma
        // (revisor-ui).
        if (order.status != OrderStatus.cancelled)
          AdminPaymentStatusChip(status: order.paymentStatus),
      ],
    );
  }
}
