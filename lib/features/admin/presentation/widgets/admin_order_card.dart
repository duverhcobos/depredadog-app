import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/catalog_assets.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/product_image.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';
import '../utils/format_elapsed.dart';
import 'admin_order_chips.dart';

/// Card straddle del pedido en la cola del local (§034 — mismo gesto
/// firma de la familia orders: la imagen del primer ítem flota a
/// caballo del borde izquierdo). Contenido del AdminOrderResponseDto:
/// chip de canal + chip de estado, cliente (nombre o "En el local ·
/// Mesa N"), tiempo transcurrido, resumen de ítems, método de pago +
/// chip de pago y total. Tap → toast del detalle (ciclo 2 — acá no
/// hay acciones todavía, mock de fase 1).
class AdminOrderCard extends StatelessWidget {
  const AdminOrderCard({required this.order, super.key});

  final AdminOrder order;

  /// Alto del recuadro flotante — 80px, el mismo de active_order_card
  /// y cart_item_tile (consistencia de la familia straddle).
  static const double _imageSize = 80;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                    onTap: () =>
                        AppToast.info(context, l10n.adminOrderDetailSoon),
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
                              AdminChannelChip(channel: order.channel),
                              const Spacer(),
                              AdminOrderStatusChip(status: order.status),
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
                                style: text.titleSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
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
        _ElapsedText(placedAt: order.placedAt, muted: muted),
      ],
    );
  }
}

/// "Hace N min" que se re-computa solo — esta pantalla vive ABIERTA
/// todo el día en el local: sin tick propio la frescura se congela y
/// el dato de operación miente en silencio (revisor-ui §034). Timer
/// de 60s pausado cuando el árbol no está visible (TickerMode: el
/// IndexedStack del shell deja los demás tabs deshabilitados).
class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.placedAt, required this.muted});

  final DateTime placedAt;
  final Color muted;

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (enabled && _timer == null) {
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => setState(() {}),
      );
    } else if (!enabled) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      formatElapsed(widget.placedAt, l10n),
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: widget.muted),
    );
  }
}

/// Fila de pago: método (Efectivo/Transferencia) + chip del estado
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
    final cash = order.paymentMethod == AdminPaymentMethod.cash;
    return Row(
      children: [
        Icon(
          // sync_alt para transferencia — smartphone ya significa el
          // canal Online en la fila de chips (revisor-ui, doble
          // significado del glifo en la misma card).
          cash ? Icons.payments_rounded : Icons.sync_alt_rounded,
          size: 13,
          color: muted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            cash ? l10n.adminPaymentCash : l10n.adminPaymentTransfer,
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
