import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/widgets/app_toast.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../../orders/presentation/utils/format_phone.dart';
import '../../../domain/entities/admin_order.dart';

/// Sección "Entrega" del detalle admin (§037) — lo que el dueño
/// necesita para sacar el domicilio: etiqueta + punto de referencia
/// (tinta plena — la zona no tiene nomenclatura formal, el landmark
/// ES la dirección) + barrio + pin de Maps (toca abre Maps con el
/// punto, el ícono copia el enlace) y el celular de quién recibe
/// (tocar la fila copia el número). Pickup dice "lo recogen
/// en el local" + el teléfono del cliente cuando existe — si nadie
/// viene por el pedido, el dueño tiene a quién llamar (regla del
/// fantasma §036). dineIn no renderiza — la mesa ya sale en el
/// header.
class AdminOrderDeliverySection extends StatelessWidget {
  const AdminOrderDeliverySection({required this.order, super.key});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    if (order.serviceType == AdminServiceType.dineIn) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final isDelivery = order.serviceType == AdminServiceType.delivery;
    return CustomizationSection(
      title: l10n.adminOrderDetailDeliverySection,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDelivery) ...[
                // La etiqueta ("Casa") susurra — para quien entrega
                // el landmark ES la dirección (revisor-ui §037).
                if (order.addressLabel != null)
                  Text(
                    order.addressLabel!,
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
                if (order.landmark != null)
                  Text(
                    order.landmark!,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (order.neighborhood != null)
                  Text(
                    order.neighborhood!,
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
                if (order.hasLocationPin)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _PinRow(
                      order: order,
                      onCopy: () async {
                        final link = _mapsLink(order);
                        if (link == null) return;
                        await Clipboard.setData(ClipboardData(text: link));
                        if (context.mounted) {
                          AppToast.success(
                            context,
                            l10n.adminOrderPinCopied,
                          );
                        }
                      },
                    ),
                  ),
              ] else
                Text(
                  l10n.adminOrderPickupAtStore,
                  style: text.bodyMedium?.copyWith(color: muted),
                ),
              // §024 — a quién llamar si nadie sale (delivery) o si
              // nadie viene a recoger (pickup). Tap copia.
              if (order.contactPhone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _PhoneRow(
                    phone: order.contactPhone!,
                    onCopy: () async {
                      await Clipboard.setData(
                        ClipboardData(text: order.contactPhone!),
                      );
                      if (context.mounted) {
                        AppToast.success(
                          context,
                          l10n.adminOrderPhoneCopied,
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Enlace "abrir en Maps" del pin del cliente: si el pedido trae el
/// link compartido real (maps.app.goo.gl) se usa verbatim; si solo
/// hay coordenadas se reconstruye la query; sin nada queda null y
/// la fila es solo informativa (§037 — "utiliza esa url").
String? _mapsLink(AdminOrder order) {
  final url = order.locationUrl;
  if (url != null && url.trim().isNotEmpty) return url.trim();
  final lat = order.locationLat, lng = order.locationLng;
  if (lat == null || lng == null) return null;
  return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
}

/// El pin del cliente — con coordenadas toca la fila abre Maps con
/// el punto (el dueño navega al domicilio) y el ícono copia el
/// enlace para compartirlo; sin coordenadas queda informativo.
class _PinRow extends StatelessWidget {
  const _PinRow({required this.order, required this.onCopy});

  final AdminOrder order;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final link = _mapsLink(order);
    final label = Text(
      l10n.orderWithLocationPin,
      style: text.bodySmall?.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w600,
      ),
    );
    if (link == null) {
      return Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          label,
        ],
      );
    }
    final uri = Uri.parse(link);
    return Semantics(
      button: true,
      label: l10n.adminOrderOpenPin,
      child: InkWell(
        onTap: () => unawaited(
          launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 15,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(child: label),
              IconButton(
                onPressed: onCopy,
                icon: Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: colors.primary.withValues(alpha: 0.8),
                ),
                tooltip: l10n.adminOrderCopyPin,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.phone, required this.onCopy});

  final String phone;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    return Semantics(
      button: true,
      label: l10n.adminOrderCopyPhone,
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          // Target ≥44dp — cocina con las manos ocupadas no apunta a
          // una línea fina (revisor-ui §037).
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
          children: [
            Icon(Icons.phone_rounded, size: 16, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.orderContactPhone(formatPhone(phone)),
                style: text.bodyMedium?.copyWith(color: muted),
              ),
            ),
            Icon(
              Icons.copy_rounded,
              size: 15,
              color: colors.primary.withValues(alpha: 0.8),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
