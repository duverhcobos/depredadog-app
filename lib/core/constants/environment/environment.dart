/// Emisor único de configuración de entorno (ver ENVIRONMENTS.md).
/// Toda variable externa entra por --dart-define y se centraliza aquí;
/// ningún otro archivo lee variables de entorno directamente.
enum EnvType { dev, stg, prod }

class Environment {
  Environment._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  // Switch-expression no es válida en contexto const — ternaria equivalente.
  static const EnvType currentEnvironment = _env == 'stg'
      ? EnvType.stg
      : _env == 'prod'
      ? EnvType.prod
      : EnvType.dev;

  /// Base URL del backend. En dev con emulador Android, 10.0.2.2 = localhost
  /// del host. En dispositivo físico: `--dart-define=API_BASE_URL=http://<ip-lan>:3000`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const bool isDev = currentEnvironment == EnvType.dev;
  static const bool isStg = currentEnvironment == EnvType.stg;
  static const bool isProd = currentEnvironment == EnvType.prod;
}
