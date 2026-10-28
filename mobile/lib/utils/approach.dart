import 'package:intl/intl.dart';

import '../data/models.dart';
import 'night.dart';

enum ApproachStatus { aVenir, enCours, terminee }

/// État d'une démarche à une date (AAAA-MM-JJ) : la date de fin est incluse
ApproachStatus approachStatus(Approach a, String today) {
  if (a.startDate.compareTo(today) > 0) return ApproachStatus.aVenir;
  final end = a.endDate;
  if (end != null && end.compareTo(today) < 0) return ApproachStatus.terminee;
  return ApproachStatus.enCours;
}

/// La démarche est-elle en place ce jour-là (ou la nuit commençant ce soir-là) ?
bool isApproachActiveOn(Approach a, String day) {
  final end = a.endDate;
  return a.startDate.compareTo(day) <= 0 && (end == null || end.compareTo(day) >= 0);
}

final _fmtDate = DateFormat('d MMM y', 'fr_FR');

String formatDay(String key) => _fmtDate.format(fromDateKey(key));

/// « Depuis le 3 oct. 2026 », « Du 3 oct. 2026 au 12 oct. 2026 », « À partir du 20 oct. 2026 »
String approachDates(Approach a, String today) {
  final end = a.endDate;
  if (end != null) {
    return end == a.startDate ? 'Le ${formatDay(a.startDate)}' : 'Du ${formatDay(a.startDate)} au ${formatDay(end)}';
  }
  return a.startDate.compareTo(today) > 0 ? 'À partir du ${formatDay(a.startDate)}' : 'Depuis le ${formatDay(a.startDate)}';
}

/// Nombre de jours (bornes incluses)
int daysBetween(String from, String to) => (fromDateKey(to).difference(fromDateKey(from)).inHours / 24).round() + 1;

String periodsLabel(List<ApproachPeriod> periods) =>
    ApproachPeriod.values.where(periods.contains).map((p) => p.label).join(', ');
