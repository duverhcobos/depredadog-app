import 'package:equatable/equatable.dart';

import '../../domain/entities/checkout_store.dart';
import '../../domain/entities/saved_address.dart';

/// Cómo recibe el pedido (§022).
enum CheckoutOrderType { pickup, delivery }

/// Cómo paga (§022): Nequi = push a un celular (prellenado con el de la
/// cuenta, editable — puede ser otra cuenta Nequi); onDelivery = al
/// recibir (label dinámico según el tipo de pedido).
enum CheckoutPaymentMethod { nequi, onDelivery }

/// Valor de `CheckoutState.addressId` para la opción "Nueva ubicación"
/// (despliega el form inline). Nunca choca con un id real: los guardados
/// llevan prefijo `addr-`.
const String kCheckoutNewAddressId = 'new';

/// Link mock de ubicación de Google adjunta (§022a — la integración
/// real tomará las coordenadas del dispositivo / link de Maps).
const String kCheckoutMockLocationLink = 'maps.app.goo.gl/xK9fP2AbCd3';

/// Estado de la pantalla de checkout (§022 + §025 — datos reales de
/// GET /addresses + GET /store/config). Es estado de pantalla — el
/// cubit es factory por apertura, no se comparte fuera de la ruta.
class CheckoutState extends Equatable {
  const CheckoutState({
    required this.savedAddresses,
    required this.store,
    this.orderType = CheckoutOrderType.pickup,
    this.addressId,
    this.newLandmark = '',
    this.newNeighborhood = '',
    this.newAddressExpanded = false,
    this.deliveryLocationLink,
    this.saveNewAddress = false,
    this.newAddressType = SavedAddressType.home,
    this.newAddressLabel = '',
    this.paymentMethod = CheckoutPaymentMethod.nequi,
    this.nequiPhone = '',
    this.contactPhone = '',
    this.note = '',
    this.confirmInProgress = false,
    this.orderConfirmed = false,
    this.showAddressError = false,
    this.showNequiPhoneError = false,
    this.showContactPhoneError = false,
    this.dataLoading = true,
    this.addressesFailed = false,
    this.storeFailed = false,
    this.addressSaveFailed = false,
    this.justSavedAddress,
    this.confirmError,
  });

  /// Direcciones guardadas — GET /addresses (el backend ordena
  /// default-primero, §014 — `first` es el prefill del domicilio).
  final List<SavedAddress> savedAddresses;

  /// Datos del negocio — GET /store/config (backend 013). Mientras
  /// carga es un placeholder vacío con isOpen=true.
  final CheckoutStore store;

  final CheckoutOrderType orderType;

  /// Id de la dirección elegida (una de [savedAddresses]) o
  /// [kCheckoutNewAddressId] para el form inline. Null mientras carga —
  /// el prefill se resuelve al llegar GET /addresses (primera guardada,
  /// o "new" si no hay / falló).
  final String? addressId;

  /// Campos del form "Nueva ubicación" (§022a — la zona no tiene
  /// direcciones: el punto de referencia ES la dirección; el barrio/
  /// sector es opcional).
  final String newLandmark;
  final String newNeighborhood;

  /// Form "Nueva ubicación" desplegado (§022d): el segundo tap en la
  /// fila solo COLAPSA — la selección se conserva; expandir/colapsar
  /// no cambia `addressId`. Un confirm fallido lo reabre para mostrar
  /// el error inline.
  final bool newAddressExpanded;

  /// Pin de Google Maps adjunto AL PEDIDO (§022d — sirve para
  /// dirección nueva o guardada: la ubicación exacta la usa el
  /// repartidor sin importar cuál referencia esté marcada). Mock —
  /// null = el cliente no adjuntó ubicación.
  final String? deliveryLocationLink;

  /// Checkbox "Guardar esta ubicación" — al confirmar hace POST
  /// /addresses real antes del pedido (§025 — el guardado es
  /// auxiliar: si falla el pedido sigue y solo se avisa con toast).
  final bool saveNewAddress;

  /// Tipo elegido para la ubicación nueva al guardarla — casa/
  /// trabajo/otro (§022b — el selector aparece solo con el checkbox
  /// marcado; el label es lo que la lista mostrará).
  final SavedAddressType newAddressType;

  /// Nombre propio cuando [newAddressType] es `other` ("casa de mi
  /// mamá") — las etiquetas casa/trabajo ya traen el suyo.
  final String newAddressLabel;

  final CheckoutPaymentMethod paymentMethod;

  /// Celular que recibe el push de Nequi — prefill del `phone` de la
  /// cuenta (editable, decisión del usuario §022).
  final String nequiPhone;

  /// Celular de quién RECIBE el pedido (§024 — requerimiento del
  /// usuario). Solo aplica a domicilio: el repartidor lo llama si no
  /// encuentra la casa o nadie sale. Prefill del `phone` de la cuenta;
  /// editable porque quien recibe puede ser otra persona.
  /// Quien PAGA ya está cubierto: Nequi → [nequiPhone]; efectivo →
  /// quien recibe paga al recibir.
  final String contactPhone;

  /// Nota opcional para el local (a nivel pedido, §013).
  final String note;

  /// POST /orders en vuelo — spinner en el CTA + IgnorePointer.
  final bool confirmInProgress;

  /// Disparo one-shot del diálogo de éxito (BlocListener).
  final bool orderConfirmed;

