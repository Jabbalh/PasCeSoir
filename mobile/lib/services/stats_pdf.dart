import 'dart:math';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../theme.dart';
import '../utils/approach.dart';
import '../utils/stats.dart';

// Thème clair du rapport (la PWA imprime aussi en clair)
final _text = PdfColor.fromInt(0xFF0F172A); // slate-900
final _muted = PdfColor.fromInt(0xFF64748B); // slate-500
final _border = PdfColor.fromInt(0xFFE2E8F0); // slate-200
final _elevated = PdfColor.fromInt(0xFFF1F5F9); // slate-100
final _success = PdfColor.fromInt(0xFF16A34A); // green-600
final _error = PdfColor.fromInt(0xFFDC2626); // red-600

PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());

/// Couleur d'un type de réveil ; « non renseigné » plus clair que dans l'application (fond blanc)
PdfColor _segmentColor(TypeSegment s) => s.type == null ? PdfColor.fromInt(0xFFCBD5E1) : _pdf(s.color);

/// Génère le rapport et ouvre le partage Android (enregistrer dans Fichiers, envoyer par mail…)
Future<void> shareStatsPdf(JournalStats s, {required bool withTable}) async {
  final bytes = await buildStatsPdf(s, withTable: withTable);
  final journal = s.journal;
  final who = journal == null ? 'statistiques' : (journal.childName.isNotEmpty ? journal.childName : journal.name);
  // caractères interdits dans un nom de fichier
  final name = '$who - ${s.from} au ${s.to}.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
    fileNameOverrides: [name],
    subject: 'Pas ce soir - statistiques',
  ));
}

/// Rapport A4 : mêmes blocs que l'écran, chaque bloc gardé sur une seule page
Future<Uint8List> buildStatsPdf(JournalStats s, {required bool withTable}) async {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/Nunito-400.ttf')),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Nunito-700.ttf')),
  ).copyWith(defaultTextStyle: pw.TextStyle(fontSize: 10, color: _text));
  final journal = s.journal;
  final week = s.granularity == Granularity.week;

  final doc = pw.Document(title: 'Statistiques ${journal?.name ?? ''}', creator: 'Pas ce soir');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    theme: theme,
    footer: (context) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(fontSize: 8, color: _muted)),
    ),
    build: (context) => [
      pw.Text(
        [journal?.name, if (journal != null && journal.childName.isNotEmpty) journal.childName].nonNulls.join(' · '),
        style: pw.TextStyle(color: _muted),
      ),
      pw.Text('Statistiques', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text('Nuits du ${formatDay(s.from)} au ${formatDay(s.to)} · généré le ${formatDay(s.today)}'),
      pw.SizedBox(height: 14),
      _keyFigures(s),
      _byType(s),
      _section(
        'Réveils par ${week ? 'semaine' : 'mois'}',
        [
          _chart(s.series, s.approachBands),
          pw.SizedBox(height: 8),
          pw.Wrap(spacing: 14, runSpacing: 3, children: [
            for (final t in typeSegments) _legend(_segmentColor(t), t.label),
          ]),
        ],
      ),
      if (withTable) ..._table(s, week),
      ..._effects(s),
      _reasons(s),
      _section('À quelle heure ?', [_chart(s.byHour, const [])]),
    ],
  ));
  return doc.save();
}

pw.Widget _section(String title, List<pw.Widget> children) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );

pw.Widget _note(String text) => pw.Text(text, style: pw.TextStyle(fontSize: 8, color: _muted));

pw.Widget _dot(PdfColor color) =>
    pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle));

pw.Widget _legend(PdfColor color, String label) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      _dot(color),
      pw.SizedBox(width: 4),
      pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _muted)),
    ]);

pw.Widget _countPct(int count, int pct) => pw.RichText(
      text: pw.TextSpan(style: pw.TextStyle(color: _muted), children: [
        pw.TextSpan(text: '$count', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _text)),
        pw.TextSpan(text: ' · $pct %'),
      ]),
    );

