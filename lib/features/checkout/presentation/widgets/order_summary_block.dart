import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/checkout_state.dart';

/// Sección "Tu pedido" del checkout (§022): resumen compacto — una
/// línea `N× Nombre` … `lineTotal` por ítem (sin modificadores — ya se
/// auditaron en el carrito), hairline, Subtotal, fila Domicilio solo en
/// delivery (fee 0 → "Gratis" — el domicilio es gratis y debe decirse,
/// §022a; SIN mínimo) y TOTAL en Anton primary w800.
class OrderSummaryBlock extends StatelessWidget {
  const OrderSummaryBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cartState = context.watch<CartCubit>().state;
    final checkout = context.watch<CheckoutCubit>();
    final isDelivery = checkout.state.orderType == CheckoutOrderType.delivery;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (final item in cartState.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}× ${item.productName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Nombre con la voz de producto (Anton) —
                      // misma firma tipográfica del cart tile.
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatCop(item.lineTotal),
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          _TotalRow(
            label: l10n.cartSubtotalLabel,
            value: formatCop(cartState.subtotal),
          ),
          if (isDelivery)
            _TotalRow(
              label: l10n.checkoutDeliveryFeeLabel,
              // Domicilio gratis → la fila lo DICE ("Gratis" en
              // primary, §022a) en vez de mostrar $0 o esconderse.
              value: checkout.deliveryFee == 0
                  ? l10n.checkoutDeliveryFree
                  : formatCop(checkout.deliveryFee),
              valueAccent: checkout.deliveryFee == 0,
            ),
          const SizedBox(height: 2),
          _TotalRow(
            label: l10n.detailTotalLabel,
            value: formatCop(checkout.total),
            highlight: true,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.valueAccent = false,
  });

  final String label;
  final String value;

  /// La fila TOTAL — Anton primary w800 (§022); el resto son filas
  /// secundarias bodySmall/bodyMedium.
  final bool highlight;

  /// Valor en primary ("Gratis" del domicilio, §022a) — acento
  /// positivo, sin la jerarquía del TOTAL.
  final bool valueAccent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: highlight
                  ? text.titleSmall?.copyWith(fontWeight: FontWeight.w800)
                  : text.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
            ),
          ),
          Text(
            value,
            style: highlight
                ? text.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  )
                : text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueAccent ? colors.primary : null,
                  ),
          ),
        ],
      ),
    );
  }
}
