import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/cubit/admin_queue_cubit.dart';
import '../../features/orders/presentation/cubit/orders_cubit.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_session.dart';
import '../di/setup_di.dart';
import 'shell_header.dart';

/// Marco persistente del área autenticada (§016): header de marca +
/// contenido del branch activo + NavigationBar de 3 secciones — 4
/// para el dueño (§034: "Cocina" a un clic, branches estáticas y
/// destino condicional por rol).
/// navigation-routing: entre secciones se navega con goBranch (nunca
/// push — push no mueve currentIndex y el tab quedaría desmarcado).
class AppShellLayout extends StatelessWidget {
  const AppShellLayout({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      // Back nativo = convención de apps con tabs (decisión del usuario):
      // con una hija apilada sobre el branch (El local, carrito…)
      // el back hace POP de esa hija primero — el salto al tab
      // Inicio solo aplica en la raíz del tab. Sin context.canPop()
      // el scope se tragaba el pop y /profile/store no podía
      // regresar (bug reportado por el usuario, §031b).
      canPop: shell.currentIndex == 0 || context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: Column(
          children: [
            const ShellHeader(),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: shell),
          ],
        ),
        // La barra escucha la sesión (§034): login/logout de un admin
        // dibuja/quita el 4º destino EN VIVO — sin rebuild del router.
        bottomNavigationBar: ListenableBuilder(
          listenable: locator<AuthSession>(),
          builder: (context, _) {
            final isAdmin = locator<AuthSession>().currentUser?.role == 'admin';
            // Logout estando en Cocina (o cualquier no-admin en el
            // branch 3): el índice queda fuera de rango — se devuelve
            // a Inicio DESPUÉS del build (mutar navegación durante el
            // build tira excepción).
            if (!isAdmin && shell.currentIndex > 2) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                shell.goBranch(0);
              });
            }
            return NavigationBar(
              // Clamp defensivo del frame de transición: con 3
              // destinos un selectedIndex=3 crashea antes del
              // postFrameCallback.
              selectedIndex: !isAdmin && shell.currentIndex > 2
                  ? 0
                  : shell.currentIndex,
              onDestinationSelected: (index) {
                // Pedidos recarga en CADA visita al tab (§027 — el
                // cliente entra a ver si su pedido avanzó): el
                // IndexedStack no re-ejecuta pageBuilder al conmutar de
                // branch, así que el refresh vive acá — corrección del
                // revisor (la decisión no estaba implementada).
                if (index == 1 && locator.isRegistered<OrdersCubit>()) {
                  locator<OrdersCubit>().loadOrders();
                }
                // Cocina recarga en CADA visita al tab (§034 —
                // paridad con Pedidos: la cola es la pantalla de
                // trabajo del dueño, no puede quedar congelada al
                // saltar de tab y volver).
                if (index == 3 && locator.isRegistered<AdminQueueCubit>()) {
                  locator<AdminQueueCubit>().load();
                }
                shell.goBranch(
                  index,
                  // Tocar el tab ya activo vuelve a la raíz de esa sección
                  // (convención estándar de apps con tabs).
                  initialLocation: index == shell.currentIndex,
                );
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: l10n.shellTabHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long_rounded),
                  label: l10n.shellTabOrders,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: l10n.shellTabProfile,
                ),
                if (isAdmin)
                  NavigationDestination(
                    // "Cocina" = la cola del local vista como mesa de
                    // trabajo del dueño (soup_kitchen — glifo de la
                    // sección, espejado en el empty state).
                    icon: const Icon(Icons.soup_kitchen_outlined),
                    selectedIcon: const Icon(Icons.soup_kitchen_rounded),
                    label: l10n.shellTabAdmin,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
