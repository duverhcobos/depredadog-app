/// Tags de `Hero` compartidos entre pantallas — centralizados para que no
/// se dupliquen/desincronicen entre features (ver splash → login).
class HeroTags {
  HeroTags._();

  /// Imagotipo de marca: vuela del splash al header del login.
  static const String brandImagotipo = 'brand_imagotipo';
}
