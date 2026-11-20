import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/admin/data/models/admin_table_model.dart';

void main() {
  group('AdminTableModel — GET /admin/tables (§042)', () {
    test('mesa libre: parsea el renglón completo y isFree=true '
        '(activa + activeOrderNumber null)', () {
      final table = AdminTableModel.fromJson(const {
        'id': 't-2',
        'label': 'Mesa 2',
        'isActive': true,
        'activeOrderNumber': null,
      });

      expect(table.id, 't-2');
      expect(table.label, 'Mesa 2');
      expect(table.isActive, isTrue);
      expect(table.activeOrderNumber, isNull);
      expect(table.isFree, isTrue);
    });

    test('mesa ocupada: activeOrderNumber viaja y isFree=false — '
        'queda disabled con el #pedido en el picker', () {
      final table = AdminTableModel.fromJson(const {
        'id': 't-3',
        'label': 'Mesa 3',
        'isActive': true,
        'activeOrderNumber': 7,
      });

      expect(table.activeOrderNumber, 7);
      expect(table.isFree, isFalse);
    });

    test('mesa inactiva: viaja pero isFree=false — no acepta '
        'pedidos nuevos (TABLE_NOT_FOUND del backend)', () {
      final table = AdminTableModel.fromJson(const {
        'id': 't-4',
        'label': 'Mesa 4',
        'isActive': false,
        'activeOrderNumber': null,
      });

      expect(table.isActive, isFalse);
      expect(table.isFree, isFalse);
    });

    test('defaults defensivos: label/isActive caen a vacío/false '
        'cuando el JSON los omite', () {
      final table = AdminTableModel.fromJson(const {'id': 't-9'});

      expect(table.label, '');
      expect(table.isActive, isFalse);
      expect(table.activeOrderNumber, isNull);
      expect(table.isFree, isFalse);
    });
  });
}
