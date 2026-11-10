/// Estado operativo del local — lo resuelve GET /store/config
/// (backend 013). `unknown` cubre "aún no se consultó" y "la
/// consulta falló": solo `closed` CONFIRMADO bloquea CTAs; unknown
/// deja pasar porque el checkout tiene su propia compuerta con
/// retry y el backend es la última línea (§029 — decisión usuario).
enum StoreOpenState { open, closed, unknown }