pw.Widget _keyFigures(JournalStats s) {
  pw.Widget tile(String value, String label) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text(label, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, color: _muted)),
          ]),
        ),
      );
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Row(children: [
      tile('${s.inRange.length}', 'réveils'),
      pw.SizedBox(width: 8),
      tile(formatAvg(s.avgPerNight), 'par nuit'),
      pw.SizedBox(width: 8),
      tile('${s.nightsCount - s.nightsWithWakeup}', 'nuit(s) sans réveil sur ${s.nightsCount}'),
    ]),
  );
}

pw.Widget _byType(JournalStats s) {
  if (s.inRange.isEmpty) {
    return _section('Lever ou réveil nocturne', [_note('Aucun réveil sur cette période.')]);
  }
  return _section('Lever ou réveil nocturne', [
    pw.ClipRRect(
      horizontalRadius: 4,
      verticalRadius: 4,
      child: pw.SizedBox(
        height: 8,
        child: pw.Row(children: [
          for (final t in s.byType)
            if (t.count > 0) pw.Expanded(flex: t.count, child: pw.Container(color: _segmentColor(t.segment))),
        ]),
      ),
    ),
    pw.SizedBox(height: 8),
    for (final t in s.byType)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          _dot(_segmentColor(t.segment)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Text(t.segment.label)),
          _countPct(t.count, t.pct),
        ]),
      ),
  ]);
}

/// Histogramme : barres (empilées si `counts`), axe Y gradué, étiquettes, frise des démarches
pw.Widget _chart(List<ChartItem> items, List<ChartBand> bands) {
  const height = 120.0;
  final ticks = chartTicks(items);
  final labelEvery = max(1, (items.length / 12).ceil());
  final axis = pw.TextStyle(fontSize: 7, color: _muted);
  double y(int v) => (1 - v / ticks.top) * height;

  pw.Widget bar(ChartItem item) {
    final h = item.value / ticks.top * height;
    final counts = item.counts;
    return pw.Expanded(
      child: pw.Container(
        alignment: pw.Alignment.bottomCenter,
        child: item.value == 0
            ? null
            : pw.Container(
                width: 10,
                height: h,
                child: pw.Column(
                  verticalDirection: pw.VerticalDirection.up,
                  children: counts == null
                      ? [pw.Container(height: h, color: _pdf(AppColors.primary))]
                      : [
                          for (final (i, n) in counts.indexed)
                            if (n > 0) pw.Container(height: h * n / item.value, color: _segmentColor(typeSegments[i])),
                        ],
                ),
              ),
      ),
    );
  }

  pw.Widget band(ChartBand b) {
    final after = items.length - b.to - 1;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.SizedBox(
        height: 12,
        child: pw.Row(children: [
          if (b.from > 0) pw.Spacer(flex: b.from),
          pw.Expanded(
            flex: b.to - b.from + 1,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
              alignment: pw.Alignment.centerLeft,
              decoration: pw.BoxDecoration(color: _pdf(b.color), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(b.label, maxLines: 1, style: pw.TextStyle(fontSize: 7, color: PdfColors.white)),
            ),
          ),
          if (after > 0) pw.Spacer(flex: after),
        ]),
      ),
    );
  }

  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.SizedBox(
      width: 18,
      height: height,
      child: pw.Stack(overflow: pw.Overflow.visible, children: [
        for (final t in ticks.values)
          pw.Positioned(right: 0, top: y(t) - 4, child: pw.Text('$t', style: axis)),
      ]),
    ),
    pw.SizedBox(width: 6),
    pw.Expanded(
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.SizedBox(
          height: height,
          child: pw.Stack(children: [
            for (final t in ticks.values)
              pw.Positioned(left: 0, right: 0, top: y(t), child: pw.Container(height: 0.5, color: _border)),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [for (final i in items) bar(i)]),
          ]),
        ),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          for (final (i, item) in items.indexed)
            pw.Expanded(
              child: pw.SizedBox(
                height: 9,
                child: i % labelEvery == 0
                    ? pw.OverflowBox(minWidth: 0, maxWidth: 60, child: pw.Text(item.label, style: axis, maxLines: 1))
                    : null,
              ),
            ),
        ]),
        for (final b in bands) band(b),
      ]),
    ),
  ]);
}

