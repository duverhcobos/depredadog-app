import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../orders/presentation/utils/format_order_date.dart';
import '../../domain/entities/admin_order.dart';
import '../utils/kitchen_order_data.dart';

/// Card-imagen de la comanda de cocina (§043 v2 — decisión del dueño:
/// "opción A pero sin la imagen del perro"): UNA card por ítem del
/// pedido, self-contained — cocina puede recibir solo una y leer
/// pedido, hora, servicio, entrega, pago, nota y total. Sin foto del
/// producto ni precios por mod.
///
/// TIQUETE VERTICAL (§043 v4 — decisión del dueño: la apaisada de
/// 600px achicaba el texto en el preview de WhatsApp): columna fija
/// de 420 logical px que crece con el contenido — el idioma del
/// tiquete de cocina. Header centrado (wordmark + tag), divisores
/// punteados, cuerpo a la izquierda y el total rematando centrado.
///
/// Marca de agua: el ISOTIPO (escudo del imagotipo dark) centrado
/// detrás del texto al ~6% — en la columna angosta la firma lateral
/// aplastaba contra las líneas; centrada queda sello de fondo. El
/// wordmark del asset vive en su ~26% inferior y queda fuera del
/// clip topCenter+cover: la firma es la marca gráfica pura.
///
/// Presentación pura: todas las líneas llegan ARMADAS por parámetro
/// (tag/footers/nota/total) o en `item.sections` (títulos + nombres
/// ya redactados por la factory con l10n) — el widget no pregunta a
/// AppLocalizations, solo a ColorScheme/TextTheme.
class KitchenItemCard extends StatelessWidget {
  const KitchenItemCard({
    required this.item,
    required this.orderTag,
    this.indexText,
    required this.footerLines,
    this.noteLine,
    this.totalLine,
    this.spacerGap = 0,
    super.key,
  });

  /// El ítem ya repartido en secciones (§043 v5): la card solo
  /// itera `sections` — cada título llega localizado y cada nombre
  /// es texto pelado (el reparto y el vínculo "X → reemplazo" los
  /// compone el caller con l10n).
  final KitchenOrderLine item;

  /// 'PEDIDO #adm-1' — armado por el caller (mismo identificador en
  /// la vista de éxito y en el reenvío desde el detalle).
  final String orderTag;

  /// '1/2' — pista de posición de la card, solo cuando el pedido
  /// trae más de una (una card única no la gasta: '1/1' era ruido,
  /// revisor-ui §043). Llega armada — la card no pregunta a l10n.
  final String? indexText;

  /// Footer operativo (α0.85 bodyMedium — es la línea que manda la
  /// entrega, no metadato): primera = 'servicio · pago · hora del
  /// pedido'; las siguientes = bloque de entrega del domicilio —
  /// dirección+referencia y teléfono (el dueño reparte).
  final List<String> footerLines;

  /// 'Nota: …' — solo llega cuando la nota no va vacía (regla §043:
  /// la nota en blanco no gasta línea).
  final String? noteLine;

  /// 'Total: $N' — única cifra de la card, por si quien entrega cobra.
  final String? totalLine;

