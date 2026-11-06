import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/checkout_state.dart';
import 'checkout_option_row.dart';

/// Sección "Pago" del checkout (§022): radio rows en el idioma
/// OptionRow. Nequi lleva su LOGO oficial sobre tile blanco (§022a) y
/// expone el campo de celular PRELLENADO con el de la cuenta, editable
/// (decisión del usuario — el push puede ir a otra cuenta Nequi);
/// aparece solo con Nequi seleccionado (AnimatedSize, misma física del
/// detalle). La opción contra entrega existe SOLO en domicilio (§022c —
/// el local es prepago: un pedido no recogido ya quedó hecho y nunca
/// se cobró); en su lugar se muestra una nota informativa atenuada.
class PaymentBlock extends StatefulWidget {
  const PaymentBlock({super.key});

  @override
  State<PaymentBlock> createState() => _PaymentBlockState();
}

class _PaymentBlockState extends State<PaymentBlock> {
  late final TextEditingController _phone;
  late final FocusNode _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Prefill desde el estado del cubit (ya trae el phone de la cuenta
    // o '' si no lo registró) — editable a partir de ahí.
    _phone = TextEditingController(
      text: context.read<CheckoutCubit>().state.nequiPhone,
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
    final isNequi = state.paymentMethod == CheckoutPaymentMethod.nequi;
    return BlocListener<CheckoutCubit, CheckoutState>(
      // Foco al campo inválido tras un confirm fallido — patrón
      // login/register (revisor-ui). Si además falló la dirección,
      // ella tiene prioridad (va antes en la pantalla).
      listenWhen: (prev, curr) =>
          !prev.showNequiPhoneError && curr.showNequiPhoneError,
      listener: (context, state) {
        if (state.showAddressError) return;
        _phoneFocus.requestFocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          CheckoutOptionRow(
            // Ícono oficial de Nequi (cuadro magenta + "N", §022b —
            // el usuario lo prefiere al wordmark completo) sobre tile
            // blanco: el trazo #200020 se pierde en el tema oscuro —
            // tile blanco, idioma de los logos de pago. Decorativo
            // para TalkBack: el título "Nequi" ya lo dice.
            leading: ExcludeSemantics(child: const _NequiLogoTile()),
            title: l10n.checkoutPayNequi,
            selected: isNequi,
            onTap: () => cubit.setPaymentMethod(CheckoutPaymentMethod.nequi),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: isNequi
                ? Padding(
                    // Bottom 0: la fila siguiente ya trae su aire —
                    // con 4 quedaba un hueco muerto ~25dp entre el
                    // campo y "Pagar al recibir" (revisor-estetico).
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: CustomTextField(
                      label: l10n.checkoutNequiPhoneLabel,
                      controller: _phone,
                      focusNode: _phoneFocus,
                      hintText: l10n.checkoutNequiPhoneHint,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      // Celular colombiano (misma regla del registro):
                      // solo dígitos, máx 10 — el formato ^3\d{9}$ lo
                      // valida el cubit al confirmar.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      errorText: state.showNequiPhoneError
                          ? l10n.checkoutNequiPhoneError
                          : null,
                      onChanged: cubit.nequiPhoneChanged,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // §022c — regla del negocio: en el LOCAL no existe pago en
          // efectivo (un pedido no recogido ya quedó hecho y nunca se
          // cobró). Solo transferencia: la fila se reemplaza por una
          // nota del mismo idioma del aviso "Domicilio gratis".
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: state.orderType == CheckoutOrderType.pickup
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.checkoutPickupTransferNote,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ),
                      ],
                    ),
                  )
                : CheckoutOptionRow(
                    icon: Icons.payments_rounded,
                    title: l10n.checkoutPayOnDelivery,
                    selected:
                        state.paymentMethod == CheckoutPaymentMethod.onDelivery,
                    onTap: () => cubit.setPaymentMethod(
                      CheckoutPaymentMethod.onDelivery,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Tile blanco con el ícono oficial de Nequi (§022b — el isotipo
/// cuadro+#DA0081 + "N" #200020, recorte del wordmark oficial sobre
/// nequi_logo.svg): el trazo casi negro desaparece sobre el fondo
/// oscuro — el tile blanco es el idioma estándar de logos de pago en
/// temas dark.
class _NequiLogoTile extends StatelessWidget {
  const _NequiLogoTile();

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
    ),
    child: SvgPicture.asset(
      'assets/images/nequi_icon.svg',
      height: 22,
      fit: BoxFit.contain,
    ),
  );
}
