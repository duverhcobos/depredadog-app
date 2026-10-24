import 'package:flutter/foundation.dart';
import '../interfaces/i_logger_service.dart';

/// Logger de desarrollo: imprime con debugPrint (no-op en release).
class DebugLoggerServiceImpl implements ILoggerService {
  const DebugLoggerServiceImpl();

  @override
  void debug(String message, {String? tag}) {
    debugPrint('[${_tag(tag)} DEBUG] $message');
  }

  @override
  void info(String message, {String? tag}) {
    debugPrint('[${_tag(tag)} INFO] $message');
  }

  @override
  void warning(String message, {String? tag}) {
    debugPrint('[${_tag(tag)} WARN] $message');
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    debugPrint('[${_tag(tag)} ERROR] $message');
    if (error != null) debugPrint('  → $error');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  static String _tag(String? tag) => tag ?? 'Depredadog';
}