  /// Bolsón de aire antes del divisor del footer (§043 v4/v6): el
  /// render mide la card natural en un primer frame y si quedó
  /// más baja que el piso de tiquete la repinta con este gap — el
  /// footer ancla al pie como en una comanda impresa. No usa
  /// Spacer+IntrinsicHeight: Row+Expanded subestima los wraps en
  /// el paso intrínseco y la altura salía corta con texto grande.
  final double spacerGap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final strong = colors.onSurface.withValues(alpha: 0.85);
    final meta = text.bodySmall?.copyWith(color: muted, fontSize: 14);
    // Marca un paso sobre el metadato — empareja la cadena
    // marca→ítem sin costo (revisor-estetico §043).
    final brand = text.labelLarge?.copyWith(
      color: strong,
      fontWeight: FontWeight.w700,
      fontSize: 18,
      letterSpacing: 1.0,
    );
    // Tipografía de tiquete AGRANDADA (§043 v6 — decisión del dueño:
    // "letra más grande, que se alcance a leer retirado del teléfono")
    // — el blanco sube a 17px de base y las jerarquías mostaza
    // escalan parejo; la columna angosta aguanta el wrap.
    final line = text.bodyMedium?.copyWith(color: strong, fontSize: 17);
    final sectionTitle = text.titleSmall?.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w800,
      fontSize: 18,
    );
    return Container(
      width: 420,
      decoration: BoxDecoration(
        // Negro puro del scaffold — la card se comparte fuera de la
        // app y el dueño la quiere negra, no el marrón del surface.
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        children: [
          // Marca de agua — isotipo CENTRADO en la card (§043 v4: en
          // la columna angosta la firma lateral aplastaba contra las
          // líneas). Escala al alto real (máx la mitad, tope 260) —
          // en una card corta el tamaño fijo cruzaba divisores.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (_, c) {
                final h = (c.maxHeight * 0.5).clamp(0.0, 260.0);
                return Align(
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: 0.06,
                    child: SizedBox(
                      // Solo el escudo (~74% superior del imagotipo)
                      // — el wordmark DEPREDADOG ya está textual en
                      // el header. La caja 190×148 guarda el clip.
                      width: h * (190 / 148),
                      height: h,
                      child: Image.asset(
                        'assets/images/imagotipo_depredadog_dark.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header de tiquete: wordmark centrado (DEPREDA
                // fuerte + DOG ketchup fijo — es marca, no tema) y
                // bajo él el tag de pedido + índice como metadato.
                Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'DEPREDA', style: brand),
                        TextSpan(
                          text: 'DOG',
                          style: brand?.copyWith(color: AppColors.primaryLight),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      indexText == null ? orderTag : '$orderTag · $indexText',
                      style: meta,
                    ),
                  ),
                ),
                _DashDivider(color: colors.outlineVariant),
                // Voz de título naciente — Anton mostaza pesada. 'x'
                // (no '×'): en Anton la × se leía como '*' en el
                // thumbnail de WhatsApp (revisor-estetico §043).
                Text(
                  '${item.quantity}x ${item.name}',
                  style: text.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                  ),
                ),
                // Secciones del ítem (§043 v5 — "todo por
                // secciones": Se le quitó / Ingredientes /
                // Adicionales / Toppings / Salsas, cada nombre
                // en su línea, no inline).
                for (final s in item.sections)
                  _section(s, sectionTitle, line, colors),
                // Bolsón de aire entre la comanda y el cierre —
                // el render lo mide y lo repinta (v6).
                SizedBox(height: spacerGap),
                _DashDivider(color: colors.outlineVariant),
                for (final (i, l) in footerLines.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                    child: Text(l, style: line),
                  ),
                if (noteLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    // La nota es el dato más accionable para quien
                    // entrega — peso semibold como el total, no el
                    // de una línea más (revisor-estetico §043).
                    child: Text(
                      noteLine!,
                      style: line?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (totalLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    // El total remata el tiquete centrado — como la
                    // línea de cierre de una comanda impresa.
                    child: Center(
                      child: Text(
                        totalLine!,
                        style: line?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sección del ítem — MISMO idioma del desplegable del tile
  /// (§021b): título Anton mostaza w800 + cada nombre con su punto
  /// mostaza y sangría francesa (el wrap de un nombre largo cae
  /// bajo el TEXTO, no bajo el punto).
  Widget _section(
    KitchenSection section,
    TextStyle? titleStyle,
    TextStyle? lineStyle,
    ColorScheme colors,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: titleStyle),
        const SizedBox(height: 4),
        for (final name in section.names)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Alinea el punto con la primera línea del texto.
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: lineStyle)),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Divisor punteado del tiquete (§043 v4): la raya continua leía
/// "card de la app" — los puntos son la línea de corte de una
/// comanda impresa. 30 segmentos Expanded + 5px de aire — sin
/// LayoutBuilder: IntrinsicHeight (v4, altura mínima) no admite
/// builders diferidos en su subárbol.
class _DashDivider extends StatelessWidget {
  const _DashDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        for (var i = 0; i < 30; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 29 ? 0 : 5),
              child: Container(height: 1, color: color),
            ),
          ),
      ],
    ),
  );
}

/// Efectivo/Transf./Nequi — las MISMAS etiquetas legibles del detalle
/// admin, para que la comanda diga lo que el dueño ya lee.
String kitchenPaymentLabel(AdminPaymentMethod method, AppLocalizations l10n) =>
    switch (method) {
      AdminPaymentMethod.cash => l10n.adminPaymentCash,
      AdminPaymentMethod.transfer => l10n.adminPaymentTransfer,
      AdminPaymentMethod.nequi => l10n.adminPaymentNequi,
    };

