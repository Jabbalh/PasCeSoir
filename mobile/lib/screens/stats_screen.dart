import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../main.dart';
import '../services/stats_pdf.dart';
import '../theme.dart';
import '../utils/approach.dart';
import '../utils/night.dart';
import '../utils/stats.dart';
import '../widgets/column_chart.dart';
import '../widgets/section_card.dart';
import '../widgets/watch_state.dart';

const _presets = [(label: '7 j', days: 7), (label: '30 j', days: 30), (label: '3 mois', days: 91), (label: '1 an', days: 365)];

const _tabular = [FontFeature.tabularFigures()];

/// Statistiques d'un journal sur une période, export PDF
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.journalId});

  final String journalId;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with WatchState {
  Journal? _journal;
  List<Wakeup>? _wakeups;
  List<Approach> _approaches = const [];
  OptionList _options = OptionList(const []);

  var _from = toDateKey(addDays(DateTime.now(), -29));
  var _to = toDateKey(DateTime.now());
  var _granularity = Granularity.week;
  var _showTable = false;
  var _exporting = false;

  @override
  void initState() {
    super.initState();
    watch(repo.watchJournal(widget.journalId), (j) => _journal = j);
    watch(repo.watchWakeups(widget.journalId), (w) => _wakeups = w);
    watch(repo.watchApproaches(widget.journalId), (a) => _approaches = a);
    watch(repo.watchOptions(widget.journalId), (o) => _options = OptionList(o));
  }

  String get _today => toDateKey(DateTime.now());

  void _applyPreset(int days) => setState(() {
        _to = _today;
        _from = toDateKey(addDays(DateTime.now(), -(days - 1)));
      });

  void _applyAll() => setState(() {
        final wakeups = _wakeups ?? const [];
        _from = wakeups.isEmpty ? _today : nightKey(wakeups.last.wokeAt);
        _to = _today;
      });

  int? get _activePreset {
    if (_to != _today) return null;
    return _presets.where((p) => _from == toDateKey(addDays(DateTime.now(), -(p.days - 1)))).firstOrNull?.days;
  }

  Future<void> _pickDate(bool isFrom) async {
    final date = await showDatePicker(
      context: context,
      initialDate: fromDateKey(isFrom ? _from : _to),
      firstDate: isFrom ? DateTime(2020) : fromDateKey(_from),
      lastDate: isFrom ? fromDateKey(_to) : DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      if (isFrom) {
        _from = toDateKey(date);
      } else {
        _to = toDateKey(date);
      }
    });
  }

  Future<void> _exportPdf(JournalStats stats) async {
    setState(() => _exporting = true);
    try {
      await shareStatsPdf(stats, withTable: _showTable);
    } catch (e) {
      if (mounted) showToast(context, 'Impossible de générer le PDF', description: '$e', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wakeups = _wakeups;
    final stats = wakeups == null
        ? null
        : JournalStats(
            wakeups: wakeups,
            approaches: _approaches,
            journal: _journal,
            labelOf: _options.labelOf,
            from: _from,
            to: _to,
            granularity: _granularity,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_journal?.name ?? '', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                  const Text('Statistiques', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: stats == null || _exporting ? null : () => _exportPdf(stats),
              icon: _exporting
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('PDF'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _period(),
        const SizedBox(height: 20),
        if (stats == null)
          const Center(child: CircularProgressIndicator())
        else
          ..._content(stats),
      ],
    );
  }

  Widget _period() {
    final active = _activePreset;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: active == p.days,
                    showCheckmark: false,
                    onSelected: (_) => _applyPreset(p.days),
                  ),
                ActionChip(label: const Text('Tout'), onPressed: _applyAll),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateField('Du (nuit du)', _from, () => _pickDate(true))),
                const SizedBox(width: 12),
                Expanded(child: _dateField('Au (nuit du)', _to, () => _pickDate(false))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.event, size: 20)),
          child: Text(formatDay(value)),
        ),
      );

  List<Widget> _content(JournalStats s) {
    const gap = SizedBox(height: 16);
    return [
      _keyFigures(s),
      gap,
      _byType(s),
      gap,
      _series(s),
      gap,
      _effects(s),
      gap,
      _reasons(s),
      gap,
      SectionCard(title: 'À quelle heure ?', child: ColumnChart(items: s.byHour)),
    ];
  }

  Widget _keyFigures(JournalStats s) {
    Widget tile(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, fontFeatures: _tabular)),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile('${s.inRange.length}', 'réveils'),
          const SizedBox(width: 8),
          tile(formatAvg(s.avgPerNight), 'par nuit'),
          const SizedBox(width: 8),
          tile('${s.nightsCount - s.nightsWithWakeup}', 'nuit(s) sans réveil\nsur ${s.nightsCount}'),
        ],
      ),
    );
  }

  Widget _byType(JournalStats s) {
    final total = s.inRange.length;
    return SectionCard(
      title: 'Lever ou réveil nocturne',
      child: total == 0
          ? const Text('Aucun réveil sur cette période.', style: TextStyle(fontSize: 14, color: AppColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        for (final t in s.byType)
                          if (t.count > 0) Expanded(flex: t.count, child: ColoredBox(color: t.segment.color)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final t in s.byType)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        _dot(t.segment.color),
                        const SizedBox(width: 8),
                        Icon(t.segment.icon, size: 16, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t.segment.label, style: const TextStyle(fontSize: 14))),
                        _countPct(t.count, t.pct),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _series(JournalStats s) {
    final week = _granularity == Granularity.week;
    return SectionCard(
      title: 'Réveils par ${week ? 'semaine' : 'mois'}',
      trailing: SegmentedButton<Granularity>(
        segments: const [
          ButtonSegment(value: Granularity.week, label: Text('Semaine')),
          ButtonSegment(value: Granularity.month, label: Text('Mois')),
        ],
        selected: {_granularity},
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        onSelectionChanged: (v) => setState(() => _granularity = v.first),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ColumnChart(items: s.series, bands: s.approachBands),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final t in typeSegments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(t.color),
                    const SizedBox(width: 6),
                    Text(t.label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
            ],
          ),
          TextButton.icon(
            onPressed: () => setState(() => _showTable = !_showTable),
            icon: Icon(_showTable ? Icons.bar_chart : Icons.table_chart_outlined, size: 18),
            label: Text(_showTable ? 'Masquer le tableau' : 'Voir en tableau'),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted, padding: EdgeInsets.zero),
          ),
          if (_showTable) _table(s, week),
        ],
      ),
    );
  }

  Widget _table(JournalStats s, bool week) {
    const head = TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500);
    const cell = TextStyle(fontSize: 13, fontFeatures: _tabular);
    Widget c(String text, TextStyle style, {bool right = true}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(text, style: style, textAlign: right ? TextAlign.right : TextAlign.left),
        );
    const line = BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border)));
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.4)},
      children: [
        TableRow(decoration: line, children: [
          c(week ? 'Semaine du' : 'Mois', head, right: false),
          for (final t in typeSegments) c(t.label, head),
          c('Total', head),
        ]),
        for (final item in s.series.reversed)
          TableRow(decoration: line, children: [
            c(item.label, cell, right: false),
            for (final n in item.counts!) c('$n', cell.copyWith(color: AppColors.muted)),
            c('${item.value}', cell.copyWith(fontWeight: FontWeight.w600)),
          ]),
      ],
    );
  }

  Widget _effects(JournalStats s) {
    final effects = s.approachEffects;
    return SectionCard(
      title: 'Effet des démarches',
      trailing: TextButton(
        onPressed: () => context.go('/journal/${widget.journalId}/demarches'),
        style: TextButton.styleFrom(foregroundColor: AppColors.muted, visualDensity: VisualDensity.compact),
        child: const Text('Gérer', style: TextStyle(fontSize: 12)),
      ),
      child: effects.isEmpty
          ? const Text('Aucune démarche sur cette période.', style: TextStyle(fontSize: 14, color: AppColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, e) in effects.indexed) ...[
                  if (i > 0) const Divider(height: 20),
                  _effect(e, s.today),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Réveils nocturnes par nuit (levers exclus) : pendant la démarche, comparés aux $beforeNights nuits '
                  "précédant son début. Calcul sur tout l'historique, indépendamment de la période choisie ; "
                  'plusieurs démarches simultanées peuvent se combiner.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
    );
  }

  Widget _effect(ApproachEffect e, String today) {
    final kind = e.approach.kind;
    final delta = e.delta;
    Widget box(String title, NightStat? stat, String empty) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                if (stat != null)
                  Text.rich(TextSpan(children: [
                    TextSpan(text: formatAvg(stat.avg), style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                      text: ' / nuit · ${stat.nights} n.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ]), style: const TextStyle(fontSize: 14, fontFeatures: _tabular))
                else
                  Text(empty, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: kind.color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(kind.icon, size: 14, color: kind.color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(e.approach.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            if (delta != null) _deltaBadge(delta),
          ],
        ),
        const SizedBox(height: 4),
        Text(approachDates(e.approach, today), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 6),
        Row(
          children: [
            box('Avant', e.before, 'Pas de données'),
            const SizedBox(width: 8),
            box('Pendant', e.during, 'Pas encore de nuit complète'),
          ],
        ),
      ],
    );
  }

  Widget _deltaBadge(int delta) {
    final color = delta < 0 ? AppColors.success : delta > 0 ? AppColors.error : AppColors.muted;
    final icon = delta < 0 ? Icons.trending_down : delta > 0 ? Icons.trending_up : Icons.remove;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('${delta > 0 ? '+' : ''}$delta %',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFeatures: _tabular)),
        ],
      ),
    );
  }

  Widget _reasons(JournalStats s) {
    final r = s.topReasons;
    return SectionCard(
      title: 'Top 10 des raisons',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.top.isEmpty)
            const Text('Aucune raison renseignée sur cette période.',
                style: TextStyle(fontSize: 14, color: AppColors.muted))
          else
            for (final (i, reason) in r.top.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('${i + 1}. ', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                        Expanded(
                          child: Text(reason.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        ),
                        _countPct(reason.value, reason.pct),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: reason.value / r.max,
                        minHeight: 8,
                        color: AppColors.primary,
                        backgroundColor: AppColors.border.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
          if (r.withoutReason > 0)
            Text(
              '${r.withoutReason} réveil(s) sans raison renseignée. Pourcentages calculés sur le nombre de réveils.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ),
    );
  }

  Widget _dot(Color color) =>
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _countPct(int count, int pct) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$count', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          TextSpan(text: ' · $pct %'),
        ]),
        style: const TextStyle(fontSize: 14, color: AppColors.muted, fontFeatures: _tabular),
      );
}
