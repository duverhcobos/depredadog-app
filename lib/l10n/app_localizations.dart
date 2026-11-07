import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'Depredadog'**
  String get appName;

  /// No description provided for @loginHeadline.
  ///
  /// In es, this message translates to:
  /// **'VUELVE A LA MANADA'**
  String get loginHeadline;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para pedir algo salvajemente bueno.'**
  String get loginSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailHint.
  ///
  /// In es, this message translates to:
  /// **'nombre@ejemplo.com'**
  String get loginEmailHint;

  /// No description provided for @loginEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo'**
  String get loginEmailRequired;

  /// No description provided for @loginEmailError.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo válido'**
  String get loginEmailError;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: HotDog2024'**
  String get loginPasswordHint;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get loginPasswordRequired;

  /// No description provided for @loginPasswordError.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get loginPasswordError;

  /// No description provided for @loginFormInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa los campos marcados'**
  String get loginFormInvalid;

  /// No description provided for @loginShowPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get loginHidePassword;

  /// No description provided for @loginForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get loginForgotPassword;

  /// No description provided for @loginRememberMe.
  ///
  /// In es, this message translates to:
  /// **'Recuérdame'**
  String get loginRememberMe;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginButton;

  /// No description provided for @loginOrContinueWith.
  ///
  /// In es, this message translates to:
  /// **'o continúa con'**
  String get loginOrContinueWith;

  /// No description provided for @loginGoogleButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get loginGoogleButton;

  /// No description provided for @loginNoAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? '**
  String get loginNoAccount;

  /// No description provided for @loginRegisterLink.
  ///
  /// In es, this message translates to:
  /// **'Regístrate'**
  String get loginRegisterLink;

  /// No description provided for @loginErrorInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña incorrectos'**
  String get loginErrorInvalidCredentials;

  /// No description provided for @loginErrorEmailNotVerified.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo antes de iniciar sesión'**
  String get loginErrorEmailNotVerified;

  /// No description provided for @loginErrorAccountSuspended.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta está suspendida'**
  String get loginErrorAccountSuspended;

  /// No description provided for @loginErrorTooManyAttempts.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos — espera un momento'**
  String get loginErrorTooManyAttempts;

  /// No description provided for @loginErrorNoConnection.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet'**
  String get loginErrorNoConnection;

  /// No description provided for @loginErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión, intenta de nuevo'**
  String get loginErrorGeneric;

  /// No description provided for @googleSignInError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos entrar con Google — inténtalo de nuevo'**
  String get googleSignInError;

  /// No description provided for @comingSoon.
  ///
  /// In es, this message translates to:
  /// **'Disponible próximamente'**
  String get comingSoon;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @verifyEmailHeadline.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo'**
  String get verifyEmailHeadline;

  /// No description provided for @verifyEmailSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Enviamos un código de 6 dígitos a {email}'**
  String verifyEmailSubtitle(String email);

  /// No description provided for @verifyEmailButton.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get verifyEmailButton;

  /// No description provided for @verifyEmailFormInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código de 6 dígitos'**
  String get verifyEmailFormInvalid;

  /// No description provided for @verifyEmailCodeSemantics.
  ///
  /// In es, this message translates to:
  /// **'Código de verificación, {filled} de 6 dígitos'**
  String verifyEmailCodeSemantics(int filled);

  /// No description provided for @verifyEmailResendQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿No recibiste el código? '**
  String get verifyEmailResendQuestion;

  /// No description provided for @verifyEmailResend.
  ///
  /// In es, this message translates to:
  /// **'Reenviar'**
  String get verifyEmailResend;

  /// No description provided for @verifyEmailResendIn.
  ///
  /// In es, this message translates to:
  /// **'Reenviar en {seconds}s'**
  String verifyEmailResendIn(int seconds);

  /// No description provided for @verifyEmailResendSuccess.
  ///
  /// In es, this message translates to:
  /// **'Código reenviado — revisa tu correo'**
  String get verifyEmailResendSuccess;

  /// No description provided for @verifyEmailErrorInvalidCode.
  ///
  /// In es, this message translates to:
  /// **'El código es incorrecto o ya expiró — pide uno nuevo.'**
  String get verifyEmailErrorInvalidCode;

  /// No description provided for @registerStepDataLabel.
  ///
  /// In es, this message translates to:
  /// **'Datos'**
  String get registerStepDataLabel;

  /// No description provided for @registerStepAccountLabel.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get registerStepAccountLabel;

  /// No description provided for @registerStepReviewLabel.
  ///
  /// In es, this message translates to:
  /// **'Revisión'**
  String get registerStepReviewLabel;

  /// No description provided for @registerStep1Title.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos quién eres'**
  String get registerStep1Title;

  /// No description provided for @registerStep1Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Empecemos por tus datos personales.'**
  String get registerStep1Subtitle;

  /// No description provided for @registerStep2Title.
  ///
  /// In es, this message translates to:
  /// **'Tu correo y tu contraseña'**
  String get registerStep2Title;

  /// No description provided for @registerStep2Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Con estos datos entrarás a tu cuenta.'**
  String get registerStep2Subtitle;

  /// No description provided for @registerStep3Title.
  ///
  /// In es, this message translates to:
  /// **'Todo listo, {name}'**
  String registerStep3Title(String name);

  /// No description provided for @registerStep3Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa que todo esté bien.'**
  String get registerStep3Subtitle;

  /// No description provided for @registerStepProgress.
  ///
  /// In es, this message translates to:
  /// **'Paso {current} de {total}'**
  String registerStepProgress(int current, int total);

  /// No description provided for @registerStepItemLabel.
  ///
  /// In es, this message translates to:
  /// **'Paso {number}: {label}, {status}'**
  String registerStepItemLabel(int number, String label, String status);

  /// No description provided for @registerStepStatusCompleted.
  ///
  /// In es, this message translates to:
  /// **'completado'**
  String get registerStepStatusCompleted;

  /// No description provided for @registerStepStatusCurrent.
  ///
  /// In es, this message translates to:
  /// **'actual'**
  String get registerStepStatusCurrent;

  /// No description provided for @registerStepStatusPending.
  ///
  /// In es, this message translates to:
  /// **'pendiente'**
  String get registerStepStatusPending;

  /// No description provided for @registerContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get registerContinue;

  /// No description provided for @registerBackStep.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get registerBackStep;

  /// No description provided for @registerReviewName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get registerReviewName;

  /// No description provided for @registerReviewEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get registerReviewEmail;

  /// No description provided for @registerReviewPhone.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get registerReviewPhone;

  /// No description provided for @registerReviewNoPhone.
  ///
  /// In es, this message translates to:
  /// **'Sin teléfono'**
  String get registerReviewNoPhone;

  /// No description provided for @registerFirstNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Primer nombre *'**
  String get registerFirstNameLabel;

  /// No description provided for @registerFirstNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Ana'**
  String get registerFirstNameHint;

  /// No description provided for @registerSecondNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Segundo nombre (opcional)'**
  String get registerSecondNameLabel;

  /// No description provided for @registerLastNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Primer apellido *'**
  String get registerLastNameLabel;

  /// No description provided for @registerLastNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Pérez'**
  String get registerLastNameHint;

  /// No description provided for @registerSecondLastNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Segundo apellido (opcional)'**
  String get registerSecondLastNameLabel;

  /// No description provided for @registerEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico *'**
  String get registerEmailLabel;

  /// No description provided for @registerPhoneLabel.
  ///
  /// In es, this message translates to:
  /// **'Teléfono (opcional)'**
  String get registerPhoneLabel;

  /// No description provided for @registerPhoneHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 300 123 4567'**
  String get registerPhoneHint;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña *'**
  String get registerPasswordLabel;

  /// No description provided for @registerPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get registerPasswordHint;

  /// No description provided for @registerConfirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña *'**
  String get registerConfirmPasswordLabel;

  /// No description provided for @registerConfirmPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Repite tu contraseña'**
  String get registerConfirmPasswordHint;

  /// No description provided for @registerNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu nombre'**
  String get registerNameRequired;

  /// No description provided for @registerNameInvalid.
  ///
  /// In es, this message translates to:
  /// **'Nombre incorrecto'**
  String get registerNameInvalid;

  /// No description provided for @registerLastNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu apellido'**
  String get registerLastNameRequired;

  /// No description provided for @registerLastNameInvalid.
  ///
  /// In es, this message translates to:
  /// **'Apellido incorrecto'**
  String get registerLastNameInvalid;

  /// No description provided for @registerPhoneInvalid.
  ///
  /// In es, this message translates to:
  /// **'Teléfono incorrecto'**
  String get registerPhoneInvalid;

  /// No description provided for @registerEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Correo incorrecto'**
  String get registerEmailInvalid;

  /// No description provided for @registerEmailTaken.
  ///
  /// In es, this message translates to:
  /// **'Este correo ya tiene cuenta'**
  String get registerEmailTaken;

  /// No description provided for @registerErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la cuenta, intenta de nuevo'**
  String get registerErrorGeneric;

  /// No description provided for @registerPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa una contraseña'**
  String get registerPasswordRequired;

  /// No description provided for @registerPasswordInvalid.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get registerPasswordInvalid;

  /// No description provided for @registerConfirmRequired.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu contraseña'**
  String get registerConfirmRequired;

  /// No description provided for @registerConfirmMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get registerConfirmMismatch;

  /// No description provided for @registerButton.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get registerButton;

  /// No description provided for @registerHasAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? '**
  String get registerHasAccount;

  /// No description provided for @registerLoginLink.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get registerLoginLink;

  /// No description provided for @forgotTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Te enviamos un código para restablecerla.'**
  String get forgotSubtitle;

  /// No description provided for @forgotSendCode.
  ///
  /// In es, this message translates to:
  /// **'Enviar código'**
  String get forgotSendCode;

  /// No description provided for @forgotStepEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get forgotStepEmailLabel;

  /// No description provided for @forgotStepCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get forgotStepCodeLabel;

  /// No description provided for @forgotStepPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Clave'**
  String get forgotStepPasswordLabel;

  /// No description provided for @forgotCodeTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu correo'**
  String get forgotCodeTitle;

  /// No description provided for @forgotCodeSemantics.
  ///
  /// In es, this message translates to:
  /// **'Código de restablecimiento, {filled} de 6 dígitos'**
  String forgotCodeSemantics(int filled);

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Crea tu nueva contraseña'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige una que no uses en otro lado.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotNewPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña *'**
  String get forgotNewPasswordLabel;

  /// No description provided for @forgotSubmit.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get forgotSubmit;

  /// No description provided for @forgotErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo restablecer la contraseña, intenta de nuevo'**
  String get forgotErrorGeneric;

  /// No description provided for @shellTabHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get shellTabHome;

  /// No description provided for @shellTabOrders.
  ///
  /// In es, this message translates to:
  /// **'Pedidos'**
  String get shellTabOrders;

  /// No description provided for @shellTabProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get shellTabProfile;

  /// No description provided for @shellNotificationsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get shellNotificationsTooltip;

  /// No description provided for @shellCartTooltip.
  ///
  /// In es, this message translates to:
  /// **'Carrito'**
  String get shellCartTooltip;

  /// No description provided for @homeStoreOpen.
  ///
  /// In es, this message translates to:
  /// **'Abierto'**
  String get homeStoreOpen;

  /// No description provided for @homeStoreClosed.
  ///
  /// In es, this message translates to:
  /// **'Cerrado'**
  String get homeStoreClosed;

  /// No description provided for @homeStoreEta.
  ///
  /// In es, this message translates to:
  /// **'Entrega en 30-45 min'**
  String get homeStoreEta;

  /// No description provided for @homePromoTag.
  ///
  /// In es, this message translates to:
  /// **'PROMO'**
  String get homePromoTag;

  /// No description provided for @homePromoTitle.
  ///
  /// In es, this message translates to:
  /// **'2×1 en El Cachorro — solo hoy'**
  String get homePromoTitle;

  /// No description provided for @homeFeaturedTag.
  ///
  /// In es, this message translates to:
  /// **'EL DE LA CASA'**
  String get homeFeaturedTag;

  /// No description provided for @catalogAddTooltip.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get catalogAddTooltip;

  /// No description provided for @catalogBackTooltip.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get catalogBackTooltip;

  /// No description provided for @catalogPromoTooltip.
  ///
  /// In es, this message translates to:
  /// **'Ver promo'**
  String get catalogPromoTooltip;

  /// No description provided for @catalogEmptySubtitle.
  ///
  /// In es, this message translates to:
  /// **'La manada aún está cazando aquí'**
  String get catalogEmptySubtitle;

  /// No description provided for @catalogProductsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 producto} other{{count} productos}}'**
  String catalogProductsCount(int count);

  /// No description provided for @detailSectionRemove.
  ///
  /// In es, this message translates to:
  /// **'¿Se le quita algo?'**
  String get detailSectionRemove;

  /// No description provided for @detailSectionExtras.
  ///
  /// In es, this message translates to:
  /// **'¿Le agregamos algo más?'**
  String get detailSectionExtras;

  /// No description provided for @detailSectionToppings.
  ///
  /// In es, this message translates to:
  /// **'Toppings'**
  String get detailSectionToppings;

  /// No description provided for @detailSectionSauces.
  ///
  /// In es, this message translates to:
  /// **'Salsas'**
  String get detailSectionSauces;

  /// No description provided for @detailTotalLabel.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get detailTotalLabel;

  /// Label del footer del detalle en modo edición con quantity>1 (§021 — el total es por unidad, no por fila)
  ///
  /// In es, this message translates to:
  /// **'Total por unidad'**
  String get detailTotalPerUnitLabel;

  /// Título naciente del detalle en modo edición — cue de orientación (§021)
  ///
  /// In es, this message translates to:
  /// **'Editando · {name}'**
  String detailEditingTitle(String name);

  /// No description provided for @detailAddToCart.
  ///
  /// In es, this message translates to:
  /// **'Agregar al carrito'**
  String get detailAddToCart;

  /// Tag en cards/opciones sin disponibilidad
  ///
  /// In es, this message translates to:
  /// **'Agotado'**
  String get catalogSoldOut;

  /// Título del estado de error del catálogo sin caché
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar la carta'**
  String get catalogLoadErrorTitle;

  /// Subtítulo del estado de error del catálogo
  ///
  /// In es, this message translates to:
  /// **'Revisa tu conexión e inténtalo de nuevo.'**
  String get catalogLoadErrorSubtitle;

  /// Botón de reintento del estado de error
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get catalogRetry;

  /// Detalle abierto con slug de producto eliminado o desconocido
  ///
  /// In es, this message translates to:
  /// **'Este producto ya no está en la carta'**
  String get productUnavailableTitle;

  /// Botón de la vista producto-no-disponible
  ///
  /// In es, this message translates to:
  /// **'Volver al menú'**
  String get productUnavailableCta;

  /// Botón junto a la X de un ingrediente incluido agotado que despliega los adicionales para reemplazarlo gratis (uno por uno)
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get detailSwapCta;

  /// Título de la pantalla del carrito
  ///
  /// In es, this message translates to:
  /// **'Tu carrito'**
  String get cartTitle;

  /// Título del estado vacío del carrito — no repite 'Tu carrito' (ya está en el título de la pantalla)
  ///
  /// In es, this message translates to:
  /// **'Nada por acá todavía'**
  String get cartEmptyTitle;

  /// Subtítulo del estado vacío del carrito
  ///
  /// In es, this message translates to:
  /// **'Suma algo rico del menú'**
  String get cartEmptySubtitle;

  /// Botón del estado vacío que lleva al menú
  ///
  /// In es, this message translates to:
  /// **'Ver el menú'**
  String get cartEmptyCta;

  /// Ghost card al final del carrito no-vacío que invita a seguir pidiendo
  ///
  /// In es, this message translates to:
  /// **'¿Se te antoja algo más?'**
  String get cartBrowseMore;

  /// Etiqueta del subtotal en el footer del carrito
  ///
  /// In es, this message translates to:
  /// **'Subtotal'**
  String get cartSubtotalLabel;

  /// Botón del footer del carrito — provisional hasta checkout (§021)
  ///
  /// In es, this message translates to:
  /// **'Ir a pagar'**
  String get cartCheckoutCta;

  /// Toast de confirmación tras agregar desde el detalle
  ///
  /// In es, this message translates to:
  /// **'Agregado al carrito'**
  String get cartItemAdded;

  /// Toast de feedback al eliminar un ítem del carrito (swipe, stepper en 1 o ícono de basura)
  ///
  /// In es, this message translates to:
  /// **'{name} eliminado del carrito'**
  String cartItemRemoved(String name);

  /// Tooltip/semántica del ícono de basura en la fila del carrito
  ///
  /// In es, this message translates to:
  /// **'Quitar del carrito'**
  String get cartRemoveTooltip;

  /// Tooltip/semántica del botón − del stepper de cantidad
  ///
  /// In es, this message translates to:
  /// **'Quitar uno'**
  String get cartStepperRemove;

  /// Tooltip/semántica del botón + del stepper de cantidad
  ///
  /// In es, this message translates to:
  /// **'Agregar uno'**
  String get cartStepperAdd;

  /// Label semántico del número del stepper de cantidad
  ///
  /// In es, this message translates to:
  /// **'Cantidad: {count}'**
  String cartStepperQty(int count);

  /// Label semántico combinado del botón del carrito con badge (accesibilidad)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Carrito, 1 ítem} other{Carrito, {count} ítems}}'**
  String cartBadgeA11y(int count);

  /// Fallback del panel cuando el ítem no tiene snapshot ni modificadores (§021b)
  ///
  /// In es, this message translates to:
  /// **'Tal cual de la carta'**
  String get cartItemAsIs;

  /// Sección del panel — ingredientes que lleva el ítem
  ///
  /// In es, this message translates to:
  /// **'Ingredientes'**
  String get cartDetailIngredients;

  /// Sección del panel — ingredientes quitados (con vínculo '→' al reemplazo gratis)
  ///
  /// In es, this message translates to:
  /// **'Se le quitó'**
  String get cartDetailRemoved;

  /// Sección del panel — agregados cobrados del ítem
  ///
  /// In es, this message translates to:
  /// **'Adicionales'**
  String get cartDetailExtras;

  /// Sección del panel — toppings gratis del ítem
  ///
  /// In es, this message translates to:
  /// **'Toppings'**
  String get cartDetailToppings;

  /// Sección del panel — salsas gratis del ítem
  ///
  /// In es, this message translates to:
  /// **'Salsas'**
  String get cartDetailSauces;

  /// Texto del chip del tile que despliega el detalle del ítem (§021b)
  ///
  /// In es, this message translates to:
  /// **'Detalle'**
  String get cartItemDetail;

  /// Botón del panel que abre la edición del ítem
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get cartItemEdit;

  /// CTA del detalle en modo edición (reemplaza 'Agregar al carrito')
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get cartEditSaveCta;

  /// Toast al guardar la edición del ítem
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados'**
  String get cartEditSaved;

  /// Título del bottom sheet de alcance al editar qty>1
  ///
  /// In es, this message translates to:
  /// **'¿A cuántos aplicar los cambios?'**
  String get cartEditScopeTitle;

  /// Opción del sheet — aplicar a una sola unidad
  ///
  /// In es, this message translates to:
  /// **'Solo 1'**
  String get cartEditScopeOne;

  /// Opción del sheet — aplicar a todas las unidades
  ///
  /// In es, this message translates to:
  /// **'Las {count}'**
  String cartEditScopeAll(int count);

  /// Label semántico del desplegable del tile (TalkBack anuncia el estado expandible aparte)
  ///
  /// In es, this message translates to:
  /// **'Detalle del perro'**
  String get cartItemDetailToggle;

  /// Toast cuando la edición coincide con otra fila del carrito y se fusionan cantidades
  ///
  /// In es, this message translates to:
  /// **'Se combinó con la fila igual'**
  String get cartEditMerged;

  /// CTA de la vista 'producto no disponible' cuando se llegó desde el carrito (modo edición)
  ///
  /// In es, this message translates to:
  /// **'Volver al carrito'**
  String get cartEditBackToCart;

  /// Título del diálogo al salir del modo edición con cambios sin guardar
  ///
  /// In es, this message translates to:
  /// **'¿Descartar los cambios?'**
  String get cartEditDiscardTitle;

  /// Diálogo descartar — quedarse en la edición
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get cartEditDiscardStay;

  /// Diálogo descartar — salir sin guardar
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get cartEditDiscardLeave;

  /// Título naciente (scrolling_title) de la pantalla de checkout (§022)
  ///
  /// In es, this message translates to:
  /// **'Confirmar pedido'**
  String get checkoutTitle;

  /// Título de la card sección 1 — recoger en el local o domicilio
  ///
  /// In es, this message translates to:
  /// **'Tipo de pedido'**
  String get checkoutOrderTypeSection;

  /// Opción del toggle segmentado — pedido para recoger
  ///
  /// In es, this message translates to:
  /// **'Local'**
  String get checkoutPickupOption;

  /// Opción del toggle segmentado — pedido a domicilio
  ///
  /// In es, this message translates to:
  /// **'Domicilio'**
  String get checkoutDeliveryOption;

  /// Etiqueta sobre la dirección del local en modo recoger
  ///
  /// In es, this message translates to:
  /// **'Lo recoges en'**
  String get checkoutPickupAtLabel;

  /// Aclaración bajo la dirección del local en modo recoger
  ///
  /// In es, this message translates to:
  /// **'Te avisamos cuando esté listo'**
  String get checkoutPickupNotice;

  /// Opción de ubicación que despliega el formulario inline (§022a — puntos de referencia)
  ///
  /// In es, this message translates to:
  /// **'Nueva ubicación'**
  String get checkoutNewAddress;

  /// Label del campo barrio/sector — OPCIONAL en zonas sin división formal (§022a)
  ///
  /// In es, this message translates to:
  /// **'Barrio o sector (opcional)'**
  String get checkoutNeighborhoodLabel;

  /// Hint interior del campo barrio
  ///
  /// In es, this message translates to:
  /// **'Ej: La Esperanza'**
  String get checkoutNeighborhoodHint;

  /// Checkbox mock de la nueva ubicación (§022 — sin persistencia)
  ///
  /// In es, this message translates to:
  /// **'Guardar esta ubicación'**
  String get checkoutSaveAddress;

  /// Checkout: etiqueta del selector de tipo (aparece solo al marcar guardar) — §022b
  ///
  /// In es, this message translates to:
  /// **'¿Qué lugar es?'**
  String get checkoutAddressTypeLabel;

  /// Checkout: chip de tipo casa
  ///
  /// In es, this message translates to:
  /// **'Casa'**
  String get checkoutAddressTypeHome;

  /// Checkout: chip de tipo trabajo
  ///
  /// In es, this message translates to:
  /// **'Trabajo'**
  String get checkoutAddressTypeWork;

  /// Checkout: chip de tipo otro — revela el campo Nombre del lugar
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get checkoutAddressTypeOther;

  /// Checkout: nombre propio cuando el tipo es 'otro' (ej: casa de mi mamá)
  ///
  /// In es, this message translates to:
  /// **'Nombre del lugar'**
  String get checkoutAddressNameLabel;

  /// Checkout: hint del campo Nombre del lugar
  ///
  /// In es, this message translates to:
  /// **'Ej: casa de mi mamá'**
  String get checkoutAddressNameHint;

  /// Error inline de la sección dirección cuando no hay selección al confirmar
  ///
  /// In es, this message translates to:
  /// **'Elige una ubicación'**
  String get checkoutAddressRequired;

  /// Label del campo principal de la nueva ubicación — la zona no tiene direcciones, se guía por puntos de referencia (§022a)
  ///
  /// In es, this message translates to:
  /// **'Punto de referencia *'**
  String get checkoutLandmarkLabel;

  /// Hint interior del punto de referencia
  ///
  /// In es, this message translates to:
  /// **'Ej: casa blanca frente a la cancha'**
  String get checkoutLandmarkHint;

  /// Error inline del punto de referencia — único campo requerido del form (§022a)
  ///
  /// In es, this message translates to:
  /// **'Ingresa el punto de referencia'**
  String get checkoutLandmarkRequired;

  /// Botón del form nueva ubicación — adjunta el pin de Google Maps (mock §022a)
  ///
  /// In es, this message translates to:
  /// **'Adjuntar ubicación de Google'**
  String get checkoutAttachLocation;

  /// Estado tras adjuntar el pin de Google Maps — muestra el link debajo
  ///
  /// In es, this message translates to:
  /// **'Ubicación adjunta'**
  String get checkoutLocationAttached;

  /// Tooltip del botón que quita el pin adjunto
  ///
  /// In es, this message translates to:
  /// **'Quitar ubicación'**
  String get checkoutRemoveLocation;

  /// Label del campo celular de contacto de la entrega — tercera división del bloque de domicilio (§024); prellenado con el phone de la cuenta, editable porque quien recibe puede ser otra persona
  ///
  /// In es, this message translates to:
  /// **'Celular de quien recibe'**
  String get checkoutContactPhoneLabel;

  /// Hint interior del campo celular de contacto (§024)
  ///
  /// In es, this message translates to:
  /// **'3XX XXX XXXX'**
  String get checkoutContactPhoneHint;

  /// Error inline del celular de contacto — requerido en domicilio, debe ser celular colombiano (§024)
  ///
  /// In es, this message translates to:
  /// **'Necesitamos el celular de quien recibe el pedido'**
  String get checkoutContactPhoneRequired;

  /// Valor de la fila Domicilio cuando el fee es 0 — el domicilio ES gratis y debe decirse (§022a)
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get checkoutDeliveryFree;

  /// Título de la card sección 2 — método de pago
  ///
  /// In es, this message translates to:
  /// **'Pago'**
  String get checkoutPaymentSection;

  /// Nota bajo la opción Nequi en modo Local (§022c): no hay pago en efectivo al recoger — regla del negocio
  ///
  /// In es, this message translates to:
  /// **'En el local el pago es solo por transferencia'**
  String get checkoutPickupTransferNote;

  /// Opción de pago Nequi
  ///
  /// In es, this message translates to:
  /// **'Nequi'**
  String get checkoutPayNequi;

  /// Label del campo de celular al que llega el push de Nequi — prellenado con el de la cuenta, editable
  ///
  /// In es, this message translates to:
  /// **'Celular Nequi'**
  String get checkoutNequiPhoneLabel;

  /// Hint interior del campo celular Nequi (mismo del registro)
  ///
  /// In es, this message translates to:
  /// **'Ej: 300 123 4567'**
  String get checkoutNequiPhoneHint;

  /// Error inline genérico del celular Nequi (vacío o formato inválido — misma regla ^3\\d{9}$ del registro)
  ///
  /// In es, this message translates to:
  /// **'Celular incorrecto'**
  String get checkoutNequiPhoneError;

  /// Opción de pago contra entrega en modo domicilio
  ///
  /// In es, this message translates to:
  /// **'Pagar al recibir tu pedido'**
  String get checkoutPayOnDelivery;

  /// Título de la card Observación — nota opcional a nivel pedido, justo bajo Tipo de pedido (§022a)
  ///
  /// In es, this message translates to:
  /// **'Observación'**
  String get checkoutNoteSection;

  /// Hint interior de la observación — ejemplo acorde a la zona (efectivo/cambio, §022a)
  ///
  /// In es, this message translates to:
  /// **'¿Algo que debamos saber? — p. ej. pago con billete de 50, traer cambio'**
  String get checkoutNoteHint;

  /// Título de la card sección 4 — resumen de ítems y totales
  ///
  /// In es, this message translates to:
  /// **'Tu pedido'**
  String get checkoutSummarySection;

  /// Etiqueta de la fila del fee en el resumen — valor 'Gratis' cuando es 0 (§022a)
  ///
  /// In es, this message translates to:
  /// **'Domicilio'**
  String get checkoutDeliveryFeeLabel;

  /// CTA del footer del checkout — dispara la confirmación
  ///
  /// In es, this message translates to:
  /// **'Confirmar pedido'**
  String get checkoutConfirmCta;

  /// Título del diálogo de éxito tras confirmar (flujo simulado §022)
  ///
  /// In es, this message translates to:
  /// **'¡Pedido confirmado!'**
  String get checkoutConfirmedTitle;

  /// Subtítulo del diálogo de éxito — SIN número de orden (§022b: el consecutivo revela el volumen de ventas del negocio, no se expone al cliente)
  ///
  /// In es, this message translates to:
  /// **'Te avisamos cuando esté listo'**
  String get checkoutConfirmedSubtitle;

  /// CTA del diálogo de éxito — cierra, vacía el carrito y navega a Pedidos
  ///
  /// In es, this message translates to:
  /// **'Ver mis pedidos'**
  String get checkoutViewOrdersCta;

  /// Título naciente (scrolling_title) del tab Pedidos (§023)
  ///
  /// In es, this message translates to:
  /// **'Pedidos'**
  String get ordersTitle;

  /// Título de la sección de pedidos terminados del tab (§023)
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get ordersSectionHistory;

  /// Título del estado vacío del tab Pedidos — no repite 'Pedidos' (ya está en el título)
  ///
  /// In es, this message translates to:
  /// **'Aún no has pedido'**
  String get ordersEmptyTitle;

  /// Subtítulo del estado vacío del tab Pedidos
  ///
  /// In es, this message translates to:
  /// **'Tu próximo antojo empieza en el menú'**
  String get ordersEmptySubtitle;

  /// CTA del estado vacío que lleva al menú (mismo texto del carrito vacío)
  ///
  /// In es, this message translates to:
  /// **'Ver el menú'**
  String get ordersBrowseMenu;

  /// Label del servicio de recogida en el local (§023)
  ///
  /// In es, this message translates to:
  /// **'Local'**
  String get orderServicePickup;

  /// Label del servicio a domicilio (§023)
  ///
  /// In es, this message translates to:
  /// **'Domicilio'**
  String get orderServiceDelivery;

  /// Chip/paso: pedido recibido por el local (pending del backend — única ventana de cancelación)
  ///
  /// In es, this message translates to:
  /// **'Recibido'**
  String get orderStatusReceived;

  /// Chip/paso: pedido confirmado por el local
  ///
  /// In es, this message translates to:
  /// **'Confirmado'**
  String get orderStatusConfirmed;

  /// Chip/paso: pedido en preparación (preparing del backend)
  ///
  /// In es, this message translates to:
  /// **'En la plancha'**
  String get orderStatusPreparing;

  /// Chip terminal done en servicio Local (§023 — el paso final se lee 'Listo', no 'Entregado')
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get orderStatusReady;

  /// Chip terminal done en servicio Domicilio
  ///
  /// In es, this message translates to:
  /// **'Entregado'**
  String get orderStatusDelivered;

  /// Chip terminal cancelled — también label del stepper cuando el pedido quedó cancelado
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get orderStatusCancelled;

  /// Label del paso actual del stepper — recibido
  ///
  /// In es, this message translates to:
  /// **'Recibido'**
  String get orderStepReceived;

  /// Label del paso actual del stepper — confirmado
  ///
  /// In es, this message translates to:
  /// **'Confirmado'**
  String get orderStepConfirmed;

  /// Label del paso actual del stepper — en preparación
  ///
  /// In es, this message translates to:
  /// **'En la plancha'**
  String get orderStepPreparing;

  /// Label del paso actual del stepper en done Local — cue de acción para pasar a recoger (§023)
  ///
  /// In es, this message translates to:
  /// **'Listo — ya puedes pasar'**
  String get orderStepReady;

  /// Label del paso actual del stepper en done Domicilio
  ///
  /// In es, this message translates to:
  /// **'Entregado'**
  String get orderStepDelivered;

  /// Línea de entrega del pedido en servicio Local (card activa y detalle)
  ///
  /// In es, this message translates to:
  /// **'Lo recoges en el local'**
  String get orderPickupAtStore;

  /// Indicador de que el pedido lleva el pin de Google Maps adjunto (§022d)
  ///
  /// In es, this message translates to:
  /// **'Con ubicación de Google'**
  String get orderWithLocationPin;

  /// Línea del detalle — celular de quién recibe el pedido (§024, solo delivery; phone ya viene con máscara '3XX XXX XXXX')
  ///
  /// In es, this message translates to:
  /// **'Recibe: {phone}'**
  String orderContactPhone(String phone);

  /// Línea de pago — transferencia Nequi ya pagada
  ///
  /// In es, this message translates to:
  /// **'Nequi · pagado'**
  String get orderPaymentNequiPaid;

  /// Línea de pago — transferencia Nequi pendiente de pago
  ///
  /// In es, this message translates to:
  /// **'Nequi · pago pendiente'**
  String get orderPaymentNequiPending;

  /// Línea de pago — contra entrega (solo domicilio, §022c)
  ///
  /// In es, this message translates to:
  /// **'Pagas al recibir'**
  String get orderPaymentOnDelivery;

  /// Línea de pago en estados terminales — la obligación ya pasó (revisor-ui §023)
  ///
  /// In es, this message translates to:
  /// **'Pagaste al recibir'**
  String get orderPaymentOnDeliveryPast;

  /// Fecha de creación del pedido en el detalle — prefijada para no leerse como fecha del cambio de estado (revisor-ui §023)
  ///
  /// In es, this message translates to:
  /// **'Pedido el {date}'**
  String orderPlacedAt(String date);

  /// Etiqueta semántica del stepper — comunica el progreso a TalkBack (revisor-ui §023)
  ///
  /// In es, this message translates to:
  /// **'Paso {current} de {total}: {step}'**
  String orderStepProgress(int current, int total, String step);

  /// Toast tras cancelar un pedido — feedback mínimo ante destrucción sin deshacer (convención AppToast)
  ///
  /// In es, this message translates to:
  /// **'Pedido cancelado'**
  String get orderCancelledToast;

  /// Conteo de ítems de la fila del historial (misma sintaxis plural de catalogProductsCount)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 ítem} other{{count} ítems}}'**
  String orderItemsCount(int count);

  /// Botón de cancelar en la card del pedido — solo visible en 'Recibido' (regla backend 015)
  ///
  /// In es, this message translates to:
  /// **'Cancelar pedido'**
  String get orderCancelCta;

  /// Título del diálogo de confirmación de cancelación
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar el pedido?'**
  String get orderCancelTitle;

  /// Cuerpo del diálogo de confirmación — explica la ventana de cancelación
  ///
  /// In es, this message translates to:
  /// **'El local aún no lo confirma — puedes cancelar sin problema.'**
  String get orderCancelBody;

  /// Acción destructiva del diálogo — confirma la cancelación
  ///
  /// In es, this message translates to:
  /// **'Sí, cancelar'**
  String get orderCancelConfirm;

  /// Acción del diálogo que conserva el pedido
  ///
  /// In es, this message translates to:
  /// **'No, dejarlo'**
  String get orderCancelKeep;

  /// Título naciente (scrolling_title) del detalle del pedido (§023)
  ///
  /// In es, this message translates to:
  /// **'Detalle del pedido'**
  String get orderDetailTitle;

  /// Sección del detalle — fecha, chip y stepper del pedido
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get orderDetailStatusSection;

  /// Sección del detalle — ítems completos con modificadores y totales (mismo título del resumen del checkout)
  ///
  /// In es, this message translates to:
  /// **'Tu pedido'**
  String get orderDetailItemsSection;

  /// Sección del detalle — servicio, referencia/barrio/pin y método + estado de pago
  ///
  /// In es, this message translates to:
  /// **'Entrega y pago'**
  String get orderDetailDeliverySection;

  /// Sección del detalle — observación del cliente para el local (§022a; solo si existe)
  ///
  /// In es, this message translates to:
  /// **'Observación'**
  String get orderDetailNoteSection;

  /// Fila del subtotal en los totales del detalle
  ///
  /// In es, this message translates to:
  /// **'Subtotal'**
  String get orderSummarySubtotal;

  /// Fila del fee de domicilio en los totales del detalle (solo servicio domicilio)
  ///
  /// In es, this message translates to:
  /// **'Domicilio'**
  String get orderSummaryDelivery;

  /// Valor de la fila Domicilio cuando el fee es 0 (primary — igual que checkout)
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get orderSummaryFree;

  /// Fila del total en los totales del detalle
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get orderSummaryTotal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
