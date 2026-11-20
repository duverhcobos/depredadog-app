import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/failures/admin_failure.dart';
import '../cubit/admin_queue_cubit.dart';
import '../cubit/admin_queue_state.dart';
import '../utils/kitchen_order_data.dart';
import '../widgets/kitchen_item_card.dart';
import '../widgets/order_detail/admin_order_cancel_dialog.dart';
import '../widgets/order_detail/admin_order_delivery_section.dart';
import '../widgets/order_detail/admin_order_detail_actions.dart';
import '../widgets/order_detail/admin_order_detail_header.dart';
import '../widgets/order_detail/admin_order_detail_items.dart';
import '../widgets/order_detail/admin_order_detail_payment.dart';
import '../widgets/order_detail/admin_order_note_section.dart';

/// Detalle del pedido admin (§035 — hija `/admin/:id`, slideUp como
/// el detalle del cliente §023): el `extra` de la ruta es el snapshot
/// de la card; la orden viva se resuelve por id del AdminQueueCubit
/// SINGLETON — el detalle opera sobre la MISMA instancia de la cola
/// y volver atrás muestra la cola ya actualizada. Contenido: header
/// (chips canal+estado, frescura, cliente/mesa, #id corto), ítems
/// COMPLETOS + total, pago con "Registrar pago" si está pendiente, y el
/// bloque de acciones (avance por matriz + cancelar con motivo).
/// Un terminal se queda abierto en solo lectura (las acciones se
/// repliegan solas); tras cancelar hay pop a la cola — la orden ya
/// no existe para mirarla. §039: al montar, initState dispara
/// refreshOrder — GET /admin/orders/:id inyecta la comanda completa
/// (los modifiers que el listado omite) con el estado más fresco.
class AdminOrderDetailScreen extends StatefulWidget {
  const AdminOrderDetailScreen({required this.order, super.key});

  /// Snapshot de la card que abrió el detalle — fallback si la orden
  /// saliera de ambas bandejas del state.
  final AdminOrder order;

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Post-frame: el cubit es singleton del shell — `context.read`
    // seguro; cubre cualquier entry point, no solo el tap de la card.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminQueueCubit>().refreshOrder(widget.order.id);
    });
  }

  /// Cancela con motivo opcional (§035/§040): el diálogo devuelve
  /// null si se arrepintió; confirmado → PATCH status cancelled —
  /// SOLO si el backend aceptó hay toast + pop a la cola (un 409
  /// deja el detalle abierto: el pedido no se canceló).
  Future<void> _confirmCancel(BuildContext context) async {
    final reason = await showAdminOrderCancelDialog(context);
    if (reason == null || !context.mounted) return;
    final failure = await context.read<AdminQueueCubit>().cancelOrder(
      widget.order.id,
      reason: reason,
    );
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (failure != null) {
      AppToast.error(
        context,
        failure is AdminConflictFailure
            ? l10n.adminToastActionRejected
            : l10n.adminToastActionFailed,
      );
      return;
    }
    AppToast.info(context, l10n.orderCancelledToast);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<AdminQueueCubit, AdminQueueState>(
            builder: (context, state) {
              // La orden viva del cubit — tras cada acción el detalle
              // refleja el estado nuevo sin re-navegar (un terminal
              // sigue encontrándose en history).
              final resolved = state.orderById(widget.order.id) ?? widget.order;
              final busy = state.busyOrderIds.contains(resolved.id);
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        _DetailTitle(order: resolved),
                        AdminOrderDetailHeader(order: resolved),
                        AdminOrderNoteSection(order: resolved),
                        AdminOrderDeliverySection(order: resolved),
                        AdminOrderDetailItems(order: resolved),
                        AdminOrderDetailPayment(order: resolved, busy: busy),
                      ],
                    ),
                  ),
                  // Footer fijo opaco (decisión del usuario §035 sobre
                  // el DIRECCION del revisor-estetico): las acciones
                  // siempre al pulgar y con contraste pleno — sueltas
                  // en el scroll el primario se fundía con la franja
                  // mostaza y quedaba BAJO el fold en pedidos largos
                  // (la Mesa 5, el caso que este detalle resuelve).
                  // Patrón Column[ListView + footer] del cart/checkout.
                  if (!resolved.isTerminal)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          top: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: AdminOrderDetailActions(
                            order: resolved,
                            busy: busy,
                            onCancel: () => _confirmCancel(context),
                          ),
                        ),
                      ),
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
/// cart/checkout/detalle de cliente: PRIMER hijo del ListView (sale
/// al bajar, vuelve al subir). Reutiliza la clave del cliente — el
/// texto es el mismo en ambas superficies. A su derecha va el ícono
/// compartir (§043 — mismo patrón del 🕐 de Cocina: ícono a la
/// derecha del título dentro de la misma fila) que lanza el share
/// sheet con las cards PNG del pedido resuelto (§043 v2).
class _DetailTitle extends StatefulWidget {
  const _DetailTitle({required this.order});

  /// La orden resuelta del cubit — con sus modifiers ya hidratados
  /// arma la comanda que sale por WhatsApp (§043).
  final AdminOrder order;

  @override
  State<_DetailTitle> createState() => _DetailTitleState();
}

class _DetailTitleState extends State<_DetailTitle> {
  /// El render PNG + share sheet toman ~1s — durante el vuelo el
  /// ícono queda disabled con spinner (revisor-ui §043: sin
  /// guardia, un doble-tap encolaba dos renders y dos sheets).
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await shareKitchenItemCards(
        context,
        KitchenOrderData.fromAdminOrder(
          widget.order,
          AppLocalizations.of(context)!,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

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
          child: Row(
            children: [
              Expanded(
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
              IconButton(
                onPressed: _sharing ? null : () => unawaited(_share()),
                icon: _sharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_rounded),
                tooltip: l10n.adminShareWhatsAppTooltip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
