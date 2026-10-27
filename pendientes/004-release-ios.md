# Pendiente: Release iOS listo para App Store/TestFlight

> **Estado: 🔴 PENDIENTE** — el proyecto iOS nunca se ha configurado para distribución; depende de 002 (íconos)
> **Producto:** frontend
> **Bloqueo:** bloqueante para iOS — sin firma ni íconos no hay build de App Store

## Contexto

Todo el desarrollo y verificación se ha hecho en Android. La carpeta `ios/` existe del bootstrap pero sin configuración de release: sin equipo de firma, sin `AppIcon.appiconset` de marca (pendiente 002) y sin revisión de `Info.plist` para producción.

## Qué falta

- **Apple Developer Program** — cuenta activa del dueño del negocio (requisito externo, ~USD 99/año).
- **Firma en Xcode** — Team ID, bundle ID final (`com.depredadog.app` o el definitivo), provisioning profiles automáticos o manuales.
- **`AppIcon.appiconset`** — depende de 002 (íconos de marca); incluir la variante de ícono para modo oscuro/tinted de iOS 18+.
- **`Info.plist` de prod** — revisar `NSAppTransportSecurity` (sin excepciones HTTP si la API es HTTPS), `CFBundleDisplayName`, strings de permisos si se agregan features (cámara, ubicación para delivery).
- **Splash/launch screen iOS** — replicar el splash nativo de marca (hoy solo existe en Android).
- **Archive + TestFlight** — `flutter build ipa --release --dart-define=ENV=prod --dart-define=API_BASE_URL=...`, subir a App Store Connect, probar en device real.

## Criterio de cierre

- Build iOS firmado corriendo en TestFlight contra el backend de prod.
- Ícono y splash de marca visibles en iOS.
