import '../../domain/entities/admin_table.dart';

/// JSON de GET /admin/tables — un renglón por mesa.
class AdminTableModel extends AdminTable {
  AdminTableModel.fromJson(Map<String, dynamic> json)
    : super(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? false,
        activeOrderNumber: json['activeOrderNumber'] as int?,
      );
}
