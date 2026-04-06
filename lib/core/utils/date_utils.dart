import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _displayFormat = DateFormat('MMM d, yyyy');

  static String toIso(DateTime date) => _dateFormat.format(date);

  static String toDisplay(DateTime date) => _displayFormat.format(date);

  static int daysUntil(DateTime date) =>
      date.difference(DateTime.now()).inDays;

  static bool isExpiringSoon(DateTime date, {int withinDays = 30}) =>
      daysUntil(date) <= withinDays && daysUntil(date) >= 0;

  static bool isExpired(DateTime date) => date.isBefore(DateTime.now());
}
