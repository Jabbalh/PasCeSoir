import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pas_ce_soir/data/models.dart';
import 'package:pas_ce_soir/services/stats_pdf.dart';
import 'package:pas_ce_soir/utils/stats.dart';
import 'package:pas_ce_soir/widgets/column_chart.dart';

final _now = DateTime(2026, 10, 28, 12);
var _n = 0;

String _iso(DateTime local) => local.toUtc().toIso8601String();

Wakeup _wakeup(DateTime at, {String? type, List<String> reasons = const []}) => Wakeup({
      'id': 'w${_n++}',
      'journal_id': 'j',
      'woke_at': _iso(at),
      'wake_type': type,
      'reason_ids': reasons,
      'created_at': _iso(at),
    });

final _journal = Journal({
  'id': 'j',
  'name': 'Journal de Léo',
  'child_name': 'Léo',
  'created_by': 'u',
  'created_at': _iso(DateTime(2026, 10, 1, 12)),
});

Approach _approach(String start, {String? end}) => Approach({
      'id': 'a$start',
      'journal_id': 'j',
      'kind': 'rituel',
      'label': 'Histoire du soir',
      'start_date': start,
      'end_date': end,
      'created_at': _iso(DateTime(2026, 10, 1)),
    });

/// Réveils du plus récent au plus ancien, comme `watchWakeups`
JournalStats _stats(List<Wakeup> wakeups,
        {List<Approach> approaches = const [], required String from, required String to, Granularity g = Granularity.week}) =>
    JournalStats(
      wakeups: wakeups..sort((a, b) => b.wokeAt.compareTo(a.wokeAt)),
      approaches: approaches,
      journal: _journal,
      labelOf: (id) => {'r1': 'Cauchemar', 'r2': 'Soif'}[id] ?? '?',
      from: from,
      to: to,
      granularity: g,
      now: _now,
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('période : réveils rattachés à leur nuit, bornes remises dans l’ordre', () {
    final s = _stats([
      _wakeup(DateTime(2026, 10, 20, 3), type: 'nocturne'), // nuit du 19
      _wakeup(DateTime(2026, 10, 20, 22)), // nuit du 20
      _wakeup(DateTime(2026, 10, 21, 7), type: 'lever'), // nuit du 20
      _wakeup(DateTime(2026, 10, 27, 2), type: 'nocturne'), // nuit du 26 : hors période
    ], from: '2026-10-25', to: '2026-10-19');

    expect((s.from, s.to), ('2026-10-19', '2026-10-25'));
    expect(s.inRange.length, 3);
    expect(s.nightsCount, 7);
    expect(s.nightsWithWakeup, 2);
    expect([for (final t in s.byType) (t.count, t.pct)], [(1, 33), (1, 33), (1, 33)]);
  });

  test('séries par semaine avec les semaines vides, empilées par type', () {
    final s = _stats([
      _wakeup(DateTime(2026, 10, 20, 3), type: 'nocturne'),
      _wakeup(DateTime(2026, 10, 20, 22)),
      _wakeup(DateTime(2026, 10, 21, 7), type: 'lever'),
    ], from: '2026-10-14', to: '2026-10-27');

    expect(s.series.map((i) => i.key), ['2026-10-12', '2026-10-19', '2026-10-26']);
    expect(s.series.map((i) => i.value), [0, 3, 0]);
    expect(s.series[1].counts, [1, 1, 1]);
    expect(s.series[1].tooltip, 'Semaine du 19 oct. au 25 oct. : 3 réveils (Lever 1, Réveil nocturne 1, Non renseigné 1)');
  });

  test('séries par mois', () {
    final s = _stats([_wakeup(DateTime(2026, 9, 3, 2))], from: '2026-08-15', to: '2026-10-02', g: Granularity.month);
    expect(s.series.map((i) => i.key), ['2026-08', '2026-09', '2026-10']);
    expect(s.series.map((i) => i.value), [0, 1, 0]);
  });

  test('effet d’une démarche : 30 nuits avant (bornées par la création du journal), nuit en cours exclue', () {
    final wakeups = [
      // 10 réveils nocturnes du 10 au 19 octobre, avant la démarche
      for (var d = 10; d <= 19; d++) _wakeup(DateTime(2026, 10, d + 1, 2), type: 'nocturne'),
      _wakeup(DateTime(2026, 10, 10, 7), type: 'lever'), // levers exclus
      _wakeup(DateTime(2026, 10, 21, 2), type: 'nocturne'), // nuit du 20, pendant
      _wakeup(DateTime(2026, 10, 28, 3), type: 'nocturne'), // nuit en cours (27) : exclue
    ];
    final s = _stats(wakeups, approaches: [_approach('2026-10-20')], from: '2026-10-14', to: '2026-10-27');
    final e = s.approachEffects.single;

    // avant : du 30 sept. (création du journal, nuit du 30) au 19 oct. = 20 nuits, 10 réveils
    expect(e.before!.nights, 20);
    expect(e.before!.avg, 0.5);
    // pendant : du 20 au 26 oct. = 7 nuits, 1 réveil
    expect(e.during!.nights, 7);
    expect(e.delta, -71);

    final band = s.approachBands.single;
    expect((band.from, band.to), (1, 2));
  });

  test('démarche qui commence aujourd’hui : pas encore de nuit complète', () {
    final s = _stats([], approaches: [_approach('2026-10-28')], from: '2026-10-01', to: '2026-10-28');
    expect(s.approachEffects.single.during, isNull);
    expect(s.approachEffects.single.delta, isNull);
  });

  test('top des raisons et répartition horaire', () {
    final s = _stats([
      _wakeup(DateTime(2026, 10, 20, 3), reasons: ['r1', 'r2']),
      _wakeup(DateTime(2026, 10, 21, 3, 30), reasons: ['r1']),
      _wakeup(DateTime(2026, 10, 21, 22)),
    ], from: '2026-10-01', to: '2026-10-27');

    final r = s.topReasons;
    expect([for (final x in r.top) (x.label, x.value, x.pct)], [('Cauchemar', 2, 67), ('Soif', 1, 33)]);
    expect(r.withoutReason, 1);
    expect(r.max, 2);
    expect({for (final h in s.byHour) if (h.value > 0) h.label: h.value}, {'22h': 1, '3h': 2});
  });

  test('graduations de l’axe Y', () {
    ChartItem item(int v) => ChartItem(key: '$v', label: '', value: v, tooltip: '');
    final one = chartTicks([item(0)]);
    expect(one.top, 1);
    expect(one.values, [1, 0]);
    final seven = chartTicks([item(7)]);
    expect(seven.top, 8);
    expect(seven.values, [8, 6, 4, 2, 0]);
  });

  test('le PDF se génère (police embarquée, accents)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final wakeups = [
      for (var d = 1; d <= 27; d++)
        _wakeup(DateTime(2026, 10, d + 1, 2), type: d.isEven ? 'nocturne' : 'lever', reasons: ['r1']),
    ];
    final s = _stats(wakeups,
        approaches: [_approach('2026-10-05', end: '2026-10-12'), _approach('2026-10-20')],
        from: '2025-10-28',
        to: '2026-10-27');
    final bytes = await buildStatsPdf(s, withTable: true);
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  testWidgets('histogramme large avec peu de barres (tablette, vue mensuelle)', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = _stats([_wakeup(DateTime(2026, 9, 3, 2))],
        approaches: [_approach('2026-09-01')], from: '2026-08-15', to: '2026-10-02', g: Granularity.month);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: [ColumnChart(items: s.series, bands: s.approachBands)])),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('sept. 26'), findsOneWidget);
  });

  test('PDF en vue mensuelle avec peu de mois', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final s = _stats([_wakeup(DateTime(2026, 9, 3, 2))], from: '2026-08-15', to: '2026-10-02', g: Granularity.month);
    final bytes = await buildStatsPdf(s, withTable: true);
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });
}
