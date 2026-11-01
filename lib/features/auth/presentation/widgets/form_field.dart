import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'custom_text_field.dart';

/// Un BlocBuilder por campo: rebuild solo cuando cambia SU texto de error
/// o SU flag de obscure (ojo) — el valor tipeado lo pinta el controller,
/// no el state, así que no hace falta observarlo.
///
/// Genérico sobre `<B, S>` (extraído de `RegisterField` en la propuesta
/// 011): cualquier cubit de formulario puede usarlo tipando su state —
/// `RegisterField` queda como subclase fija a `RegisterCubit` y los pasos
/// de /forgot-password lo usan con `ForgotPasswordCubit`.
class FormBlocField<B extends StateStreamable<S>, S> extends StatelessWidget {
  const FormBlocField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
    this.obscure,
    this.suffix,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.keyboardType,
    this.textCapitalization,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? Function(S) errorText;
  final ValueChanged<String> onChanged;
  final bool Function(S)? obscure;
  final Widget Function(BuildContext, S)? suffix;
  final String? hintText;
  final String? helperText;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization? textCapitalization;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final obscureFn = obscure;
    return BlocBuilder<B, S>(
      buildWhen: (p, c) =>
          errorText(p) != errorText(c) ||
          (obscureFn != null && obscureFn(p) != obscureFn(c)),
      builder: (context, state) => CustomTextField(
        key: key,
        label: label,
        controller: controller,
        focusNode: focusNode,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffix?.call(context, state),
        obscureText: obscure?.call(state) ?? false,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization ?? TextCapitalization.none,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        inputFormatters: inputFormatters,
        errorText: errorText(state),
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }
}
