import 'package:flutter/material.dart';
import '../di/setup_di.dart';

/// Orquesta el arranque: bindings → DI → runApp. Punto único para agregar
/// inicializaciones futuras (Crashlytics, orientación, splash nativo).
class AppBootstrap {
  AppBootstrap._();

  static void run(Widget app) {
    WidgetsFlutterBinding.ensureInitialized();
    setupDI();
    runApp(app);
  }
}
