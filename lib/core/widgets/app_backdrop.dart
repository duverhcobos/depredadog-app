import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Backdrop de marca: degradado ketchup → mostaza ocupando el
/// tercio superior de la pantalla. Las screens lo ponen tras su contenido:
/// Scaffold → AppBackdrop → listeners → scroll (bloc-patterns).
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: ColoredBox(color: scheme.surface),
          ),
        ],
      ),
    );
  }
}

/// Icono de marca reutilizable — la "flama" de Depredadog.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.local_fire_department_rounded,
      size: size,
      color: AppColors.onBrandGradient,
    );
  }
}
