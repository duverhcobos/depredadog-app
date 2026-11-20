import 'package:flutter/material.dart';

/// Banda negra compartida de chips (§036 carriles / §042 categorías):
/// un bar sólido del negro del scaffold cruza el ancho completo —
/// tapa la franja firma en esta fila, así que nada pinta sobre
/// mostaza (excepción §034c). Los chips van CENTRADOS: el Row se
/// centra en el viewport cuando caben; al desbordar el scroll
/// horizontal sigue funcionando y el consumidor centra el chip
/// activo con Scrollable.ensureVisible sobre su contexto.
class AdminChipBand extends StatelessWidget {
  const AdminChipBand({required this.children, super.key});

  /// Chips en orden — el consumidor decide separadores.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      // La banda — negro puro del scaffold, ancho completo.
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            // minWidth = viewport: el Row se centra cuando los
            // chips caben; al desbordar conserva su ancho real
            // y el scroll horizontal sigue funcionando.
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
