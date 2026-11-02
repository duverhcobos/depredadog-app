import 'package:google_sign_in/google_sign_in.dart';

import '../../../../../core/constants/environment/environment.dart';
import '../interfaces/i_google_sign_in_gateway.dart';

/// Wrapper del plugin `google_sign_in` v7: initialize() una sola vez (lazy,
/// al primer tap — sin costo de arranque) con el serverClientId del
/// --dart-define; authenticate() abre el selector nativo y devuelve el
/// idToken. Cancel = GoogleSignInException(code: canceled) → null.
class GoogleSignInGatewayImpl implements IGoogleSignInGateway {
  GoogleSignInGatewayImpl({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  bool _initialized = false;

  @override
  Future<String?> getIdToken() async {
    if (!_initialized) {
      await _signIn.initialize(
        serverClientId: Environment.googleServerClientId,
      );
      _initialized = true;
    }
    try {
      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;
      // authenticate() puede resolver sin idToken (config sin serverClientId
      // válido): null aquí no es cancel — se propaga para que el repository
      // lo traduzca a UnknownAuthFailure y la UI muestre el error genérico.
      if (idToken == null) {
        throw StateError('authenticate() resolvió sin idToken');
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
