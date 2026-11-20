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
  /// **'Ej: casa blanca, reja negra'**
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

  /// Aviso inline del bloque de domicilio cuando GET /addresses falla — cae a 'Nueva ubicación' como única opción con retry (§025)
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus ubicaciones'**
  String get checkoutAddressesError;

  /// Botón de reintento de los avisos inline del checkout (ubicaciones / datos del local)
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get checkoutRetry;

  /// Aviso inline cuando GET /store/config falla — las líneas del local quedan en '—' con retry (§025)
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los datos del local'**
  String get checkoutStoreError;

  /// Mensaje que ocupa el LUGAR del CTA 'Confirmar pedido' cuando isOpen=false confirmado (§029 — ya no es banner ni botón deshabilitado; storeFailed conserva su banner con retry; el backend rechaza con 409)
  ///
  /// In es, this message translates to:
  /// **'El local está cerrado ahora — intenta en el horario de atención'**
  String get checkoutStoreClosed;

  /// Mensaje que reemplaza al CTA 'Ir a pagar' del carrito con el local cerrado (§029)
  ///
  /// In es, this message translates to:
  /// **'El local está cerrado ahora — intenta en el horario de atención'**
  String get cartStoreClosed;

  /// Toast junto al diálogo de éxito cuando POST /addresses falló — el guardado es auxiliar y el pedido siguió igual (§025)
  ///
  /// In es, this message translates to:
  /// **'Pedido confirmado — no pudimos guardar la ubicación'**
  String get checkoutAddressSaveFailed;

  /// Error genérico inline del POST /orders (5xx/inesperado)
  ///
  /// In es, this message translates to:
  /// **'No pudimos confirmar tu pedido — inténtalo de nuevo'**
  String get checkoutOrderFailed;

  /// Error inline del POST /orders rechazado por el backend (400/409) — copy genérico cuando el errorCode llega ausente o desconocido; los motivos conocidos tienen su copy dedicado (§028)
  ///
  /// In es, this message translates to:
  /// **'El local no pudo tomar tu pedido — revísalo e inténtalo de nuevo'**
  String get checkoutOrderRejected;

  /// POST /orders rechazado con STORE_CLOSED (§028)
  ///
  /// In es, this message translates to:
  /// **'El local está cerrado ahora — intenta en el horario de atención'**
  String get checkoutRejectStoreClosed;

  /// POST /orders rechazado con MIN_ORDER_AMOUNT (§028)
  ///
  /// In es, this message translates to:
  /// **'El pedido no llega al mínimo a domicilio — súmele algo más'**
  String get checkoutRejectMinOrder;

  /// POST /orders rechazado con ORDER_CATALOG_VIOLATION — opción agotada/removida/inválida (§028)
  ///
  /// In es, this message translates to:
  /// **'Algo de tu pedido ya no está disponible — revísalo e inténtalo de nuevo'**
  String get checkoutRejectCatalog;

  /// POST /orders rechazado con INVALID_ORDER_DATA (§028)
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos del pedido e inténtalo de nuevo'**
  String get checkoutRejectInvalidData;

  /// Error inline del POST /orders sin conectividad
  ///
  /// In es, this message translates to:
  /// **'Sin internet — revisa tu conexión e inténtalo de nuevo'**
  String get checkoutOrderOffline;

  /// Título naciente (scrolling_title) del tab Pedidos (§023)
  ///
  /// In es, this message translates to:
  /// **'PEDIDOS'**
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

  /// Aviso inline por sección cuando GET /orders falla (activos o historial — cada pierna degrada por separado, §027)
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus pedidos'**
  String get ordersLoadError;

  /// Botón de reintento de los avisos inline del tab Pedidos
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get ordersRetry;

  /// Botón de la fila final del historial — trae la página siguiente del bucket (§027)
  ///
  /// In es, this message translates to:
  /// **'Cargar más'**
  String get ordersLoadMore;

  /// Aviso de la misma fila 'Cargar más' cuando la página siguiente del historial falla — el retry queda en el mismo sitio
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar más pedidos'**
  String get ordersLoadMoreError;

  /// Toast de error genérico al cancelar (offline/5xx — el 409 tiene su propio texto en ordersCancelRejected)
  ///
  /// In es, this message translates to:
  /// **'No pudimos cancelar el pedido — inténtalo de nuevo'**
  String get ordersCancelError;

  /// Toast cuando el backend rechaza la cancelación (409 — el pedido ya salió de pending; el mensaje del servidor viene en inglés y nunca se muestra)
  ///
  /// In es, this message translates to:
  /// **'Este pedido ya no se puede cancelar — el local ya lo tomó'**
  String get ordersCancelRejected;

  /// Título naciente (scrolling_title) del tab Perfil (§030)
  ///
  /// In es, this message translates to:
  /// **'PERFIL'**
  String get profileTitle;

  /// Fila del menú del perfil que empuja a /profile/addresses (§030)
  ///
  /// In es, this message translates to:
  /// **'Mis direcciones'**
  String get profileAddressesRow;

  /// Subtítulo de la fila 'Mis direcciones' — conteo de direcciones guardadas (§030)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin direcciones} =1{{count} guardada} other{{count} guardadas}}'**
  String profileAddressesCount(int count);

  /// Label de la tarjeta del código de referido del perfil (§030)
  ///
  /// In es, this message translates to:
  /// **'Tu código para la manada'**
  String get profileReferralTitle;

  /// Tooltip del botón copiar del número de soporte (§030)
  ///
  /// In es, this message translates to:
  /// **'Copiar número'**
  String get profileCopyNumber;

  /// Tooltip del botón copiar del código de referido (§030)
  ///
  /// In es, this message translates to:
  /// **'Copiar código'**
  String get profileCopyCode;

  /// Toast tras copiar el código de referido al portapapeles (§030)
  ///
  /// In es, this message translates to:
  /// **'Código copiado'**
  String get profileCopiedToast;

  /// Toast tras copiar el número de WhatsApp de soporte al portapapeles (§030)
  ///
  /// In es, this message translates to:
  /// **'Número copiado'**
  String get profileCopiedNumberToast;

  /// Fila destructiva del menú del perfil — abre el diálogo de confirmación de logout (§030)
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get profileLogoutRow;

  /// Título del diálogo de confirmación de cierre de sesión (§030)
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar sesión?'**
  String get profileLogoutConfirmTitle;

  /// Cuerpo del diálogo de confirmación de cierre de sesión (§030)
  ///
  /// In es, this message translates to:
  /// **'Tendrás que iniciar sesión de nuevo para pedir.'**
  String get profileLogoutConfirmBody;

  /// Acción destructiva del diálogo — confirma el cierre de sesión (§030)
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get profileLogoutConfirmAction;

  /// Toast tras confirmar el cierre de sesión en fase mock — cierra el loop mientras llega POST /auth/logout (§030.1, revisor-ui)
  ///
  /// In es, this message translates to:
  /// **'Muy pronto podrás cerrar sesión'**
  String get profileLogoutSoonToast;

  /// Acción neutral de los diálogos del perfil — cierra sin hacer nada (§030)
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get profileCancelAction;

  /// Fila del menú del perfil que abre el diálogo de soporte (§030)
  ///
  /// In es, this message translates to:
  /// **'Soporte'**
  String get profileSupportRow;

  /// Título del diálogo de soporte con el WhatsApp del local (§030)
  ///
  /// In es, this message translates to:
  /// **'Soporte'**
  String get supportDialogTitle;

  /// Cuerpo del diálogo de soporte — antecede el número copiable (§030)
  ///
  /// In es, this message translates to:
  /// **'Escríbenos al WhatsApp del local:'**
  String get supportDialogBody;

  /// Acción del diálogo de soporte — cierra sin más (§030)
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get supportDialogClose;

  /// Título naciente (scrolling_title) de la pantalla de direcciones guardadas (§030)
  ///
  /// In es, this message translates to:
  /// **'Mis direcciones'**
  String get addressesTitle;

  /// Badge mini de la dirección marcada como default (§030)
  ///
  /// In es, this message translates to:
  /// **'Predeterminada'**
  String get addressDefaultBadge;

  /// Opción del menú de la fila de dirección — PATCH {isDefault:true} (§030)
  ///
  /// In es, this message translates to:
  /// **'Marcar predeterminada'**
  String get addressMakeDefault;

  /// Opción destructiva del menú de la fila de dirección (§030)
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get addressDelete;

  /// Título del diálogo de confirmación de borrado de dirección (§030)
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta dirección?'**
  String get addressDeleteConfirmTitle;

  /// Cuerpo del diálogo de confirmación de borrado de dirección (§030)
  ///
  /// In es, this message translates to:
  /// **'La quitarás de tus direcciones guardadas.'**
  String get addressDeleteConfirmBody;

  /// Acción destructiva del diálogo — confirma el borrado (§030)
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get addressDeleteConfirmAction;

  /// Título del estado vacío de la pantalla de direcciones (§030)
  ///
  /// In es, this message translates to:
  /// **'Sin direcciones guardadas'**
  String get addressesEmpty;

  /// Subtítulo del estado vacío de direcciones (§030)
  ///
  /// In es, this message translates to:
  /// **'La próxima vez que pidas a domicilio puedes guardar una.'**
  String get addressesEmptyHint;

  /// CTA al pie de la lista de direcciones — empuja al form de creación (§030)
  ///
  /// In es, this message translates to:
  /// **'Nueva dirección'**
  String get addressesNewCta;

  /// Título naciente del form de dirección en modo crear (§030)
  ///
  /// In es, this message translates to:
  /// **'Nueva dirección'**
  String get addressesNewTitle;

  /// Título naciente del form de dirección en modo editar (§030)
  ///
  /// In es, this message translates to:
  /// **'Editar dirección'**
  String get addressesEditTitle;

  /// Label del campo punto de referencia del form de dirección — único requerido (§030)
  ///
  /// In es, this message translates to:
  /// **'Punto de referencia'**
  String get addressesLandmarkLabel;

  /// Error inline del punto de referencia vacío al guardar (§030)
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos el punto de referencia'**
  String get addressesLandmarkRequired;

  /// Label del campo barrio/sector del form de dirección — opcional (§030)
  ///
  /// In es, this message translates to:
  /// **'Barrio o sector (opcional)'**
  String get addressesNeighborhoodLabel;

  /// Label del campo nombre propio — visible solo cuando el tipo es 'Otro' (§030)
  ///
  /// In es, this message translates to:
  /// **'Nombre de la dirección'**
  String get addressesLabelLabel;

  /// Error inline del nombre vacío cuando el tipo es 'Otro' (§030)
  ///
  /// In es, this message translates to:
  /// **'Ponle un nombre'**
  String get addressesLabelRequired;

  /// CTA del form de dirección — upsert sobre el cubit de la lista (§030)
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get addressFormSave;

  /// Label de la sección del menú del perfil que agrupa los datos del cliente (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Mi cuenta'**
  String get profileSectionAccount;

  /// Label de la sección del menú del perfil que agrupa local + soporte (§030.1)
  ///
  /// In es, this message translates to:
  /// **'El negocio'**
  String get profileSectionBusiness;

  /// Headline de puntos de la tarjeta de fidelidad del perfil (§030.1)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 punto} other{{count} puntos}}'**
  String profileLoyaltyPoints(int count);

  /// Copy de voz bajo el headline de puntos de la tarjeta de fidelidad (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Tu manada te premia'**
  String get profileLoyaltyCopy;

  /// Línea de referidos de la tarjeta de fidelidad — conteo de personas que entraron con el código (§030.1)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Nadie se ha sumado todavía con tu código} =1{1 persona ya se sumó con tu código} other{{count} personas ya se sumaron con tu código}}'**
  String profileLoyaltyReferred(int count);

  /// Tooltip del ícono info (esquina sup. derecha) de la tarjeta de fidelidad (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Cómo funcionan los puntos'**
  String get profileLoyaltyInfoTooltip;

  /// Título del diálogo que explica puntos y código de referidos (§030.1)
  ///
  /// In es, this message translates to:
  /// **'¿Cómo funciona la manada?'**
  String get profileLoyaltyInfoTitle;

  /// Párrafo de puntos del diálogo info de fidelidad — reglas genéricas en fase mock (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Acumulas puntos con cada pedido. Cuando tengas suficientes podrás canjearlos por premios del menú.'**
  String get profileLoyaltyInfoPoints;

  /// Párrafo de referidos del diálogo info de fidelidad — reglas genéricas en fase mock (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Comparte tu código con amigos — cuando hagan su primer pedido se suman a tu manada y tú ganas premios.'**
  String get profileLoyaltyInfoCode;

  /// Botón cerrar del diálogo info de fidelidad (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get profileLoyaltyInfoClose;

  /// Fila del menú del perfil que empuja a /profile/data (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Mis datos'**
  String get profileDataRow;

  /// Título naciente (scrolling_title) del form de datos personales (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Mis datos'**
  String get profileDataTitle;

  /// Label del campo de correo del form de datos — visible pero read-only (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get profileDataEmailLabel;

  /// Helper bajo el campo de correo deshabilitado — explica por qué no se edita (§030.1)
  ///
  /// In es, this message translates to:
  /// **'El correo no se puede cambiar'**
  String get profileDataEmailHelper;

  /// Error inline del teléfono mal formado en Mis datos — copy accionable con la regla (§030.1, revisor-ui)
  ///
  /// In es, this message translates to:
  /// **'Celular de 10 dígitos que inicia en 3'**
  String get profileDataPhoneInvalid;

  /// Toast tras guardar el form de datos personales (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Datos actualizados'**
  String get profileDataSavedToast;

  /// Fila del menú del perfil que empuja a /profile/password (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get profilePasswordRow;

  /// Título naciente (scrolling_title) del form de cambio de contraseña (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get profilePasswordTitle;

  /// Label del campo contraseña actual del form de cambio (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Contraseña actual *'**
  String get profilePasswordCurrentLabel;

  /// Hint del campo contraseña actual del form de cambio (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Escribe tu contraseña'**
  String get profilePasswordCurrentHint;

  /// Error inline de la contraseña actual vacía al guardar (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña actual'**
  String get profilePasswordCurrentRequired;

  /// Toast tras guardar la nueva contraseña (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Contraseña actualizada'**
  String get profilePasswordSavedToast;

  /// Fila del menú del perfil que empuja a /profile/store (§030.1)
  ///
  /// In es, this message translates to:
  /// **'El local'**
  String get profileStoreRow;

  /// Título naciente (scrolling_title) de la pantalla de info del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'El local'**
  String get profileStoreTitle;

  /// Mini-label sobre las 7 filas del horario semanal dentro de la card del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Horario'**
  String get profileStoreHoursLabel;

  /// Nombre del día dayOfWeek=0 del horario semanal del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Domingo'**
  String get storeDaySunday;

  /// Nombre del día dayOfWeek=1 del horario semanal del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Lunes'**
  String get storeDayMonday;

  /// Nombre del día dayOfWeek=2 del horario semanal del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Martes'**
  String get storeDayTuesday;

  /// Nombre del día dayOfWeek=3 del horario semanal del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Miércoles'**
  String get storeDayWednesday;

  /// Nombre del día dayOfWeek=4 del horario semanal del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Jueves'**
  String get storeDayThursday;

  /// Nombre del día dayOfWeek=5 del horario semanal del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Viernes'**
  String get storeDayFriday;

  /// Nombre del día dayOfWeek=6 del horario semanal del local (§030.1)
  ///
  /// In es, this message translates to:
  /// **'Sábado'**
  String get storeDaySaturday;

  /// Título del muro de auth que ve el invitado en el tab Pedidos (§031)
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para ver tus pedidos'**
  String get guestOrdersTitle;

  /// Cuerpo del muro de auth del tab Pedidos para invitado (§031)
  ///
  /// In es, this message translates to:
  /// **'Aquí viven tus pedidos activos y tu historial — entra y síguelos el rastro.'**
  String get guestOrdersBody;

  /// Título de la wall card de auth que ve el invitado en el tab Perfil (§031)
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para ver tu perfil'**
  String get guestProfileTitle;

  /// Cuerpo de la wall card de auth del tab Perfil para invitado (§031)
  ///
  /// In es, this message translates to:
  /// **'Tus datos, direcciones y puntos de la manada te esperan.'**
  String get guestProfileBody;

  /// Label del 4º destino del NavigationBar — solo visible con sesión admin (§034)
  ///
  /// In es, this message translates to:
  /// **'Cocina'**
  String get shellTabAdmin;

  /// Título naciente (scrolling_title) del tab admin — la cola del local (§034)
  ///
  /// In es, this message translates to:
  /// **'COCINA'**
  String get adminQueueTitle;

  /// Chip de canal del pedido admin — llegó por la app (channel=online del backend)
  ///
  /// In es, this message translates to:
  /// **'Online'**
  String get adminChannelOnline;

  /// Etiqueta de canal del pedido admin — tomado en el local por el dueño (channel=presencial). La card la usa como susurro en la esquina; el detalle la usa en la píldora
  ///
  /// In es, this message translates to:
  /// **'Presencial'**
  String get adminChannelInPerson;

  /// Chip de servicio del pedido admin — hay que salir a repartir (serviceType=delivery). Es el dato operativo de la card
  ///
  /// In es, this message translates to:
  /// **'Domicilio'**
  String get adminServiceDelivery;

  /// Chip de servicio del pedido admin — el cliente pasa a recoger (serviceType=pickup, online o mostrador)
  ///
  /// In es, this message translates to:
  /// **'Recogida'**
  String get adminServicePickup;

  /// Chip de servicio del pedido admin — se sirve en mesa (serviceType=dine_in; el número va en la fila cliente)
  ///
  /// In es, this message translates to:
  /// **'Mesa'**
  String get adminServiceDineIn;

  /// Cliente del pedido admin presencial con mesa — table = tableLabel del backend ('Mesa 3')
  ///
  /// In es, this message translates to:
  /// **'En el local · {table}'**
  String adminOrderAtTable(String table);

  /// Cliente del pedido admin presencial sin mesa ni nombre — pedido de mostrador
  ///
  /// In es, this message translates to:
  /// **'En el local'**
  String get adminOrderInHouse;

  /// Tiempo transcurrido del pedido admin cuando lleva menos de 1 h — la cola se opera por frescura
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{hace 1 min} other{hace {count} min}}'**
  String adminOrderElapsedMinutes(int count);

  /// Tiempo transcurrido del pedido admin cuando lleva 1+ h y menos de 24 h
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{hace 1 h} other{hace {count} h}}'**
  String adminOrderElapsedHours(int count);

  /// Chip de estado del pedido admin en pending del backend (el cliente lo lee 'Recibido' — el dueño lo opera como pendiente de confirmar)
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get adminStatusPending;

  /// Método de pago del pedido admin — cash del backend
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get adminPaymentCash;

  /// Método de pago Nequi dentro de la app (cobro por push/pasarela que confirma el webhook, §036)
  ///
  /// In es, this message translates to:
  /// **'Nequi'**
  String get adminPaymentNequi;

  /// Rótulo NO interactivo en el slot de acción de la card/detalle admin — el pedido Nequi no tiene botones hasta que el webhook confirme (§036)
  ///
  /// In es, this message translates to:
  /// **'Esperando confirmación de Nequi…'**
  String get adminAwaitingNequiHint;

  /// Rótulo NO interactivo del pedido Nequi fallido — el webhook ya reportó el rechazo, la única salida es cancelar (§036)
  ///
  /// In es, this message translates to:
  /// **'Nequi rechazó el pago — cancela el pedido'**
  String get adminNequiFailedHint;

  /// Método de pago del pedido admin — transfer del backend (Nequi/gateway)
  ///
  /// In es, this message translates to:
  /// **'Transf.'**
  String get adminPaymentTransfer;

  /// Chip de estado de pago del pedido admin — aún no se confirma el pago
  ///
  /// In es, this message translates to:
  /// **'Pago pendiente'**
  String get adminPaymentPending;

  /// Chip de estado de pago del pedido admin — pago confirmado
  ///
  /// In es, this message translates to:
  /// **'Pagado'**
  String get adminPaymentPaid;

  /// Chip de estado de pago del pedido admin — la pasarela rechazó el cobro
  ///
  /// In es, this message translates to:
  /// **'Pago fallido'**
  String get adminPaymentFailed;

  /// Título del vacío de la cola admin sin pedidos vivos
  ///
  /// In es, this message translates to:
  /// **'Sin pedidos activos'**
  String get adminQueueEmptyActiveTitle;

  /// Cuerpo del vacío de la cola admin sin pedidos vivos (§034)
  ///
  /// In es, this message translates to:
  /// **'La cocina descansa — los pedidos nuevos caen aquí solos.'**
  String get adminQueueEmptyActiveBody;

  /// Título del vacío del historial de la cola admin
  ///
  /// In es, this message translates to:
  /// **'Historial vacío'**
  String get adminQueueEmptyHistoryTitle;

  /// Cuerpo del vacío del historial de la cola admin
  ///
  /// In es, this message translates to:
  /// **'Los pedidos terminados y cancelados quedan aquí.'**
  String get adminQueueEmptyHistoryBody;

  /// Estado de error de la cola admin — acompaña el botón Reintentar
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar la cola'**
  String get adminQueueLoadError;

  /// Tooltip del FAB flecha que regresa el carril (y el header) al inicio tras mucho scroll — Cocina kanban (§036)
  ///
  /// In es, this message translates to:
  /// **'Volver arriba'**
  String get adminBackToTop;

  /// Label del FAB de la cola admin — orden presencial a un clic (§034, form en ciclo 3)
  ///
  /// In es, this message translates to:
  /// **'Nueva orden'**
  String get adminNewOrder;

  /// Sufijo del resumen de ítems de la card admin cuando no caben todos en 2 líneas — recorte honesto: el dueño sabe cuántos faltan sin abrir el detalle (decisión §034)
  ///
  /// In es, this message translates to:
  /// **'+{count} más'**
  String adminOrderItemsMore(int count);

  /// Botón de acción de la card/detalle admin para pedido pending — avanza a confirmed (PATCH status del backend, §035)
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get adminActionConfirm;

  /// Botón de cobro de la card/detalle admin — confirma el pago pendiente (POST confirm-payment del backend, §035)
  ///
  /// In es, this message translates to:
  /// **'Registrar pago'**
  String get adminActionPaid;

  /// Pista bajo el botón siguiente paso deshabilitado del detalle admin — la puerta exige pago cobrado (invariante PaymentNotSettled del backend + puerta de recogida, §035/§036)
  ///
  /// In es, this message translates to:
  /// **'Registra el pago primero'**
  String get adminDoneNeedsPayment;

  /// Identificador corto del pedido en el header del detalle admin (§035) — id = cola del orderId (6 últimos caracteres o el id completo si es corto)
  ///
  /// In es, this message translates to:
  /// **'#{id}'**
  String adminOrderShortId(String id);

  /// Título de la sección header del detalle admin — chips canal+estado, cliente/mesa y frescura (§035)
  ///
  /// In es, this message translates to:
  /// **'Pedido'**
  String get adminOrderDetailOrderSection;

  /// Título de la sección de ítems completos del detalle admin — una fila por ítem + total (§035)
  ///
  /// In es, this message translates to:
  /// **'Ítems'**
  String get adminOrderDetailItemsSection;

  /// Título de la sección de pago del detalle admin — método + estado + botón 'Registrar pago' cuando el pago está pendiente (§035)
  ///
  /// In es, this message translates to:
  /// **'Pago'**
  String get adminOrderDetailPaymentSection;

  /// Título de la sección de entrega del detalle admin — dirección/referencia/barrio/pin/teléfono en domicilio o línea de recogida en el local; no renderiza en mesa (§037)
  ///
  /// In es, this message translates to:
  /// **'Entrega'**
  String get adminOrderDetailDeliverySection;

  /// Línea única de la sección Entrega del detalle admin para pedidos pickup — vista del dueño (§037)
  ///
  /// In es, this message translates to:
  /// **'Lo recogen en el local'**
  String get adminOrderPickupAtStore;

  /// Toast de éxito al copiar el celular de contacto del pedido al portapapeles desde la sección Entrega del detalle admin (§037)
  ///
  /// In es, this message translates to:
  /// **'Teléfono copiado'**
  String get adminOrderPhoneCopied;

  /// Etiqueta de accesibilidad (Semantics) de la fila de teléfono de contacto copiable en la sección Entrega del detalle admin (§037)
  ///
  /// In es, this message translates to:
  /// **'Copiar teléfono'**
  String get adminOrderCopyPhone;

  /// Etiqueta de accesibilidad (Semantics) de la fila del pin de ubicación del cliente — tocarla abre Google Maps con el punto del domicilio (§037)
  ///
  /// In es, this message translates to:
  /// **'Abrir ubicación en Maps'**
  String get adminOrderOpenPin;

  /// Tooltip del ícono copiar junto al pin de ubicación del cliente — copia el enlace de Maps con las coordenadas (§037)
  ///
  /// In es, this message translates to:
  /// **'Copiar ubicación'**
  String get adminOrderCopyPin;

  /// Toast de éxito al copiar el enlace de Maps del pin del cliente al portapapeles desde la sección Entrega del detalle admin (§037)
  ///
  /// In es, this message translates to:
  /// **'Ubicación copiada'**
  String get adminOrderPinCopied;

  /// Cuerpo del diálogo de confirmación de cancelación del detalle admin (§035)
  ///
  /// In es, this message translates to:
  /// **'El pedido sale de la cola y queda en el historial como cancelado.'**
  String get adminOrderCancelBody;

  /// Label del campo de motivo opcional del diálogo de cancelación admin — viaja como cancelReason del backend (§035)
  ///
  /// In es, this message translates to:
  /// **'Motivo (opcional)'**
  String get adminOrderCancelReasonLabel;

  /// Toast de éxito tras avanzar un pedido pending a confirmed en la cola admin (§035)
  ///
  /// In es, this message translates to:
  /// **'Pedido confirmado'**
  String get adminToastOrderConfirmed;

  /// Toast de éxito tras marcar el pago de un pedido admin como cobrado — 'me pagó' (§035)
  ///
  /// In es, this message translates to:
  /// **'Pago confirmado'**
  String get adminToastPaymentConfirmed;

  /// Toast de éxito tras marcar un pedido admin como entregado — queda en el carril Entregado hasta el cierre de caja (§036)
  ///
  /// In es, this message translates to:
  /// **'Pedido entregado'**
  String get adminToastOrderDone;

  /// Botón de acción de la card/detalle admin para pedido confirmed — avanza a preparing, 'a la plancha' (§036)
  ///
  /// In es, this message translates to:
  /// **'Preparar'**
  String get adminActionPrepare;

  /// Label del paso a ready para pedidos delivery — la acción de la card/detalle admin lo marca saliendo a domicilio (§036)
  ///
  /// In es, this message translates to:
  /// **'Va en camino'**
  String get adminActionOnTheWay;

  /// Label del paso a ready para pedidos dine_in — la acción de la card/detalle admin lo marca servido a la mesa (§036)
  ///
  /// In es, this message translates to:
  /// **'Servir'**
  String get adminActionServe;

  /// Label del paso a ready para pedidos pickup — la acción de la card/detalle admin lo deja listo para que lo recojan (§036)
  ///
  /// In es, this message translates to:
  /// **'Listo p/recoger'**
  String get adminActionReadyPickup;

  /// Botón de acción de la card/detalle admin para pedido ready+pagado — marca done; queda en el carril Entregado hasta el cierre de caja (§036)
  ///
  /// In es, this message translates to:
  /// **'Entregado'**
  String get adminActionDeliver;

  /// Label corto alterno del botón de cierre del header de Cocina (§036) — hoy el botón es ícono solo; clave reservada si el label vuelve
  ///
  /// In es, this message translates to:
  /// **'Caja'**
  String get adminCloseDayShort;

  /// Título de la pantalla provisional de historial admin + tooltip del ícono 🕐 del header de Cocina (§036)
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get adminHistoryTitle;

  /// Título de la pantalla de cierre de caja del día admin (§036)
  ///
  /// In es, this message translates to:
  /// **'Cierre de caja'**
  String get adminDayCloseTitle;

  /// Label del hero del total vendido en el resumen del cierre de caja (§036)
  ///
  /// In es, this message translates to:
  /// **'Vendido hoy'**
  String get adminDayCloseTotal;

  /// CTA que ejecuta el cierre de caja tras el preview del resumen (§036)
  ///
  /// In es, this message translates to:
  /// **'Confirmar cierre'**
  String get adminDayCloseConfirm;

  /// Botón que cierra la pantalla de resultado del cierre de caja y vuelve a Cocina (§036)
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get adminDayCloseDone;

  /// Fila del resumen del cierre de caja con la cantidad de pedidos entregados que se archivan (§036)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 pedido entregado} other{{count} pedidos entregados}}'**
  String adminDayCloseOrders(int count);

  /// Fila de contexto del resumen del cierre de caja — cancelados del periodo con su monto; no suma al total (§036)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 cancelado} other{{count} cancelados}} · {amount}'**
  String adminDayCloseCancelled(int count, String amount);

  /// Nota del resumen del cierre de caja cuando no hubo pedidos entregados — el cierre vacío está permitido (§036)
  ///
  /// In es, this message translates to:
  /// **'Cierre del día — sin pedidos entregados. El registro queda como bitácora.'**
  String get adminDayCloseEmpty;

  /// Vista de error del preview del cierre de caja cuando el GET /admin/day-close falla — con botón Reintentar (§041)
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar el cierre'**
  String get adminDayCloseLoadError;

  /// Toast de éxito tras avanzar un pedido admin de confirmed a preparing (§036)
  ///
  /// In es, this message translates to:
  /// **'Pedido a la plancha'**
  String get adminToastOrderPreparing;

  /// Toast de éxito tras avanzar un pedido admin de preparing a ready — listo / en camino / servido según el canal (§036)
  ///
  /// In es, this message translates to:
  /// **'Pedido listo'**
  String get adminToastOrderReady;

  /// Toast de error genérico al avanzar/cancelar un pedido admin (offline/5xx — convención ordersCancelError §027)
  ///
  /// In es, this message translates to:
  /// **'No pudimos actualizar el pedido — inténtalo de nuevo'**
  String get adminToastActionFailed;

  /// Toast cuando el backend rechaza la mutación con 409 (INVALID_STATUS_TRANSITION/PAYMENT_NOT_SETTLED — la cola ya se resincronizó sola; el mensaje del servidor viene en inglés y nunca se muestra)
  ///
  /// In es, this message translates to:
  /// **'El pedido ya cambió — la cola se actualizó'**
  String get adminToastActionRejected;

  /// Toast de éxito tras confirmar el cierre de caja del día — total = total vendido formateado (§036)
  ///
  /// In es, this message translates to:
  /// **'Día cerrado — {total}'**
  String adminToastDayClosed(String total);

  /// Toast de error específico del cobro manual admin (POST confirm-payment offline/5xx — el 409 usa el genérico 'el pedido ya cambió', §041)
  ///
  /// In es, this message translates to:
  /// **'No pudimos registrar el pago — inténtalo de nuevo'**
  String get adminToastPaymentFailed;

  /// Toast de error cuando el POST /admin/day-close falla — la pantalla se queda en el preview para reintentar (§041)
  ///
  /// In es, this message translates to:
  /// **'No pudimos cerrar la caja — inténtalo de nuevo'**
  String get adminToastDayCloseFailed;

  /// Vacío compacto de un carril del kanban de Cocina sin pedidos — el carril existe aunque esté vacío (§036)
  ///
  /// In es, this message translates to:
  /// **'Sin pedidos'**
  String get adminLaneEmpty;

  /// Título naciente de la comanda presencial del dueño (§042 — paso comanda)
  ///
  /// In es, this message translates to:
  /// **'Nueva orden'**
  String get adminNewOrderTitle;

  /// Título naciente del paso cobro de la comanda presencial (§042 — esqueleto _CobroTitle)
  ///
  /// In es, this message translates to:
  /// **'Revisar y cobrar'**
  String get adminNewOrderReviewTitle;

  /// CTA del footer del paso comanda que lleva al paso cobro (§042)
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get adminNewOrderContinue;

  /// Conteo de unidades del ticket en el footer del paso comanda (§042)
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 ítem} other{{count} ítems}}'**
  String adminNewOrderItems(int count);

  /// CTA del footer del paso cobro que manda el POST /admin/orders (§042)
  ///
  /// In es, this message translates to:
  /// **'Crear pedido'**
  String get adminNewOrderCreate;

  /// Título de la vista de éxito de la comanda presencial (§043) — number = consecutivo del día, o el tag adm-N si el POST no lo trajo
  ///
  /// In es, this message translates to:
  /// **'Pedido #{number} creado'**
  String adminNewOrderCreatedTitle(String number);

  /// CTA secundario de la vista de éxito de la comanda (§043) — pop a la cola kanban, que ya se resincronizó en el éxito
  ///
  /// In es, this message translates to:
  /// **'Volver a Cocina'**
  String get adminNewOrderBackToQueue;

  /// CTA primario de la vista de éxito de la comanda (§043) — abre wa.me con el pedido redactado para el chat de cocina; voz de negocio como el tooltip (revisor-estetico: 'Compartir por WhatsApp' rompía en dos líneas)
  ///
  /// In es, this message translates to:
  /// **'Enviar a cocina'**
  String get adminShareWhatsApp;

  /// Tooltip del ícono compartir del detalle admin (§043 v2) — lanza el share sheet con la card PNG de cada ítem; ya no menciona WhatsApp: el chooser es del sistema (revisor-ui §043)
  ///
  /// In es, this message translates to:
  /// **'Enviar comanda a cocina'**
  String get adminShareWhatsAppTooltip;

  /// Toast de error cuando el render PNG o el share sheet lanzan (§043 v2 — genérico: ya no es un fallo de WhatsApp, es de la comanda entera)
  ///
  /// In es, this message translates to:
  /// **'No pudimos compartir la comanda'**
  String get adminShareWhatsAppFailed;

  /// Etiqueta de la sección tipo de servicio del paso cobro (§042)
  ///
  /// In es, this message translates to:
  /// **'Servicio'**
  String get adminNewOrderService;

  /// Chip del servicio dine_in (pedido a mesa del local, §042)
  ///
  /// In es, this message translates to:
  /// **'Mesa'**
  String get adminNewOrderDineIn;

  /// Chip del servicio pickup (pedido de mostrador/para llevar, §042)
  ///
  /// In es, this message translates to:
  /// **'Para llevar'**
  String get adminNewOrderPickup;

  /// Chip de filtro sin categoría de la comanda — muestra la carta completa (§042)
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get adminNewOrderCategoryAll;

  /// Etiqueta de la sección método de pago del paso cobro (§042)
  ///
  /// In es, this message translates to:
  /// **'Pago'**
  String get adminNewOrderPayment;

  /// Label del campo celular del pagador — visible solo en Transf. (§042, exigido por el contrato)
  ///
  /// In es, this message translates to:
  /// **'Celular que recibe el cobro'**
  String get adminNewOrderPayerPhone;

  /// Hint del campo celular del pagador (§042 — formato 3XXXXXXXXX)
  ///
  /// In es, this message translates to:
  /// **'Ej: 3001234567'**
  String get adminNewOrderPhoneHint;

  /// Error inline del campo celular cuando no cumple ^3\d{9}$ — solo en Transf. (§042)
  ///
  /// In es, this message translates to:
  /// **'Escribe el celular de 10 dígitos'**
  String get adminNewOrderPhoneError;

  /// Label del campo de nota del pedido completo — maxLength 500 (§042; items[].notes fuera de alcance). Corto: el label vive en la zona angosta y 'Nota del pedido (opcional)' truncaba a media palabra (revisor-estetico §042)
  ///
  /// In es, this message translates to:
  /// **'Nota (opcional)'**
  String get adminNewOrderNote;

  /// Vacío de la lista de la comanda cuando la categoría filtrada no tiene productos (§042)
  ///
  /// In es, this message translates to:
  /// **'Sin productos en esta categoría'**
  String get adminNewOrderEmpty;

  /// Vacío del bloque de ítems del paso cobro (§042)
  ///
  /// In es, this message translates to:
  /// **'Toca un producto para agregarlo'**
  String get adminNewOrderTicketEmpty;

  /// Tag de la mesa ocupada en el picker — number = consecutivo del pedido vivo que la tiene (§042)
  ///
  /// In es, this message translates to:
  /// **'#{number}'**
  String adminNewOrderTableBusy(int number);

  /// CTA del sheet de personalización que produce el CartItem y cierra (§042)
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get adminNewOrderSheetAdd;

  /// Vista de error de la comanda cuando la carga de carta+mesas falla — con botón Reintentar (§042)
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar la comanda'**
  String get adminNewOrderLoadError;

  /// Toast del submit cuando el backend responde 409 ORDER_CATALOG_VIOLATION — un ítem se agotó en el medio (§042)
  ///
  /// In es, this message translates to:
  /// **'Un ítem ya no está disponible — revisa la comanda'**
  String get adminNewOrderCatalogViolation;

  /// Toast del submit cuando el backend responde 404 TABLE_NOT_FOUND — las mesas se resincronizan solas (§042)
  ///
  /// In es, this message translates to:
  /// **'La mesa cambió — elige otra'**
  String get adminNewOrderTableStale;

  /// Toast del submit cuando el backend responde 502 PAYMENT_DISPATCH_FAILED — el push transfer no salió (§042)
  ///
  /// In es, this message translates to:
  /// **'No pudimos enviar el cobro — cobra en efectivo o inténtalo de nuevo'**
  String get adminNewOrderDispatchFailed;

  /// Línea de servicio del pedido dine_in SIN mesa conocida en la comanda de cocina (§043) — con tableLabel la línea es la etiqueta verbatim ('Mesa 2')
  ///
  /// In es, this message translates to:
  /// **'En el local'**
  String get shareWaServiceInSite;

  /// Línea de servicio del pedido pickup en la comanda de cocina (§043)
  ///
  /// In es, this message translates to:
  /// **'Para llevar'**
  String get shareWaServicePickup;

  /// Línea de servicio del pedido delivery en la comanda de cocina (§043) — le siguen la línea dirección+referencia y el teléfono del cliente
  ///
  /// In es, this message translates to:
  /// **'Domicilio'**
  String get shareWaServiceDelivery;

  /// Etiqueta en negrita de la nota del pedido en la comanda de cocina (§043 — la línea entera se omite si la nota viene vacía o solo espacios)
  ///
  /// In es, this message translates to:
  /// **'Nota:'**
  String get shareWaNoteLabel;

  /// Etiqueta del total final de la comanda de cocina (§043 — única cifra del mensaje: cocina no arma precios por ítem, el total es por si quien entrega cobra). 'del pedido' explícito: en una card self-contained, 'Total:' sugería el total de ESE ítem (revisor-ui §043)
  ///
  /// In es, this message translates to:
  /// **'Total del pedido:'**
  String get shareWaTotalLabel;

  /// Índice del ítem dentro del pedido en el header de la card de cocina (§043 v2) — '1/2' = ítem 1 de 2; la card lo omite cuando el pedido trae una sola card ('1/1' era ruido, revisor-ui §043)
  ///
  /// In es, this message translates to:
  /// **'{index}/{total}'**
  String shareWaItemIndex(int index, int total);

  /// Tag del pedido en el header de la card de cocina (§043 v2) — number es el shortTag 'adm-N' en ambos caminos (éxito y detalle) para que cocina lea el MISMO identificador
  ///
  /// In es, this message translates to:
  /// **'PEDIDO #{number}'**
  String shareWaOrderTag(String number);
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
