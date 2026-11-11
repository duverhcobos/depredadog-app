import 'package:flutter/material.dart';

import '../../../auth/domain/entities/user.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../../orders/presentation/utils/format_phone.dart';

/// Tarjeta de identidad del tab Perfil (§030): avatar con iniciales
/// + nombre completo + email + celular (fila oculta si `phone` es
/// null). SIN edición — el backend no tiene PATCH /auth/me aún.
/// Radius 16 como la header card del detalle (es la card hero de la
/// pantalla); geometría straddle de la familia.
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({required this.user, super.key});

  final User user;

  /// Iniciales del avatar — primer nombre + primer apellido.
  String get _initials =>
      '${user.firstName.characters.first}${user.firstLastName.characters.first}'
          .toUpperCase();

  /// Nombre completo LatAm — une con espacio solo las piezas no-null
  /// (secondName/secondLastName son opcionales en el registro).
  String get _fullName => [
    user.firstName,
    user.secondName,
    user.firstLastName,
    user.secondLastName,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, c) => Padding(
          padding: EdgeInsets.only(
            left: c.maxWidth * kSignatureStripFraction * kCardStripInset,
            right: blackZoneMargin(c.maxWidth),
          ),
          child: Card(
            margin: EdgeInsets.zero,
            color: colors.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(
                      _initials,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fullName,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: text.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        // Fila oculta si el registro no trajo celular.
                        if (user.phone != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 16,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formatPhone(user.phone!),
                                  style: text.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
