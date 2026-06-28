import 'package:flutter/material.dart';

class DateTimeFormatter {
  static String shortDateTime(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final localValue = value.toLocal();
    final date = localizations.formatMediumDate(localValue);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localValue),
    );

    return '$date at $time';
  }

  static String shortDate(BuildContext context, DateTime value) {
    return MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
  }

  static String shortTime(BuildContext context, TimeOfDay value) {
    return MaterialLocalizations.of(context).formatTimeOfDay(value);
  }
}
