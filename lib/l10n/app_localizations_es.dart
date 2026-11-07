// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Depredadog';

  @override
  String get loginHeadline => 'VUELVE A LA MANADA';

  @override
  String get loginSubtitle =>
      'Inicia sesión para pedir algo salvajemente bueno.';

  @override
  String get loginEmailLabel => 'Correo electrónico';

  @override
  String get loginEmailHint => 'nombre@ejemplo.com';

  @override
  String get loginEmailRequired => 'Ingresa tu correo';

  @override
  String get loginEmailError => 'Ingresa un correo válido';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginPasswordHint => 'Ej: HotDog2024';

  @override
  String get loginPasswordRequired => 'Ingresa tu contraseña';

  @override
  String get loginPasswordError => 'Mínimo 6 caracteres';

  @override
  String get loginFormInvalid => 'Revisa los campos marcados';

  @override
  String get loginShowPassword => 'Mostrar contraseña';

  @override
  String get loginHidePassword => 'Ocultar contraseña';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginRememberMe => 'Recuérdame';

  @override
  String get loginButton => 'Iniciar sesión';

  @override
  String get loginOrContinueWith => 'o continúa con';

  @override
  String get loginGoogleButton => 'Continuar con Google';

  @override
  String get loginNoAccount => '¿No tienes cuenta? ';

  @override
  String get loginRegisterLink => 'Regístrate';

  @override
  String get loginErrorInvalidCredentials => 'Correo o contraseña incorrectos';

  @override
  String get loginErrorEmailNotVerified =>
      'Verifica tu correo antes de iniciar sesión';

  @override
  String get loginErrorAccountSuspended => 'Tu cuenta está suspendida';

  @override
  String get loginErrorTooManyAttempts =>
      'Demasiados intentos — espera un momento';

  @override
  String get loginErrorNoConnection => 'Sin conexión a internet';

  @override
  String get loginErrorGeneric => 'No se pudo iniciar sesión, intenta de nuevo';

  @override
  String get googleSignInError =>
      'No pudimos entrar con Google — inténtalo de nuevo';

  @override
  String get comingSoon => 'Disponible próximamente';

  @override
  String get commonBack => 'Volver';

  @override
  String get verifyEmailHeadline => 'Verifica tu correo';

  @override
  String verifyEmailSubtitle(String email) {
    return 'Enviamos un código de 6 dígitos a $email';
  }

  @override
  String get verifyEmailButton => 'Verificar';

  @override
  String get verifyEmailFormInvalid => 'Ingresa el código de 6 dígitos';

  @override
  String verifyEmailCodeSemantics(int filled) {
    return 'Código de verificación, $filled de 6 dígitos';
  }

  @override
  String get verifyEmailResendQuestion => '¿No recibiste el código? ';

  @override
  String get verifyEmailResend => 'Reenviar';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Reenviar en ${seconds}s';
  }

  @override
  String get verifyEmailResendSuccess => 'Código reenviado — revisa tu correo';

  @override
  String get verifyEmailErrorInvalidCode =>
      'El código es incorrecto o ya expiró — pide uno nuevo.';

  @override
  String get registerStepDataLabel => 'Datos';

  @override
  String get registerStepAccountLabel => 'Cuenta';

  @override
  String get registerStepReviewLabel => 'Revisión';

  @override
  String get registerStep1Title => 'Cuéntanos quién eres';

  @override
  String get registerStep1Subtitle => 'Empecemos por tus datos personales.';

  @override
  String get registerStep2Title => 'Tu correo y tu contraseña';

  @override
  String get registerStep2Subtitle => 'Con estos datos entrarás a tu cuenta.';

  @override
  String registerStep3Title(String name) {
    return 'Todo listo, $name';
  }

  @override
  String get registerStep3Subtitle => 'Revisa que todo esté bien.';

  @override
  String registerStepProgress(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String registerStepItemLabel(int number, String label, String status) {
    return 'Paso $number: $label, $status';
  }

  @override
  String get registerStepStatusCompleted => 'completado';

  @override
  String get registerStepStatusCurrent => 'actual';

  @override
  String get registerStepStatusPending => 'pendiente';

  @override
  String get registerContinue => 'Continuar';

  @override
  String get registerBackStep => 'Atrás';

  @override
  String get registerReviewName => 'Nombre';

  @override
  String get registerReviewEmail => 'Correo';

  @override
  String get registerReviewPhone => 'Teléfono';

  @override
  String get registerReviewNoPhone => 'Sin teléfono';

  @override
  String get registerFirstNameLabel => 'Primer nombre *';

  @override
  String get registerFirstNameHint => 'Ej: Ana';

  @override
  String get registerSecondNameLabel => 'Segundo nombre (opcional)';

  @override
  String get registerLastNameLabel => 'Primer apellido *';

  @override
  String get registerLastNameHint => 'Ej: Pérez';

  @override
  String get registerSecondLastNameLabel => 'Segundo apellido (opcional)';

  @override
  String get registerEmailLabel => 'Correo electrónico *';

  @override
  String get registerPhoneLabel => 'Teléfono (opcional)';

  @override
  String get registerPhoneHint => 'Ej: 300 123 4567';

  @override
  String get registerPasswordLabel => 'Contraseña *';

  @override
  String get registerPasswordHint => 'Mínimo 8 caracteres';

  @override
  String get registerConfirmPasswordLabel => 'Confirmar contraseña *';

  @override
  String get registerConfirmPasswordHint => 'Repite tu contraseña';

  @override
  String get registerNameRequired => 'Ingresa tu nombre';

  @override
  String get registerNameInvalid => 'Nombre incorrecto';

  @override
  String get registerLastNameRequired => 'Ingresa tu apellido';

  @override
  String get registerLastNameInvalid => 'Apellido incorrecto';

  @override
  String get registerPhoneInvalid => 'Teléfono incorrecto';

  @override
  String get registerEmailInvalid => 'Correo incorrecto';

  @override
  String get registerEmailTaken => 'Este correo ya tiene cuenta';

  @override
  String get registerErrorGeneric =>
      'No se pudo crear la cuenta, intenta de nuevo';

  @override
  String get registerPasswordRequired => 'Ingresa una contraseña';

  @override
  String get registerPasswordInvalid => 'Mínimo 8 caracteres';

  @override
  String get registerConfirmRequired => 'Confirma tu contraseña';

  @override
  String get registerConfirmMismatch => 'Las contraseñas no coinciden';

  @override
  String get registerButton => 'Crear cuenta';

  @override
  String get registerHasAccount => '¿Ya tienes cuenta? ';

  @override
  String get registerLoginLink => 'Inicia sesión';

  @override
  String get forgotTitle => '¿Olvidaste tu contraseña?';

  @override
  String get forgotSubtitle => 'Te enviamos un código para restablecerla.';

  @override
  String get forgotSendCode => 'Enviar código';

  @override
  String get forgotStepEmailLabel => 'Correo';

  @override
  String get forgotStepCodeLabel => 'Código';

  @override
  String get forgotStepPasswordLabel => 'Clave';

  @override
  String get forgotCodeTitle => 'Revisa tu correo';

  @override
  String forgotCodeSemantics(int filled) {
    return 'Código de restablecimiento, $filled de 6 dígitos';
  }

  @override
  String get forgotPasswordTitle => 'Crea tu nueva contraseña';

  @override
  String get forgotPasswordSubtitle => 'Elige una que no uses en otro lado.';

  @override
  String get forgotNewPasswordLabel => 'Nueva contraseña *';

  @override
  String get forgotSubmit => 'Cambiar contraseña';

  @override
  String get forgotErrorGeneric =>
      'No se pudo restablecer la contraseña, intenta de nuevo';

  @override
  String get shellTabHome => 'Inicio';

  @override
  String get shellTabOrders => 'Pedidos';

  @override
  String get shellTabProfile => 'Perfil';

  @override
  String get shellNotificationsTooltip => 'Notificaciones';

  @override
  String get shellCartTooltip => 'Carrito';

  @override
  String get homeStoreOpen => 'Abierto';

  @override
  String get homeStoreClosed => 'Cerrado';

  @override
  String get homeStoreEta => 'Entrega en 30-45 min';

  @override
  String get homePromoTag => 'PROMO';

  @override
  String get homePromoTitle => '2×1 en El Cachorro — solo hoy';

  @override
  String get homeFeaturedTag => 'EL DE LA CASA';

  @override
  String get catalogAddTooltip => 'Agregar';

  @override
  String get catalogBackTooltip => 'Volver';

  @override
  String get catalogPromoTooltip => 'Ver promo';

  @override
  String get catalogEmptySubtitle => 'La manada aún está cazando aquí';

  @override
  String catalogProductsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count productos',
      one: '1 producto',
    );
    return '$_temp0';
  }

  @override
  String get detailSectionRemove => '¿Se le quita algo?';

  @override
  String get detailSectionExtras => '¿Le agregamos algo más?';

  @override
  String get detailSectionToppings => 'Toppings';

  @override
  String get detailSectionSauces => 'Salsas';

  @override
  String get detailTotalLabel => 'Total';

  @override
  String get detailTotalPerUnitLabel => 'Total por unidad';

  @override
  String detailEditingTitle(String name) {
    return 'Editando · $name';
  }

  @override
  String get detailAddToCart => 'Agregar al carrito';

  @override
  String get catalogSoldOut => 'Agotado';

  @override
  String get catalogLoadErrorTitle => 'No pudimos cargar la carta';

  @override
  String get catalogLoadErrorSubtitle =>
      'Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get catalogRetry => 'Reintentar';

  @override
  String get productUnavailableTitle => 'Este producto ya no está en la carta';

  @override
  String get productUnavailableCta => 'Volver al menú';

  @override
  String get detailSwapCta => 'Cambiar';

  @override
  String get cartTitle => 'Tu carrito';

  @override
  String get cartEmptyTitle => 'Nada por acá todavía';

  @override
  String get cartEmptySubtitle => 'Suma algo rico del menú';

  @override
  String get cartEmptyCta => 'Ver el menú';

  @override
  String get cartBrowseMore => '¿Se te antoja algo más?';

  @override
  String get cartSubtotalLabel => 'Subtotal';

  @override
  String get cartCheckoutCta => 'Ir a pagar';

  @override
  String get cartItemAdded => 'Agregado al carrito';

  @override
  String cartItemRemoved(String name) {
    return '$name eliminado del carrito';
  }

  @override
  String get cartRemoveTooltip => 'Quitar del carrito';

  @override
  String get cartStepperRemove => 'Quitar uno';

  @override
  String get cartStepperAdd => 'Agregar uno';

  @override
  String cartStepperQty(int count) {
    return 'Cantidad: $count';
  }

  @override
  String cartBadgeA11y(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Carrito, $count ítems',
      one: 'Carrito, 1 ítem',
    );
    return '$_temp0';
  }

  @override
  String get cartItemAsIs => 'Tal cual de la carta';

  @override
  String get cartDetailIngredients => 'Ingredientes';

  @override
  String get cartDetailRemoved => 'Se le quitó';

  @override
  String get cartDetailExtras => 'Adicionales';

  @override
  String get cartDetailToppings => 'Toppings';

  @override
  String get cartDetailSauces => 'Salsas';

  @override
  String get cartItemDetail => 'Detalle';

  @override
  String get cartItemEdit => 'Editar';

  @override
  String get cartEditSaveCta => 'Guardar cambios';

  @override
  String get cartEditSaved => 'Cambios guardados';

  @override
  String get cartEditScopeTitle => '¿A cuántos aplicar los cambios?';

  @override
  String get cartEditScopeOne => 'Solo 1';

  @override
  String cartEditScopeAll(int count) {
    return 'Las $count';
  }

  @override
  String get cartItemDetailToggle => 'Detalle del perro';

  @override
  String get cartEditMerged => 'Se combinó con la fila igual';

  @override
  String get cartEditBackToCart => 'Volver al carrito';

  @override
  String get cartEditDiscardTitle => '¿Descartar los cambios?';

  @override
  String get cartEditDiscardStay => 'Seguir editando';

  @override
  String get cartEditDiscardLeave => 'Descartar';

  @override
  String get checkoutTitle => 'Confirmar pedido';

  @override
  String get checkoutOrderTypeSection => 'Tipo de pedido';

  @override
  String get checkoutPickupOption => 'Local';

  @override
  String get checkoutDeliveryOption => 'Domicilio';

  @override
  String get checkoutPickupAtLabel => 'Lo recoges en';

  @override
  String get checkoutPickupNotice => 'Te avisamos cuando esté listo';

  @override
  String get checkoutNewAddress => 'Nueva ubicación';

  @override
  String get checkoutNeighborhoodLabel => 'Barrio o sector (opcional)';

  @override
  String get checkoutNeighborhoodHint => 'Ej: La Esperanza';

  @override
  String get checkoutSaveAddress => 'Guardar esta ubicación';

  @override
  String get checkoutAddressTypeLabel => '¿Qué lugar es?';

  @override
  String get checkoutAddressTypeHome => 'Casa';

  @override
  String get checkoutAddressTypeWork => 'Trabajo';

  @override
  String get checkoutAddressTypeOther => 'Otro';

  @override
  String get checkoutAddressNameLabel => 'Nombre del lugar';

  @override
  String get checkoutAddressNameHint => 'Ej: casa de mi mamá';

  @override
  String get checkoutAddressRequired => 'Elige una ubicación';

  @override
  String get checkoutLandmarkLabel => 'Punto de referencia *';

  @override
  String get checkoutLandmarkHint => 'Ej: casa blanca frente a la cancha';

  @override
  String get checkoutLandmarkRequired => 'Ingresa el punto de referencia';

  @override
  String get checkoutAttachLocation => 'Adjuntar ubicación de Google';

  @override
  String get checkoutLocationAttached => 'Ubicación adjunta';

  @override
  String get checkoutRemoveLocation => 'Quitar ubicación';

  @override
  String get checkoutContactPhoneLabel => 'Celular de quien recibe';

  @override
  String get checkoutContactPhoneHint => '3XX XXX XXXX';

  @override
  String get checkoutContactPhoneRequired =>
      'Necesitamos el celular de quien recibe el pedido';

  @override
  String get checkoutDeliveryFree => 'Gratis';

  @override
  String get checkoutPaymentSection => 'Pago';

  @override
  String get checkoutPickupTransferNote =>
      'En el local el pago es solo por transferencia';

  @override
  String get checkoutPayNequi => 'Nequi';

  @override
  String get checkoutNequiPhoneLabel => 'Celular Nequi';

  @override
  String get checkoutNequiPhoneHint => 'Ej: 300 123 4567';

  @override
  String get checkoutNequiPhoneError => 'Celular incorrecto';

  @override
  String get checkoutPayOnDelivery => 'Pagar al recibir tu pedido';

  @override
  String get checkoutNoteSection => 'Observación';

  @override
  String get checkoutNoteHint =>
      '¿Algo que debamos saber? — p. ej. pago con billete de 50, traer cambio';

  @override
  String get checkoutSummarySection => 'Tu pedido';

  @override
  String get checkoutDeliveryFeeLabel => 'Domicilio';

  @override
  String get checkoutConfirmCta => 'Confirmar pedido';

  @override
  String get checkoutConfirmedTitle => '¡Pedido confirmado!';

  @override
  String get checkoutConfirmedSubtitle => 'Te avisamos cuando esté listo';

  @override
  String get checkoutViewOrdersCta => 'Ver mis pedidos';

  @override
  String get ordersTitle => 'Pedidos';

  @override
  String get ordersSectionHistory => 'Historial';

  @override
  String get ordersEmptyTitle => 'Aún no has pedido';

  @override
  String get ordersEmptySubtitle => 'Tu próximo antojo empieza en el menú';

  @override
  String get ordersBrowseMenu => 'Ver el menú';

  @override
  String get orderServicePickup => 'Local';

  @override
  String get orderServiceDelivery => 'Domicilio';

  @override
  String get orderStatusReceived => 'Recibido';

  @override
  String get orderStatusConfirmed => 'Confirmado';

  @override
  String get orderStatusPreparing => 'En la plancha';

  @override
  String get orderStatusReady => 'Listo';

  @override
  String get orderStatusDelivered => 'Entregado';

  @override
  String get orderStatusCancelled => 'Cancelado';

  @override
  String get orderStepReceived => 'Recibido';

  @override
  String get orderStepConfirmed => 'Confirmado';

  @override
  String get orderStepPreparing => 'En la plancha';

  @override
  String get orderStepReady => 'Listo — ya puedes pasar';

  @override
  String get orderStepDelivered => 'Entregado';

  @override
  String get orderPickupAtStore => 'Lo recoges en el local';

  @override
  String get orderWithLocationPin => 'Con ubicación de Google';

  @override
  String orderContactPhone(String phone) {
    return 'Recibe: $phone';
  }

  @override
  String get orderPaymentNequiPaid => 'Nequi · pagado';

  @override
  String get orderPaymentNequiPending => 'Nequi · pago pendiente';

  @override
  String get orderPaymentOnDelivery => 'Pagas al recibir';

  @override
  String get orderPaymentOnDeliveryPast => 'Pagaste al recibir';

  @override
  String orderPlacedAt(String date) {
    return 'Pedido el $date';
  }

  @override
  String orderStepProgress(int current, int total, String step) {
    return 'Paso $current de $total: $step';
  }

  @override
  String get orderCancelledToast => 'Pedido cancelado';

  @override
  String orderItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ítems',
      one: '1 ítem',
    );
    return '$_temp0';
  }

  @override
  String get orderCancelCta => 'Cancelar pedido';

  @override
  String get orderCancelTitle => '¿Cancelar el pedido?';

  @override
  String get orderCancelBody =>
      'El local aún no lo confirma — puedes cancelar sin problema.';

  @override
  String get orderCancelConfirm => 'Sí, cancelar';

  @override
  String get orderCancelKeep => 'No, dejarlo';

  @override
  String get orderDetailTitle => 'Detalle del pedido';

  @override
  String get orderDetailStatusSection => 'Estado';

  @override
  String get orderDetailItemsSection => 'Tu pedido';

  @override
  String get orderDetailDeliverySection => 'Entrega y pago';

  @override
  String get orderDetailNoteSection => 'Observación';

  @override
  String get orderSummarySubtotal => 'Subtotal';

  @override
  String get orderSummaryDelivery => 'Domicilio';

  @override
  String get orderSummaryFree => 'Gratis';

  @override
  String get orderSummaryTotal => 'Total';
}
