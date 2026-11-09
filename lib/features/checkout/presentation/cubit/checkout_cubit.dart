import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../l10n/app_localizations_es.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../domain/entities/checkout_store.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/use_cases/load_checkout_data_use_case.dart';
import '../../domain/use_cases/save_address_use_case.dart';
import 'checkout_state.dart';

/// SOLID (SRP): único dueño del estado de la pantalla de checkout
/// (§022 + §025) — tipo de pedido, dirección, pago, nota, la carga
/// inicial de direcciones+store y el delay mock de confirmación. Es
/// FACTORY por apertura (estado de pantalla, no compartido): cada push
/// a /checkout crea una instancia fresca.
///
/// LEE el CartCubit para ítems/subtotal/total — NUNCA lo modifica: la
/// confirmación real vaciará el carrito en §015; aquí la pantalla lo
/// limpia tras el diálogo de éxito (flujo simulado).
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this.cartCubit,
    required AuthSession authSession,
    required LoadCheckoutDataUseCase loadCheckoutDataUseCase,
    required SaveAddressUseCase saveAddressUseCase,
    this.confirmDelay = const Duration(milliseconds: 800),
  }) : _loadCheckoutData = loadCheckoutDataUseCase,
       _saveAddress = saveAddressUseCase,
       super(
         CheckoutState(
           // El prefill addressId se resuelve en loadCheckoutData()
           // (aquí aún no hay direcciones — dataLoading arranca true).
           savedAddresses: const [],
           // Placeholder seguro mientras carga: vacío y abierto — si
           // el GET falla se reemplaza por uno cerrado (isOpen:false).
           store: const CheckoutStore(name: '', address: '', deliveryFee: 0),
           // Prefills que reducen fricción (§022): celular de la cuenta
           // para el push de Nequi (vacío si no lo registró). §024: el
           // mismo phone prellena el contacto de entrega — quien recibe
           // puede ser otra persona, por eso es editable.
           nequiPhone: authSession.currentUser?.phone ?? '',
           contactPhone: authSession.currentUser?.phone ?? '',
         ),
       );

  /// Fuente de ítems/subtotal (solo lectura — §022: el cubit NUNCA lo
  /// muta; la pantalla lo limpia tras el diálogo de éxito).
  final CartCubit cartCubit;

  /// Duración del delay mock de confirmación — inyectable para tests.
  final Duration confirmDelay;

  final LoadCheckoutDataUseCase _loadCheckoutData;
  final SaveAddressUseCase _saveAddress;

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

  /// Carga inicial (§025): GET /addresses + GET /store/config en
  /// paralelo. Cada pierna degrada por separado — un fallo de una no
  /// tumba la otra. También es el retry de los avisos inline.
  Future<void> loadCheckoutData() async {
    // Capturar ANTES de limpiar los flags — si el 'new' actual vino del
    // fallback por falla, un retry exitoso debe prefijar la primera
    // guardada; solo se preserva 'new' si el usuario lo eligió o tipeó.
    final hadAddressesFailed = state.addressesFailed;
    emit(
      state.copyWith(
        dataLoading: true,
        addressesFailed: false,
        storeFailed: false,
      ),
    );
    final result = await _loadCheckoutData();
    if (isClosed) return;
    result.addresses.fold(
      // Sin direcciones por error → "Nueva ubicación" es la única
      // opción del domicilio (el pickup nunca se bloquea).
      (failure) => emit(
        state.copyWith(
          savedAddresses: const [],
          addressId: kCheckoutNewAddressId,
          newAddressExpanded: true,
          addressesFailed: true,
        ),
      ),
      (addresses) {
        // En un retry/reload se conserva lo que el usuario ya eligió:
        // su guardada si sigue existiendo, o "new" si tenía el form
        // abierto. El prefill a primera-guardada (default del backend,
        // §014) solo aplica cuando no hay selección previa válida —
        // incluido el 'new' del fallback por falla SIN texto tipeado
        // (ese 'new' lo puso el fallback, no el usuario).
        final typedForm =
            state.newLandmark.trim().isNotEmpty ||
            state.newNeighborhood.trim().isNotEmpty ||
            state.newAddressLabel.trim().isNotEmpty;
        final keepId =
            addresses.any((a) => a.id == state.addressId) ||
            (state.addressId == kCheckoutNewAddressId &&
                state.newAddressExpanded &&
                (!hadAddressesFailed || typedForm));
        final resolvedId = keepId
            ? state.addressId
            : addresses.isEmpty
            ? kCheckoutNewAddressId
            : addresses.first.id;
        emit(
          state.copyWith(
            savedAddresses: addresses,
            addressId: resolvedId,
            // Cliente nuevo sin direcciones: el form arranca abierto —
            // es la única forma de entregar a domicilio. Con lista el
            // form queda como estaba si "new" sigue seleccionada.
            newAddressExpanded:
                addresses.isEmpty ||
                (resolvedId == kCheckoutNewAddressId &&
                    state.newAddressExpanded),
            addressesFailed: false,
          ),
        );
      },
    );
    result.store.fold(
      // Store placeholder CERRADO por defecto = seguro: sin fee ni
      // apertura reales el confirm queda bloqueado hasta el retry.
      (failure) => emit(
        state.copyWith(
          store: const CheckoutStore(
            name: '',
            address: '',
            deliveryFee: 0,
            isOpen: false,
          ),
          storeFailed: true,
        ),
      ),
      (store) => emit(state.copyWith(store: store, storeFailed: false)),
    );
    emit(state.copyWith(dataLoading: false));
  }

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
    if (state.confirmInProgress || state.dataLoading) return;
    emit(state.copyWith(addressId: id, showAddressError: false));
  }

  /// Tap en "Nueva ubicación" (§022d — toggle de SOLO
  /// expandir/colapsar, NUNCA desmarca):
  /// - no seleccionada → la selecciona y despliega el form;
  /// - seleccionada → alterna `newAddressExpanded` (colapsa/reabre)
  ///   conservando la selección. Desmarcar solo pasa al tocar otra
  ///   dirección. Los campos tipeados sobreviven al colapso.
  void toggleNewAddress() {
    if (state.confirmInProgress || state.dataLoading) return;
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

  /// Celular de quién recibe (§024 — solo domicilio lo exige).
  void contactPhoneChanged(String value) =>
      emit(state.copyWith(contactPhone: value, showContactPhoneError: false));

  void noteChanged(String value) => emit(state.copyWith(note: value));

  /// "Guardar esta ubicación" corre solo si hay algo válido que
  /// guardar: domicilio + form nuevo + checkbox + landmark (§025).
  bool get _shouldSaveNewAddress =>
      state.orderType == CheckoutOrderType.delivery &&
      state.addressId == kCheckoutNewAddressId &&
      state.saveNewAddress &&
      state.hasValidDeliveryTarget;

  /// Label que POST /addresses exige siempre (§014): casa/trabajo toman
  /// el l10n de los chips del selector (misma fuente que la UI muestra);
  /// "otro" usa el nombre propio tipeado.
  String get _resolvedNewAddressLabel {
    final l10n = AppLocalizationsEs();
    return switch (state.newAddressType) {
      SavedAddressType.home => l10n.checkoutAddressTypeHome,
      SavedAddressType.work => l10n.checkoutAddressTypeWork,
      // "Otro" sin nombre propio → el l10n del chip (el backend exige
      // label siempre, §014 — un '' sería 400 garantizado).
      SavedAddressType.other =>
        state.newAddressLabel.trim().isEmpty
            ? l10n.checkoutAddressTypeOther
            : state.newAddressLabel.trim(),
    };
  }

  /// Validación al confirmar (§022 + §024 — sin mínimo): delivery
  /// exige ubicación elegida o form nuevo con su punto de referencia
  /// (§022a — barrio/pin opcionales) y el celular de quién recibe
  /// (§024 — el repartidor necesita a quién llamar); Nequi exige
  /// celular colombiano válido.
  /// Inválido → errores INLINE (flags, la UI los pinta bajo el campo/
  /// sección); válido → guarda la ubicación si se pidió (§025 —
  /// auxiliar: si falla el pedido sigue y solo se avisa con toast),
  /// delay mock → `orderConfirmed` dispara el diálogo de éxito.
  Future<void> confirm() async {
    if (state.confirmInProgress || state.orderConfirmed) return;
    // Guardia de cerrado (la UI ya deshabilita el CTA — defensa): el
    // backend rechazaría con 409, mejor ni llegar. Lo mismo aplica
    // mientras la carga inicial sigue en vuelo.
    if (state.dataLoading || !state.store.isOpen) return;
    final addressOk = state.hasValidDeliveryTarget;
    final phoneOk =
        state.paymentMethod != CheckoutPaymentMethod.nequi ||
        _colombianMobile.hasMatch(state.nequiPhone.trim());
    // §024 — quién recibe: requerido solo en domicilio (en el local
    // quien recoge se identifica en el mostrador). Misma regla
    // celular colombiano del Nequi/registro.
    final contactOk =
        state.orderType == CheckoutOrderType.pickup ||
        _colombianMobile.hasMatch(state.contactPhone.trim());
    if (!addressOk || !phoneOk || !contactOk) {
      emit(
        state.copyWith(
          showAddressError: !addressOk,
          showNequiPhoneError: !phoneOk,
          showContactPhoneError: !contactOk,
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
    // §025 — POST /addresses ANTES de confirmar (flujo de dos llamadas
    // del 015): el guardado es auxiliar, NUNCA aborta la compra — si
    // falla, el pedido sigue y la UI solo avisa con toast.
    if (_shouldSaveNewAddress) {
      final result = await _saveAddress(
        label: _resolvedNewAddressLabel,
        landmark: state.newLandmark.trim(),
        neighborhood: state.newNeighborhood.trim().isEmpty
            ? null
            : state.newNeighborhood.trim(),
        type: state.newAddressType,
      );
      // El usuario pudo salir durante el POST — emitir sobre un cubit
      // cerrado lanza StateError async.
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(addressSaveFailed: true)),
        (saved) => emit(
          state.copyWith(
            savedAddresses: [...state.savedAddresses, saved],
            justSavedAddress: () => saved,
          ),
        ),
      );
    }
    await Future<void>.delayed(confirmDelay);
    if (isClosed) return;
    emit(state.copyWith(confirmInProgress: false, orderConfirmed: true));
  }
}