/// Tableau sur plusieurs pages si besoin (direct dans la page, pas dans un cadre)
List<pw.Widget> _table(JournalStats s, bool week) => [
      pw.Text('Réveils par ${week ? 'semaine' : 'mois'} : tableau',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: [week ? 'Semaine du' : 'Mois', for (final t in typeSegments) t.label, 'Total'],
        data: [
          for (final item in s.series.reversed) [item.label, for (final n in item.counts!) '$n', '${item.value}'],
        ],
        border: null,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border))),
        rowDecoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.5))),
        cellAlignment: pw.Alignment.centerRight,
        cellAlignments: {0: pw.Alignment.centerLeft},
        headerAlignment: pw.Alignment.centerRight,
        headerAlignments: {0: pw.Alignment.centerLeft},
        cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      ),
      pw.SizedBox(height: 12),
    ];

/// Une démarche par bloc : la liste peut s'étendre sur plusieurs pages
List<pw.Widget> _effects(JournalStats s) {
  final effects = s.approachEffects;
  if (effects.isEmpty) return [_section('Effet des démarches', [_note('Aucune démarche sur cette période.')])];

  pw.Widget box(String title, NightStat? stat, String empty) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(color: _elevated, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 8, color: _muted)),
            stat == null
                ? pw.Text(empty, style: pw.TextStyle(fontSize: 8, color: _muted))
                : pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: formatAvg(stat.avg), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(text: ' / nuit · ${stat.nights} n.', style: pw.TextStyle(color: _muted)),
                    ]),
                  ),
          ]),
        ),
      );

  pw.Widget effect(ApproachEffect e) {
    final delta = e.delta;
    final kind = e.approach.kind;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: _pdf(kind.color), width: 3)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Row(children: [
          pw.Expanded(
            child: pw.Text('${kind.label} · ${e.approach.label}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          if (delta != null)
            pw.Text(
              '${delta > 0 ? '+' : ''}$delta %',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: delta < 0 ? _success : delta > 0 ? _error : _muted,
              ),
            ),
        ]),
        pw.Text(approachDates(e.approach, s.today), style: pw.TextStyle(fontSize: 8, color: _muted)),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          box('Avant', e.before, 'Pas de données'),
          pw.SizedBox(width: 6),
          box('Pendant', e.during, 'Pas encore de nuit complète'),
        ]),
      ]),
    );
  }

  return [
    pw.Text('Effet des démarches', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 6),
    for (final e in effects) effect(e),
    _note(
      'Réveils nocturnes par nuit (levers exclus) : pendant la démarche, comparés aux $beforeNights nuits précédant '
      "son début. Calcul sur tout l'historique, indépendamment de la période choisie ; plusieurs démarches "
      'simultanées peuvent se combiner.',
    ),
    pw.SizedBox(height: 12),
  ];
}

pw.Widget _reasons(JournalStats s) {
  final r = s.topReasons;
  return _section('Top 10 des raisons', [
    if (r.top.isEmpty) _note('Aucune raison renseignée sur cette période.'),
    for (final (i, reason) in r.top.indexed)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(children: [
            pw.Text('${i + 1}. ', style: pw.TextStyle(color: _muted)),
            pw.Expanded(child: pw.Text(reason.label, maxLines: 1)),
            _countPct(reason.value, reason.pct),
          ]),
          pw.SizedBox(height: 2),
          pw.Container(
            height: 5,
            decoration: pw.BoxDecoration(color: _elevated, borderRadius: pw.BorderRadius.circular(3)),
            child: pw.Row(children: [
              pw.Expanded(
                flex: reason.value,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: _pdf(AppColors.primary),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                ),
              ),
              if (r.max > reason.value) pw.Spacer(flex: r.max - reason.value),
            ]),
          ),
        ]),
      ),
    if (r.withoutReason > 0)
      _note('${r.withoutReason} réveil(s) sans raison renseignée. Pourcentages calculés sur le nombre de réveils.'),
  ]);
}
