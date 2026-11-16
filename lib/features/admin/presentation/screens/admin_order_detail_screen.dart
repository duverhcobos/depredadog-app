import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_queue_cubit.dart';
import '../cubit/admin_queue_state.dart';
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
  State<AdminOrderDetailScreen> createState() =>
      _AdminOrderDetailScreenState();
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

  /// Cancela con motivo opcional (§035): el diálogo devuelve null si
  /// se arrepintió; confirmado → cancel mock → toast + pop a la cola.
  Future<void> _confirmCancel(BuildContext context) async {
    final reason = await showAdminOrderCancelDialog(context);
    if (reason == null || !context.mounted) return;
    await context.read<AdminQueueCubit>().cancelOrder(
      widget.order.id,
      reason: reason,
    );
    if (!context.mounted) return;
    AppToast.info(context, AppLocalizations.of(context)!.orderCancelledToast);
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
              final resolved =
                  state.orderById(widget.order.id) ?? widget.order;
              final busy = state.busyOrderIds.contains(resolved.id);
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        const _DetailTitle(),
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
/// texto es el mismo en ambas superficies.
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
