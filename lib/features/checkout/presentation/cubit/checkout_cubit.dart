import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../domain/entities/checkout_store.dart';
import '../../domain/entities/saved_address.dart';
import 'checkout_state.dart';

/// Datos mock del checkout (§022, solo presentación). Las direcciones
/// vendrán de `GET /addresses` (backend 014) y el store de
/// `GET /store/config` (backend 013, ya existe).
/// La zona del negocio no tiene nomenclatura de calles (§022a,
/// decisión del usuario): el local y las entregas se guían por puntos
/// de referencia, y el DOMICILIO ES GRATIS — el fee queda en 0 y la UI
/// lo muestra como "Gratis" (especificarlo es parte del requisito).
const kCheckoutMockStore = CheckoutStore(
  name: 'Depredadog',
  address: 'Costado norte del parque principal',
  deliveryFee: 0,
);

const kCheckoutMockAddresses = <SavedAddress>[
  SavedAddress(
    id: 'addr-casa',
    label: 'Casa',
    landmark: 'Casa blanca frente a la cancha',
    neighborhood: 'Vereda El Carmen',
    type: SavedAddressType.home,
  ),
  SavedAddress(
    id: 'addr-trabajo',
    label: 'Trabajo',
    landmark: 'Segundo local del puente hacia arriba',
    neighborhood: 'Centro',
    type: SavedAddressType.work,
  ),
];

