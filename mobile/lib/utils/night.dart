import 'package:intl/intl.dart';

/// Une « nuit » va de 14h à 14h le lendemain : un réveil à 3h du matin le mardi
/// appartient à la nuit du lundi au mardi.
const nightPivotHour = 14;

/// Clé de nuit = date (AAAA-MM-JJ, heure locale) du soir
String nightKey(DateTime date) {
  final d = date.toLocal();
  return toDateKey(DateTime(d.year, d.month, d.day, d.hour - nightPivotHour, d.minute));
}

String toDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime fromDateKey(String key) {
  final [y, m, d] = key.split('-').map(int.parse).toList();
  return DateTime(y, m, d);
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

final _fmtShort = DateFormat('EEE d MMM', 'fr_FR');
final _fmtTime = DateFormat('HH:mm', 'fr_FR');
final _fmtDateTime = DateFormat('EEE d MMM, HH:mm', 'fr_FR');

String nightLabel(String key) {
  final start = fromDateKey(key);
  return 'Nuit du ${_fmtShort.format(start)} au ${_fmtShort.format(addDays(start, 1))}';
}

String formatTime(DateTime date) => _fmtTime.format(date.toLocal());

String formatDateTime(DateTime date) => _fmtDateTime.format(date.toLocal());

/// Lundi (clé AAAA-MM-JJ) de la semaine contenant la date
String weekKey(String key) {
  final d = fromDateKey(key);
  return toDateKey(addDays(d, -(d.weekday - 1)));
}

String monthKey(String key) => key.substring(0, 7);
