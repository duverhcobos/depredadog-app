import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'shell_header.dart';

/// Marco persistente del área autenticada (§016): header de marca +
/// contenido del branch activo + NavigationBar de 3 secciones.
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
      // fuera de Inicio vuelve al tab Inicio; en Inicio sale de la app.
      canPop: shell.currentIndex == 0,
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            // Tocar el tab ya activo vuelve a la raíz de esa sección
            // (convención estándar de apps con tabs).
            initialLocation: index == shell.currentIndex,
          ),
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
          ],
        ),
      ),
    );
  }
}
