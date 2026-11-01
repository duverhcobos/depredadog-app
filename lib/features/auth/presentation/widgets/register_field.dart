import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import 'form_field.dart';

/// Campo del wizard de registro: subclase fina de `FormBlocField` fijada
/// a `RegisterCubit`/`RegisterState` — conserva el nombre y call sites de
/// la propuesta 009 tras la generalización de la propuesta 011.
class RegisterField extends FormBlocField<RegisterCubit, RegisterState> {
  const RegisterField({
    super.key,
    required super.label,
    required super.controller,
    required super.focusNode,
    required super.errorText,
    required super.onChanged,
    super.obscure,
    super.suffix,
    super.hintText,
    super.helperText,
    super.prefixIcon,
    super.keyboardType,
    super.textCapitalization,
    super.textInputAction,
    super.autofillHints,
    super.inputFormatters,
    super.onFieldSubmitted,
  });
}
