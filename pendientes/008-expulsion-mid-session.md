# Pendiente: Expulsión de sesión a mitad de uso no navega sola

> **Estado: 🔴 PENDIENTE**
> **Producto:** frontend
> **Bloqueo:** recomendado — el guard la atrapa en la próxima navegación,
> pero la pantalla actual queda abierta mostrando UI autenticada sin sesión

## Contexto

Cuando el refresh token falla de forma definitiva a mitad de uso del usuario
(expiró, reuso detectado, revocada), `TokenRefreshService` borra las claves y
llama `AuthSession.markLoggedOut()` — pero eso solo apaga el flag en RAM. El
`GoRouter` se construye una vez y su `redirect` solo corre al navegar: el
usuario permanece en la pantalla actual (autenticada) hasta tocar algo que
navegue; ahí el guard sí lo expulsa a `/login`.

Además, los requests siguientes devolverán 401 (sin tokens) — visible como
errores de datos, no como "sesión cerrada".

## Qué falta

- `refreshListenable` del `GoRouter` conectado a `AuthSession` (notifier),
  o un mecanismo equivalente que dispare el redirect del guard apenas
  `markLoggedOut` corra — expulsión inmediata a `/login` con toast
  "Tu sesión expiró".
- Opcional: al detectar la expulsión, `markLoggedOut` podría notificar un
  motivo (expirada vs. comprometida) para el copy del toast.

## Criterio de cierre

- Con sesión vencida a mitad de uso, la app navega a `/login` sola (sin
  requerir que el usuario toque algo que navegue).
