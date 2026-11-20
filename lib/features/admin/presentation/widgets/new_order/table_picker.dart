import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../domain/entities/admin_table.dart';

/// Grid de mesas del cobro (§042): un SelectChip por mesa — libre
/// seleccionable; ocupada muestra "#N" (el consecutivo del pedido
/// vivo que la tiene) y queda disabled; inactiva atenuada disabled
/// (TABLE_NOT_FOUND del backend — no acepta pedidos nuevos).
class TablePicker extends StatelessWidget {
  const TablePicker({
    required this.tables,
    required this.selectedTableId,
    required this.onSelect,
    super.key,
  });

  final List<AdminTable> tables;
  final String? selectedTableId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChipWrap(
      children: [
        for (final t in tables)
          SelectChip(
            // Ocupada → "Mesa 3 · #7" (el dueño ve qué pedido la
            // tiene); libre/inactiva → solo el label.
            label: t.isActive && t.activeOrderNumber != null
                ? '${t.label} · ${l10n.adminNewOrderTableBusy(t.activeOrderNumber!)}'
                : t.label,
            selected: t.id == selectedTableId,
            enabled: t.isFree,
            onTap: () => onSelect(t.id),
          ),
      ],
    );
  }
}