  /// Errores inline tras un confirm inválido (§022 — nada de toast):
  /// dirección sin selección / form incompleto, y celular Nequi vacío
  /// o con formato inválido. Se limpian al editar el campo afectado.
  final bool showAddressError;
  final bool showNequiPhoneError;

  /// Error inline tras confirm inválido: en domicilio el celular de
  /// contacto es requerido y debe ser celular colombiano.
  final bool showContactPhoneError;

  /// Carga inicial de direcciones + store en vuelo — los bloques
  /// muestran placeholder de carga y el CTA espera (§025).
  final bool dataLoading;

  /// GET /addresses falló → el bloque cae a "Nueva ubicación" como
  /// única opción + aviso con retry (el pickup nunca se bloquea).
  final bool addressesFailed;

  /// GET /store/config falló → las líneas del local quedan en "—",
  /// aviso con retry y el store placeholder queda cerrado (seguro).
  final bool storeFailed;

  /// POST /addresses falló al confirmar con "guardar" — el pedido
  /// continuó igual (el guardado es auxiliar, §025); la UI lo avisa
  /// con toast junto al diálogo de éxito.
  final bool addressSaveFailed;

  /// La dirección que se acaba de guardar dentro del confirm — ciclo
  /// 2 la usará como destino de la orden (`justSavedAddress?.id ??
  /// newAddress`).
  final SavedAddress? justSavedAddress;

  /// POST /orders rechazado/fallido — texto resuelto por el cubit
  /// (mensaje del servidor en 4xx, l10n en offline/5xx) que la fila
  /// inline sobre el CTA muestra persistente hasta el retry. Null =
  /// sin error.
  final String? confirmError;

  /// La entrega está resuelta: modo pickup, dirección guardada
  /// elegida, o form nuevo con los campos requeridos completos.
  bool get hasValidDeliveryTarget {
    if (orderType == CheckoutOrderType.pickup) return true;
    if (addressId == null) return false;
    if (addressId == kCheckoutNewAddressId) {
      // Solo el punto de referencia es requerido (§022a) — barrio y
      // pin de Google son apoyo opcional.
      return newLandmark.trim().isNotEmpty;
    }
    return true;
  }

  CheckoutState copyWith({
    List<SavedAddress>? savedAddresses,
    CheckoutStore? store,
    CheckoutOrderType? orderType,
    String? addressId,
    String? newLandmark,
    String? newNeighborhood,
    bool? newAddressExpanded,
    String? Function()? deliveryLocationLink,
    bool? saveNewAddress,
    SavedAddressType? newAddressType,
    String? newAddressLabel,
    CheckoutPaymentMethod? paymentMethod,
    String? nequiPhone,
    String? contactPhone,
    String? note,
    bool? confirmInProgress,
    bool? orderConfirmed,
    bool? showAddressError,
    bool? showNequiPhoneError,
    bool? showContactPhoneError,
    bool? dataLoading,
    bool? addressesFailed,
    bool? storeFailed,
    bool? addressSaveFailed,
    SavedAddress? Function()? justSavedAddress,
    String? Function()? confirmError,
  }) => CheckoutState(
    savedAddresses: savedAddresses ?? this.savedAddresses,
    store: store ?? this.store,
    orderType: orderType ?? this.orderType,
    addressId: addressId ?? this.addressId,
    newLandmark: newLandmark ?? this.newLandmark,
    newNeighborhood: newNeighborhood ?? this.newNeighborhood,
    newAddressExpanded: newAddressExpanded ?? this.newAddressExpanded,
    deliveryLocationLink: deliveryLocationLink != null
        ? deliveryLocationLink()
        : this.deliveryLocationLink,
    saveNewAddress: saveNewAddress ?? this.saveNewAddress,
    newAddressType: newAddressType ?? this.newAddressType,
    newAddressLabel: newAddressLabel ?? this.newAddressLabel,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    nequiPhone: nequiPhone ?? this.nequiPhone,
    contactPhone: contactPhone ?? this.contactPhone,
    note: note ?? this.note,
    confirmInProgress: confirmInProgress ?? this.confirmInProgress,
    orderConfirmed: orderConfirmed ?? this.orderConfirmed,
    showAddressError: showAddressError ?? this.showAddressError,
    showNequiPhoneError: showNequiPhoneError ?? this.showNequiPhoneError,
    showContactPhoneError: showContactPhoneError ?? this.showContactPhoneError,
    dataLoading: dataLoading ?? this.dataLoading,
    addressesFailed: addressesFailed ?? this.addressesFailed,
    storeFailed: storeFailed ?? this.storeFailed,
    addressSaveFailed: addressSaveFailed ?? this.addressSaveFailed,
    justSavedAddress: justSavedAddress != null
        ? justSavedAddress()
        : this.justSavedAddress,
    confirmError: confirmError != null ? confirmError() : this.confirmError,
  );

  @override
  List<Object?> get props => [
    savedAddresses,
    store,
    orderType,
    addressId,
    newLandmark,
    newNeighborhood,
    newAddressExpanded,
    deliveryLocationLink,
    saveNewAddress,
    newAddressType,
    newAddressLabel,
    paymentMethod,
    nequiPhone,
    contactPhone,
    note,
    confirmInProgress,
    orderConfirmed,
    showAddressError,
    showNequiPhoneError,
    showContactPhoneError,
    dataLoading,
    addressesFailed,
    storeFailed,
    addressSaveFailed,
    justSavedAddress,
    confirmError,
  ];
}
