import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../domain/entities/admin_order.dart';

/// Observación del cliente (§037) — sección propia para que la nota
/// no se pierda entre ítems y pago: "sin picante, es para el niño" es
/// instrucción de cocina. No renderiza sin nota.
class AdminOrderNoteSection extends StatelessWidget {
  const AdminOrderNoteSection({required this.order, super.key});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final note = order.note;
    if (note == null || note.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    return CustomizationSection(
      title: l10n.orderDetailNoteSection,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 16, color: muted),
              const SizedBox(width: 8),
              Expanded(
                // w600 — la nota "ordena" en cocina, no "informa"
                // (revisor-estetico §037).
                child: Text(
                  note,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