/// SOLID (SRP): único dueño del estado de la pantalla de checkout
/// (§022) — tipo de pedido, dirección, pago, nota y el delay mock de
/// confirmación. Es FACTORY por apertura (estado de pantalla, no
/// compartido): cada push a /checkout crea una instancia fresca.
///
/// LEE el CartCubit para ítems/subtotal/total — NUNCA lo modifica: la
/// confirmación real vaciará el carrito en §015; aquí la pantalla lo
/// limpia tras el diálogo de éxito (flujo simulado).
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this.cartCubit,
    required AuthSession authSession,
    this.confirmDelay = const Duration(milliseconds: 800),
  }) : super(
         CheckoutState(
           savedAddresses: kCheckoutMockAddresses,
           store: kCheckoutMockStore,
           // Prefills que reducen fricción (§022): primera dirección
           // guardada para cuando elija domicilio; celular de la cuenta
           // para el push de Nequi (vacío si no lo registró).
           addressId: kCheckoutMockAddresses.first.id,
           nequiPhone: authSession.currentUser?.phone ?? '',
         ),
       );

  /// Fuente de ítems/subtotal (solo lectura — §022: el cubit NUNCA lo
  /// muta; la pantalla lo limpia tras el diálogo de éxito).
  final CartCubit cartCubit;

  /// Duración del delay mock de confirmación — inyectable para tests.
  final Duration confirmDelay;

  /// Celular colombiano: 10 dígitos iniciando en 3 — MISMA regla que
  /// `PhoneInput` del registro (propuesta 009, ^3\d{9}$).
  static final RegExp _colombianMobile = RegExp(r'^3\d{9}$');

  /// Totales derivados del carrito + tipo de pedido. En pickup la fila
  /// del fee no se muestra y no se cobra (§022 — sin mínimo de
  /// domicilio, el fee es fijo y punto).
  int get subtotal => cartCubit.state.subtotal;
  int get deliveryFee => state.orderType == CheckoutOrderType.delivery
      ? state.store.deliveryFee
      : 0;
  int get total => subtotal + deliveryFee;

  void setOrderType(CheckoutOrderType type) {
    if (state.confirmInProgress) return;
    emit(
      state.copyWith(
        orderType: type,
        // La sección de dirección cambia con el tipo — el error viejo
        // no debe sobrevivir al toggle.
        showAddressError: false,
        // §022c — regla del negocio: en el LOCAL no hay pago en
        // efectivo (si el cliente no pasa por el pedido, ya quedó
        // hecho y nunca se cobró). Solo transferencia (Nequi). Si
        // venía "al recibir" desde domicilio, se corrige aquí.
        paymentMethod: type == CheckoutOrderType.pickup
            ? CheckoutPaymentMethod.nequi
            : state.paymentMethod,
      ),
    );
  }

  void selectAddress(String id) {
    if (state.confirmInProgress) return;
    emit(state.copyWith(addressId: id, showAddressError: false));
  }

  /// Tap en "Nueva ubicación" (§022d — toggle de SOLO
  /// expandir/colapsar, NUNCA desmarca):
  /// - no seleccionada → la selecciona y despliega el form;
  /// - seleccionada → alterna `newAddressExpanded` (colapsa/reabre)
  ///   conservando la selección. Desmarcar solo pasa al tocar otra
  ///   dirección. Los campos tipeados sobreviven al colapso.
  void toggleNewAddress() {
    if (state.confirmInProgress) return;
    if (state.addressId != kCheckoutNewAddressId) {
      emit(
        state.copyWith(
          addressId: kCheckoutNewAddressId,
          newAddressExpanded: true,
          showAddressError: false,
        ),
      );
      return;
    }
    emit(state.copyWith(newAddressExpanded: !state.newAddressExpanded));
  }

  void setNewAddressType(SavedAddressType type) =>
      emit(state.copyWith(newAddressType: type));

  void newAddressLabelChanged(String value) =>
      emit(state.copyWith(newAddressLabel: value));

  void newLandmarkChanged(String value) =>
      emit(state.copyWith(newLandmark: value, showAddressError: false));

  void newNeighborhoodChanged(String value) =>
      emit(state.copyWith(newNeighborhood: value, showAddressError: false));

  /// Adjunta/quita el pin de Google Maps del PEDIDO (§022d — sirve
  /// para dirección nueva o guardada: el repartidor usa el punto
  /// exacto sin importar cuál referencia esté marcada). MOCK: en la
  /// integración real abrirá el selector de ubicación / compartir
  /// desde Maps y guardará lat/lng de verdad.
  void attachDeliveryLocation() => emit(
    state.copyWith(deliveryLocationLink: () => kCheckoutMockLocationLink),
  );

  void removeDeliveryLocation() =>
      emit(state.copyWith(deliveryLocationLink: () => null));

  void toggleSaveNewAddress() =>
      emit(state.copyWith(saveNewAddress: !state.saveNewAddress));

  void setPaymentMethod(CheckoutPaymentMethod method) {
    if (state.confirmInProgress) return;
    // §022c — defensa: "al recibir" no existe en el local aunque
    // alguien la invoque directo (la UI ni la muestra).
    if (method == CheckoutPaymentMethod.onDelivery &&
        state.orderType == CheckoutOrderType.pickup) {
      return;
    }
    emit(state.copyWith(paymentMethod: method));
  }

  void nequiPhoneChanged(String value) =>
      emit(state.copyWith(nequiPhone: value, showNequiPhoneError: false));

  void noteChanged(String value) => emit(state.copyWith(note: value));

  /// Validación al confirmar (§022 — solo dos reglas, sin mínimo):
  /// delivery exige ubicación elegida o form nuevo con su punto de
  /// referencia (§022a — barrio/pin opcionales); Nequi exige celular
  /// colombiano válido.
  /// Inválido → errores INLINE (flags, la UI los pinta bajo el campo/
  /// sección); válido → delay mock → `orderConfirmed` dispara el
  /// diálogo de éxito.
  Future<void> confirm() async {
    if (state.confirmInProgress || state.orderConfirmed) return;
    final addressOk = state.hasValidDeliveryTarget;
    final phoneOk =
        state.paymentMethod != CheckoutPaymentMethod.nequi ||
        _colombianMobile.hasMatch(state.nequiPhone.trim());
    if (!addressOk || !phoneOk) {
      emit(
        state.copyWith(
          showAddressError: !addressOk,
          showNequiPhoneError: !phoneOk,
          // §022d — si el error es del form colapsado, hay que
          // reabrirlo para que el usuario vea el error inline.
          newAddressExpanded:
              !addressOk && state.addressId == kCheckoutNewAddressId
              ? true
              : state.newAddressExpanded,
        ),
      );
      return;
    }
    emit(state.copyWith(confirmInProgress: true));
    await Future<void>.delayed(confirmDelay);
    if (isClosed) return;
    emit(state.copyWith(confirmInProgress: false, orderConfirmed: true));
  }
}
