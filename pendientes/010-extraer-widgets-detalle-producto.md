# Pendiente: Extraer widgets del detalle de producto (umbral de tamaño)

> **Estado: 🔴 PENDIENTE** — detectado en evaluacion-modulo de catalog
> **Producto:** app
> **Bloqueo:** recomendado — convención `file-size-refactoring`
> obligatoria incumplida; mantenibilidad, no funcionalidad

## Contexto

`lib/features/home/presentation/screens/product_detail_screen.dart`
quedó en **543 líneas** tras el cambio gratis — el umbral del skill es
~450 para extracción obligatoria. Además
`lib/features/home/presentation/widgets/customization_section.dart` está
en 369 — por encima del umbral de "evaluar extracción" (~300).

El build del detalle mezcla hoy: título + header card + las tres
variantes de la fila agotada (fila atenuada, picker animado de
reemplazo, fila elegida con gancho ↳) + footer. El bloque
agotada→picker→elegida (~100 líneas) es el candidato natural de
extracción — ej. un `RemovableSwapBlock` que recibe la opción,
`_swapCandidates`, `_replacements` y los callbacks.

## Qué falta

- Extraer el bloque de reemplazo (y lo que resulte natural) de
  `product_detail_screen.dart` hasta quedar bajo el umbral.
- Evaluar si `customization_section.dart` también se parte
  (RemovableRow/OptionRow/SelectChip ya son widgets internos suyos).
- Re-correr tests del detalle tras la extracción.

## Criterio de cierre

- `product_detail_screen.dart` < ~450 líneas; `flutter analyze` y la
  suite verdes; comportamiento idéntico (los 11 tests del detalle
  pasan sin cambios de aserción).
