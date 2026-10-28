import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../theme.dart';
import 'approach.dart';
import 'night.dart';

enum Granularity { week, month }

/// Type de réveil (null = non renseigné) et sa couleur, dans le graphique empilé et la répartition
class TypeSegment {
  const TypeSegment(this.type, this.label, this.icon, this.color);

  final WakeType? type;
  final String label;
  final IconData icon;
  final Color color;
}

final typeSegments = [
  for (final (i, t) in WakeType.values.indexed)
    TypeSegment(t, t.label, t.icon, i == 0 ? AppColors.warning : AppColors.primary),
  const TypeSegment(null, 'Non renseigné', Icons.help_outline, AppColors.accented),
];

/// Barre d'histogramme ; `counts` (un nombre par élément de [typeSegments]) pour une barre empilée
class ChartItem {
  const ChartItem({required this.key, required this.label, required this.value, required this.tooltip, this.counts});

  final String key;
  final String label;
  final int value;
  final String tooltip;
  final List<int>? counts;
}

/// Bande de la frise sous l'histogramme, de la barre `from` à la barre `to` (incluses)
class ChartBand {
  const ChartBand({
    required this.key,
    required this.label,
    required this.from,
    required this.to,
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  final String key;
  final String label;
  final int from;
  final int to;
  final Color color;
  final IconData icon;
  final String tooltip;
}

class NightStat {
  const NightStat(this.nights, this.avg);

  final int nights;

  /// Réveils nocturnes par nuit
  final double avg;
}

class ApproachEffect {
  const ApproachEffect(this.approach, this.before, this.during, this.delta);

  final Approach approach;
  final NightStat? before;
  final NightStat? during;

  /// Évolution en % (arrondie), null si pas de comparaison possible
  final int? delta;
}

class ReasonCount {
  const ReasonCount(this.id, this.label, this.value, this.pct);

  final String id;
  final String label;
  final int value;
  final int pct;
}

class TypeCount {
  const TypeCount(this.segment, this.count, this.pct);

  final TypeSegment segment;
  final int count;
  final int pct;
}

/// Nombre de nuits « avant » auxquelles est comparée une démarche
const beforeNights = 30;

/// Arrondi comme Math.round en JS (demi vers +∞), pour des pourcentages identiques à la PWA
int _round(double x) => (x + 0.5).floor();

final _fmtDay = DateFormat('d MMM', 'fr_FR');
final _fmtMonth = DateFormat('MMM yy', 'fr_FR');
final _fmtMonthLong = DateFormat('MMMM y', 'fr_FR');
final _fmtAvg = NumberFormat('0.#', 'fr_FR');

/// « 1,5 »
String formatAvg(num n) => _fmtAvg.format(n);

String _plural(int n, String word) => '$n $word${n > 1 ? 's' : ''}';

/// Statistiques d'un journal sur une période de nuits (port de pages/journal/[id]/stats.vue)
class JournalStats {
  JournalStats({
    required List<Wakeup> wakeups,
    required List<Approach> approaches,
    required this.journal,
    required String Function(String id) labelOf,
    required String from,
    required String to,
    required this.granularity,
    DateTime? now,
  })  : _wakeups = wakeups,
        _approaches = approaches,
        _labelOf = labelOf,
        now = now ?? DateTime.now(),
        from = from.compareTo(to) <= 0 ? from : to,
        to = from.compareTo(to) <= 0 ? to : from;

  /// Réveils du plus récent au plus ancien (ordre de `watchWakeups`)
  final List<Wakeup> _wakeups;
  final List<Approach> _approaches;
  final String Function(String id) _labelOf;
  final Journal? journal;
  final Granularity granularity;
  final DateTime now;

  /// Bornes de la période (nuits, incluses), remises dans l'ordre
  final String from;
  final String to;

  late final String today = toDateKey(now);

  /// Réveils de la période, rattachés à leur nuit (une nuit = soir J -> matin J+1)
  late final List<({Wakeup w, String night})> inRange = [
    for (final w in _wakeups)
      if (nightKey(w.wokeAt) case final night when night.compareTo(from) >= 0 && night.compareTo(to) <= 0)
        (w: w, night: night),
  ];

  late final int nightsCount = daysBetween(from, to);
  late final int nightsWithWakeup = inRange.map((x) => x.night).toSet().length;
  late final double avgPerNight = nightsCount > 0 ? inRange.length / nightsCount : 0;

  String Function(String) get _keyOf => granularity == Granularity.week ? weekKey : monthKey;

  /// Séries par semaine / mois, empilées par type, avec les périodes vides (0)
  late final List<ChartItem> series = () {
    final counts = <String, List<int>>{};
    for (final x in inRange) {
      final c = counts.putIfAbsent(_keyOf(x.night), () => List.filled(typeSegments.length, 0));
      c[typeSegments.indexWhere((s) => s.type == x.w.wakeType)]++;
    }
    ChartItem item(String key, String label, String title) {
      final c = counts[key] ?? List.filled(typeSegments.length, 0);
      final value = c.fold(0, (s, n) => s + n);
      final detail = [
        for (final (i, s) in typeSegments.indexed)
          if (c[i] > 0) '${s.label} ${c[i]}',
      ].join(', ');
      return ChartItem(
        key: key,
        label: label,
        value: value,
        counts: c,
        tooltip: '$title : ${_plural(value, 'réveil')}${detail.isNotEmpty ? ' ($detail)' : ''}',
      );
    }

    final items = <ChartItem>[];
    if (granularity == Granularity.week) {
      for (var d = fromDateKey(weekKey(from)); toDateKey(d).compareTo(to) <= 0; d = addDays(d, 7)) {
        items.add(item(toDateKey(d), _fmtDay.format(d), 'Semaine du ${_fmtDay.format(d)} au ${_fmtDay.format(addDays(d, 6))}'));
      }
    } else {
      final start = fromDateKey(from);
      for (var d = DateTime(start.year, start.month);
          monthKey(toDateKey(d)).compareTo(monthKey(to)) <= 0;
          d = DateTime(d.year, d.month + 1)) {
        items.add(item(monthKey(toDateKey(d)), _fmtMonth.format(d), _fmtMonthLong.format(d)));
      }
    }
    return items;
  }();

  /// Démarches en place sur la période, de la plus ancienne à la plus récente
  late final List<Approach> approachesInRange = _approaches
      .where((x) => x.startDate.compareTo(to) <= 0 && (x.endDate == null || x.endDate!.compareTo(from) >= 0))
      .toList()
    ..sort((x, y) => x.startDate.compareTo(y.startDate));

  /// Frise des démarches sous l'histogramme, alignée sur les semaines / mois
  late final List<ChartBand> approachBands = () {
    final index = {for (final (i, s) in series.indexed) s.key: i};
    return [
      for (final x in approachesInRange)
        if ((
          index[_keyOf(x.startDate.compareTo(from) > 0 ? x.startDate : from)],
          index[_keyOf(x.endDate != null && x.endDate!.compareTo(to) < 0 ? x.endDate! : to)],
        )
            case (final int a, final int b))
          ChartBand(
            key: x.id,
            label: x.label,
            from: a,
            to: b,
            color: x.kind.color,
            icon: x.kind.icon,
            tooltip: '${x.kind.label} · ${x.label} : ${approachDates(x, today).toLowerCase()}',
          ),
    ];
  }();

  /// Effet de chaque démarche : réveils nocturnes (hors levers) par nuit pendant la démarche,
  /// comparés aux [beforeNights] nuits qui précèdent son début. La nuit en cours, incomplète, est exclue.
  late final List<ApproachEffect> approachEffects = () {
    final lastNight = toDateKey(addDays(fromDateKey(nightKey(now)), -1));
    final perNight = <String, int>{};
    for (final w in _wakeups) {
      if (w.wakeType == WakeType.lever) continue;
      final k = nightKey(w.wokeAt);
      perNight[k] = (perNight[k] ?? 0) + 1;
    }
    // pas de données avant la création du journal ni avant le premier réveil saisi
    final starts = [
      if (journal != null) nightKey(journal!.createdAt),
      if (_wakeups.isNotEmpty) nightKey(_wakeups.last.wokeAt),
    ]..sort();
    final dataStart = starts.firstOrNull ?? today;

    NightStat? stat(String from, String to) {
      if (to.compareTo(from) < 0) return null;
      var total = 0;
      for (var d = fromDateKey(from); toDateKey(d).compareTo(to) <= 0; d = addDays(d, 1)) {
        total += perNight[toDateKey(d)] ?? 0;
      }
      final nights = daysBetween(from, to);
      return NightStat(nights, total / nights);
    }

    return [
      for (final x in approachesInRange)
        () {
          final start = fromDateKey(x.startDate);
          final beforeTo = toDateKey(addDays(start, -1));
          final beforeFrom = toDateKey(addDays(start, -beforeNights));
          final before = stat(beforeFrom.compareTo(dataStart) > 0 ? beforeFrom : dataStart, beforeTo);
          final end = x.endDate;
          final during = stat(x.startDate, end != null && end.compareTo(lastNight) < 0 ? end : lastNight);
          final delta = before != null && during != null && before.avg != 0
              ? _round((during.avg - before.avg) / before.avg * 100)
              : null;
          return ApproachEffect(x, before, during, delta);
        }(),
    ];
  }();

  /// Top 10 des raisons (un réveil peut avoir plusieurs raisons) et nombre de réveils sans raison
  late final ({List<ReasonCount> top, int withoutReason, int max}) topReasons = () {
    final counts = <String, int>{};
    var withoutReason = 0;
    for (final x in inRange) {
      if (x.w.reasonIds.isEmpty) withoutReason++;
      for (final r in x.w.reasonIds) {
        counts[r] = (counts[r] ?? 0) + 1;
      }
    }
    final total = inRange.isEmpty ? 1 : inRange.length;
    final top = [
      for (final MapEntry(key: id, :value) in counts.entries)
        ReasonCount(id, _labelOf(id), value, _round(value / total * 100)),
    ]
      ..sort((x, y) => x.value != y.value ? y.value - x.value : x.label.toLowerCase().compareTo(y.label.toLowerCase()));
    final top10 = top.take(10).toList();
    return (
      top: top10,
      withoutReason: withoutReason,
      max: top10.fold(1, (m, r) => r.value > m ? r.value : m),
    );
  }();

  /// Répartition lever / réveil nocturne (pourcentages sur l'ensemble des réveils de la période)
  late final List<TypeCount> byType = [
    for (final s in typeSegments)
      () {
        final count = inRange.where((x) => x.w.wakeType == s.type).length;
        return TypeCount(s, count, inRange.isEmpty ? 0 : _round(count / inRange.length * 100));
      }(),
  ];

  /// Répartition par heure de la nuit (18h -> 12h)
  late final List<ChartItem> byHour = () {
    const hours = [18, 19, 20, 21, 22, 23, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    final counts = <int, int>{};
    for (final x in inRange) {
      final h = x.w.wokeAt.toLocal().hour;
      counts[h] = (counts[h] ?? 0) + 1;
    }
    return [
      for (final h in hours)
        ChartItem(
          key: '$h',
          label: '${h}h',
          value: counts[h] ?? 0,
          tooltip: 'Entre ${h}h et ${(h + 1) % 24}h : ${_plural(counts[h] ?? 0, 'réveil')}',
        ),
    ];
  }();
}

/// Graduations de l'axe Y : environ 4 intervalles entiers, du haut vers le bas
({int top, List<int> values}) chartTicks(List<ChartItem> items) {
  final m = items.fold(1, (m, i) => i.value > m ? i.value : m);
  final step = (m / 4).ceil().clamp(1, m);
  final top = (m / step).ceil() * step;
  return (top: top, values: [for (var v = top; v >= 0; v -= step) v]);
}