/// Render offscreen → PNG por ítem (§043 v2): monta cada card en el
/// Overlay del MaterialApp a -2000,-2000 (fuera de vista pero con el
/// Theme real), espera el frame, captura el RepaintBoundary a 2x y
/// escribe `pedido_<tag>_item_<n>.png` en el temp dir. Devuelve los
/// XFile en orden para el share sheet.
Future<List<XFile>> renderKitchenItemCards(
  BuildContext context,
  KitchenOrderData data,
  AppLocalizations l10n,
) async {
  final overlay = Overlay.of(context);
  final dir = await getTemporaryDirectory();
  // Las cards de un compartido anterior quedan huérfanas en el temp
  // dir — el lote nuevo arranca limpio (los temp del SO no se
  // purgan solos entre compartidos de la misma sesión).
  for (final e in dir.listSync()) {
    if (e is File && e.path.contains('pedido_') && e.path.endsWith('.png')) {
      try {
        e.deleteSync();
      } on FileSystemException {
        // noop — el archivo en uso no tumba el render.
      }
    }
  }
  // Solo alfanumérico en el filename ('adm-1' → 'adm1').
  final tag = data.number.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  final note = data.note?.trim() ?? '';
  // Footer: servicio · pago · hora DEL PEDIDO — un reenvío no puede
  // leerse como orden nueva (revisor-ui §043: la hora del envío
  // confundía a cocina). Debajo, el bloque de entrega del domicilio
  // — dirección+referencia y teléfono (el dueño reparte, decisión
  // suya §043 v2).
  final footerLines = [
    '${data.serviceLines.first} · '
        '${kitchenPaymentLabel(data.paymentMethod, l10n)} · '
        '${formatOrderTime(data.placedAt)}',
    ...data.serviceLines.skip(1),
  ];
  final files = <XFile>[];
  for (var i = 0; i < data.items.length; i++) {
    final line = data.items[i];
    final boundaryKey = GlobalKey();
    // Bolsón de aire del tiquete (§043 v6): se pinta en 0, se mide
    // la card natural y si quedó bajo el piso se repinta con el gap
    // que falta — el footer ancla al pie. markNeedsBuild recompone
    // el builder con el nuevo valor (OverlayEntry es reactivo).
    var gap = 0.0;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000,
        top: -2000,
        child: RepaintBoundary(
          key: boundaryKey,
          child: KitchenItemCard(
            // Las secciones llegan ARMADAS desde la factory (v5) —
            // la card solo las pinta (presentación pura).
            item: line,
            orderTag: l10n.shareWaOrderTag(data.number),
            indexText: data.items.length > 1
                ? l10n.shareWaItemIndex(i + 1, data.items.length)
                : null,
            footerLines: footerLines,
            noteLine: note.isEmpty ? null : '${l10n.shareWaNoteLabel} $note',
            totalLine: '${l10n.shareWaTotalLabel} ${formatCop(data.total)}',
            spacerGap: gap,
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      // El entry se construye y pinta en el frame siguiente al
      // insert — endOfFrame puede resolver ANTES de que el contexto
      // monte (carrera con el pipeline); segundo frame de margen y
      // null-check antes de capturar (revisor-ui §043).
      await WidgetsBinding.instance.endOfFrame;
      var renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject == null) {
        await WidgetsBinding.instance.endOfFrame;
        renderObject = boundaryKey.currentContext?.findRenderObject();
      }
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('la card no montó su boundary en dos frames');
      }
      // Piso de tiquete (v4/v6): 420×600 de mínimo — sin él un ítem
      // pelado dejaba la imagen apaisada. Solo un repintado cuando
      // falta aire; el gap va entre las secciones y el cierre.
      const minTicketHeight = 600.0;
      if (renderObject.size.height < minTicketHeight) {
        gap = minTicketHeight - renderObject.size.height;
        entry.markNeedsBuild();
        await WidgetsBinding.instance.endOfFrame;
      }
      final image = await renderObject.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('toByteData devolvió null — PNG vacío');
      }
      final file = File('${dir.path}/pedido_${tag}_item_${i + 1}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      files.add(XFile(file.path));
    } finally {
      entry.remove();
    }
  }
  return files;
}

/// "Enviar a cocina" (§043 v2): render de una card PNG por ítem y
/// share sheet del sistema — WhatsApp abre su pantalla de reenvío
/// (wa.me no transporta media; cocina queda primero en recientes).
/// Un fallo de plataforma tosteea `adminShareWhatsAppFailed` — el
/// chooser siempre resuelve, el único fallo real es la exception.
Future<void> shareKitchenItemCards(
  BuildContext context,
  KitchenOrderData data,
) async {
  final l10n = AppLocalizations.of(context)!;
  // Una orden sin ítems no puede llegar acá (el POST lo exige), pero
  // sin guardia un data roto abriría el chooser con cero archivos.
  if (data.items.isEmpty) {
    AppToast.error(context, l10n.adminShareWhatsAppFailed);
    return;
  }
  try {
    final files = await renderKitchenItemCards(context, data, l10n);
    await SharePlus.instance.share(ShareParams(files: files));
  } catch (_) {
    if (context.mounted) {
      AppToast.error(context, l10n.adminShareWhatsAppFailed);
    }
  }
}
