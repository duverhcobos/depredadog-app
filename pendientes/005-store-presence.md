# Pendiente: Presencia en tiendas (Play Store / App Store) — metadata y políticas

> **Estado: 🔴 PENDIENTE** — no hay cuentas de tienda, política de privacidad ni assets de listing
> **Producto:** frontend
> **Bloqueo:** bloqueante para distribución pública — sin política de privacidad ni data-safety no se aprueba la app

## Contexto

Publicar en Play Store / App Store exige más que el build: cuentas de desarrollador, metadata del listing y declaraciones de datos. La app recolecta email, nombre y teléfono (registro) y pedidos/direcciones — eso obliga a política de privacidad y formulario de "seguridad de datos".

## Qué falta

- **Google Play Console** — cuenta (~USD 25 único). **App Store Connect** — cubierta por la cuenta Apple Developer de 004.
- **Política de privacidad** — URL pública obligatoria en ambas tiendas; redactar para los datos reales (auth, pedidos, direcciones).
- **Data safety / App Privacy** — formulario de datos recolectados (Google) y privacy nutrition labels (Apple).
- **Content rating** — cuestionario IARC; la app es de pedidos de comida (sin restricciones especiales esperadas).
- **Assets del listing** — screenshots por tamaño de pantalla, ícono 512 (ya existe `store_assets/` para Play), descripción corta/larga, feature graphic (Play).
- **Decisión de distribución** — ¿solo Play Store al inicio? ¿APK directo para el MVP mientras se aprueba tienda?

## Criterio de cierre

- Listings creados con metadata completa en los stores decididos.
- Política de privacidad publicada en URL estable.
- App en revisión/publicada en al menos un canal.
