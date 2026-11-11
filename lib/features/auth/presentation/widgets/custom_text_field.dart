import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SOLID (SRP): campo de formulario del proyecto — label externo arriba,
/// icono prefijo, error reservado abajo (helperText ' ' para que el error
/// no re-fluja el formulario — flutter-building-forms regla 9).
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.helperText = ' ',
    this.enabled = true,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? errorText;

  /// Texto de ayuda persistente bajo el campo. Default `' '` (un espacio):
  /// reserva la línea de error para que mostrar `errorText` no re-fluya
  /// el formulario. Si hay error, Material pinta el error en su lugar.
  final String? helperText;

  /// `false` → campo deshabilitado (gris M3) — para datos visibles que
  /// no se editan (ej. el correo del form "Mis datos", §030.1).
  final bool enabled;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          // Reserva espacio: errorText o helper ' ' ocupan la misma línea.
          // El error lo pinta inputDecorationTheme (M3 usa colorScheme.error)
          // — nada de overrides por campo (forms skill 5).
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
            helperText: helperText,
          ),
        ),
      ],
    );
  }
}
