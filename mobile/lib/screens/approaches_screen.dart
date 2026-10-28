import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../main.dart';
import '../theme.dart';
import '../utils/approach.dart';
import '../utils/night.dart';
import '../widgets/approach_card.dart';
import '../widgets/watch_state.dart';

/// Démarches d'un journal : en cours, à venir, terminées
class ApproachesScreen extends StatefulWidget {
  const ApproachesScreen({super.key, required this.journalId});

  final String journalId;

  @override
  State<ApproachesScreen> createState() => _ApproachesScreenState();
}

class _ApproachesScreenState extends State<ApproachesScreen> with WatchState {
  Journal? _journal;
  List<Approach>? _approaches;
  var _today = toDateKey(DateTime.now());
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    watch(repo.watchJournal(widget.journalId), (j) => _journal = j);
    watch(repo.watchApproaches(widget.journalId), (a) => _approaches = a);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() => _today = toDateKey(DateTime.now())));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _new() => context.push('/journal/${widget.journalId}/demarches/nouveau');

  @override
  Widget build(BuildContext context) {
    final approaches = _approaches;
    final groups = {for (final s in ApproachStatus.values) s: <Approach>[]};
    for (final a in approaches ?? const <Approach>[]) {
      groups[approachStatus(a, _today)]!.add(a);
    }
    // à venir : la plus proche d'abord ; terminées : la plus récemment terminée d'abord
    final upcoming = groups[ApproachStatus.aVenir]!.reversed.toList();
    final finished = groups[ApproachStatus.terminee]!..sort((a, b) => b.endDate!.compareTo(a.endDate!));
    final sections = [
      ('En cours', groups[ApproachStatus.enCours]!),
      ('À venir', upcoming),
      ('Terminées', finished),
    ].where((s) => s.$2.isNotEmpty);

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
                  const Text('Démarches', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _new,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Rituels, médication… tout ce qui est mis en place pour améliorer les nuits, afin de suivre son effet sur les réveils.',
          style: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        if (approaches == null)
          const Center(child: CircularProgressIndicator())
        else if (approaches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Icon(Icons.checklist, size: 48, color: AppColors.muted),
                const SizedBox(height: 12),
                const Text('Aucune démarche', style: TextStyle(fontWeight: FontWeight.w600)),
                const Text(
                  "Ajoutez un rituel du coucher, un traitement, un changement d'environnement…",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _new,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle démarche'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ],
            ),
          )
        else
          for (final (title, items) in sections) ...[
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                Text('${items.length}', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            for (final a in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ApproachCard(approach: a, today: _today),
              ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
