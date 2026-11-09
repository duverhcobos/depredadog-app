import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/presentation/widgets/custom_text_field.dart';
import '../../cubit/checkout_cubit.dart';
import '../../cubit/checkout_state.dart';

/// Celular de quién recibe el pedido (§024 — solo domicilio).
/// Espejo del campo Nequi (payment_block): CustomTextField +
/// keyboardType.phone + digitsOnly + LengthLimiting(10) +
/// AutofillHints.telephoneNumber. NO usa PhoneInput Formz — ese es el
/// idioma del registro; el checkout valida plano en el cubit.
class ContactPhoneField extends StatefulWidget {
  const ContactPhoneField({super.key});

  @override
  State<ContactPhoneField> createState() => _ContactPhoneFieldState();
}

class _ContactPhoneFieldState extends State<ContactPhoneField> {
  late final TextEditingController _phone;
  late final FocusNode _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Siembra desde el estado (mismo patrón del landmark/Nequi): el
    // bloque se desmonta al alternar Local↔Domicilio y el controller
    // se recrea — sin esto el texto seguía en el cubit pero el campo
    // reaparecía vacío y podía validar un contacto invisible.
    _phone = TextEditingController(
      text: context.read<CheckoutCubit>().state.contactPhone,
    );
  }

  @override
  void dispose() {
    _phone.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<CheckoutCubit>();
    final state = cubit.state;
    return BlocListener<CheckoutCubit, CheckoutState>(
      // Foco al campo inválido tras un confirm fallido — patrón
      // login/register (revisor-ui). El punto de referencia va antes
      // en la pantalla: si él también falló se queda con el foco.
      listenWhen: (prev, curr) =>
          !prev.showContactPhoneError && curr.showContactPhoneError,
      listener: (context, state) {
        if (state.showAddressError &&
            state.addressId == kCheckoutNewAddressId &&
            state.newLandmark.trim().isEmpty) {
          return;
        }
        _phoneFocus.requestFocus();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: CustomTextField(
          label: l10n.checkoutContactPhoneLabel,
          controller: _phone,
          focusNode: _phoneFocus,
          hintText: l10n.checkoutContactPhoneHint,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          // Celular colombiano (misma regla del registro/Nequi): solo
          // dígitos, máx 10 — el formato ^3\d{9}$ lo valida el cubit
          // al confirmar.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          errorText: state.showContactPhoneError
              ? l10n.checkoutContactPhoneRequired
              : null,
          onChanged: cubit.contactPhoneChanged,
        ),
      ),
    );
  }
}
