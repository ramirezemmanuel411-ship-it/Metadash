import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application-wide logger.
///
/// Wraps the `logger` package and is silenced in release builds, so debug
/// diagnostics never reach production output. Prefer this over `print`.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    level: kReleaseMode ? Level.off : Level.debug,
    printer: SimplePrinter(printTime: false, colors: false),
  );

  /// Verbose/debug diagnostics.
  static void d(Object? message) => _logger.d(message);

  /// Informational messages.
  static void i(Object? message) => _logger.i(message);

  /// Warnings that don't stop execution.
  static void w(Object? message) => _logger.w(message);

  /// Errors, optionally with the originating [error] and [stackTrace].
  static void e(Object? message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
