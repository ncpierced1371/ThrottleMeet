import 'dart:convert';

import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void info(String event, {Map<String, Object?> fields = const {}}) {
    _write('info', event, fields: fields);
  }

  static void warning(
    String event, {
    Map<String, Object?> fields = const {},
    Object? error,
  }) {
    _write('warning', event, fields: fields, error: error);
  }

  static void error(
    String event, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _write(
      'error',
      event,
      fields: fields,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _write(
    String level,
    String event, {
    required Map<String, Object?> fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final record = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'event': event,
      for (final entry in fields.entries) entry.key: _safeValue(entry.value),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack_trace': stackTrace.toString(),
    };
    debugPrint(jsonEncode(record));
  }

  static Object? _safeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    return value.toString();
  }
}
