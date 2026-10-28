import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../main.dart';
import '../theme.dart';
import '../utils/approach.dart';
import '../utils/night.dart';
import '../widgets/wakeup_card.dart';
import '../widgets/watch_state.dart';

/// Journal : gros bouton RÉVEIL, nuit en cours, nuits précédentes
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.journalId});

  final String journalId;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> with WatchState {
  Journal? _journal;
  var _loading = true;
  var _members = <Member>[];
  var _wakeups = <Wakeup>[];
  var _options = OptionList(const []);
  var _approaches = <Approach>[];

  var _now = DateTime.now();
  Timer? _clock;
  var _visibleNights = 7;
  var _approachesOpen = false;

  @override
  void initState() {
    super.initState();
    final r = repo;
    final id = widget.journalId;
    watch(r.watchJournal(id), (j) {
      _journal = j;
      _loading = false;
    });
    watch(r.watchMembers(id), (m) => _members = m);
    watch(r.watchWakeups(id), (w) => _wakeups = w);
    watch(r.watchOptions(id), (o) => _options = OptionList(o));
    watch(r.watchApproaches(id), (a) => _approaches = a);
    prefs.setString('pcs:lastJournal', id);
    // Rafraîchit la « nuit en cours » régulièrement (l'app peut rester ouverte longtemps)
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _author(String? userId) => authorName(_members, userId, auth.user!.id);

  /// Réveils groupés par nuit (plus récente d'abord), ordre chronologique dans une nuit
  Map<String, List<Wakeup>> get _nights {
    final groups = <String, List<Wakeup>>{};
    for (final w in _wakeups) {
      groups.putIfAbsent(nightKey(w.wokeAt), () => []).add(w);
    }
    return groups.map((k, list) => MapEntry(k, list.reversed.toList()));
  }

  Future<void> _recordWakeup() async {
    HapticFeedback.mediumImpact();
    final w = await repo.addWakeup(widget.journalId);
    if (!mounted) return;
    showToast(
      context,
      'Réveil enregistré à ${formatTime(w.wokeAt)}',
      description: 'Vous pourrez le compléter plus tard.',
      actions: [
        (
          label: 'Compléter',
          onPressed: () {
            if (mounted) context.push('/journal/${widget.journalId}/reveil/${w.id}');
          }
        ),
        (label: 'Annuler', onPressed: () => repo.deleteWakeup(w.id)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final journal = _journal;
    if (journal == null || journal.deleted) return const _NotFound();

    final currentNight = nightKey(_now);
    final nights = _nights;
    final tonight = nights[currentNight] ?? const <Wakeup>[];
    final pastNights = nights.entries.where((e) => e.key != currentNight).toList();
    final today = toDateKey(_now);
    final currentApproaches = _approaches.where((a) => approachStatus(a, today) == ApproachStatus.enCours).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(journal.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        Text(
          journal.childName.isNotEmpty ? "${journal.childName} s'est réveillé·e ?" : 'Un réveil ?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Center(child: _WakeButton(now: _now, onPressed: _recordWakeup)),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push('/journal/${widget.journalId}/reveil/nouveau'),
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('Saisir un réveil à une autre heure'),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          ),
        ),
        const SizedBox(height: 16),
        if (currentApproaches.isNotEmpty) ...[
          _CurrentApproaches(
            approaches: currentApproaches,
            open: _approachesOpen,
            onToggle: () => setState(() => _approachesOpen = !_approachesOpen),
            onManage: () => context.go('/journal/${widget.journalId}/demarches'),
          ),
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            const Expanded(child: Text('Cette nuit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            Text('${tonight.length} réveil(s)', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 8),
        if (tonight.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Aucun réveil pour l'instant. Bonne nuit ! 🌙",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          )
        else
          for (final w in tonight) _card(w),
        if (pastNights.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Nuits précédentes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          for (final MapEntry(key: key, value: list) in pastNights.take(_visibleNights)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(nightLabel(key), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
                  child: Text('${list.length}', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final w in list) _card(w),
          ],
          if (pastNights.length > _visibleNights) ...[
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => setState(() => _visibleNights += 7),
              child: const Text('Voir plus de nuits'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _card(Wakeup w) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: WakeupCard(wakeup: w, author: _author(w.createdBy), labelOf: _options.labelOf),
      );
}

/// Le gros bouton : un appui = un réveil horodaté (anti double-appui de 2 s)
class _WakeButton extends StatefulWidget {
  const _WakeButton({required this.now, required this.onPressed});

  final DateTime now;
  final VoidCallback onPressed;

  @override
  State<_WakeButton> createState() => _WakeButtonState();
}

class _WakeButtonState extends State<_WakeButton> {
  var _pressing = false;
  var _cooldown = false;

  void _press() {
    if (_cooldown) return;
    setState(() {
      _cooldown = true;
      _pressing = true;
    });
    Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _pressing = false);
    });
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _cooldown = false);
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Enregistrer un réveil maintenant',
      child: AnimatedScale(
        scale: _pressing ? 0.95 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 224,
          height: 224,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF818CF8), Color(0xFF4338CA)], // indigo-400 -> indigo-700
            ),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 60, spreadRadius: -10)],
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 4),
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _press,
              child: Opacity(
                opacity: _cooldown ? 0.8 : 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_cooldown ? Icons.check : Icons.child_care, size: 64, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      _cooldown ? 'Noté !' : 'RÉVEIL',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTime(widget.now),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Démarches en place aujourd'hui (rappel compact, replié par défaut)
class _CurrentApproaches extends StatelessWidget {
  const _CurrentApproaches({required this.approaches, required this.open, required this.onToggle, required this.onManage});

  final List<Approach> approaches;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final n = approaches.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.checklist, size: 16, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$n', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        TextSpan(text: ' démarche${n > 1 ? 's' : ''} en cours'),
                      ]),
                      style: const TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in approaches)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: a.kind.color.withValues(alpha: 0.12),
                            border: Border.all(color: a.kind.color.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(a.kind.icon, size: 12, color: a.kind.color),
                              const SizedBox(width: 4),
                              Text(
                                a.periods.isEmpty ? a.label : '${a.label} · ${periodsLabel(a.periods)}',
                                style: TextStyle(fontSize: 12, color: a.kind.color),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onManage,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Gérer les démarches', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        Icon(Icons.chevron_right, size: 14, color: AppColors.muted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text('Journal introuvable', style: TextStyle(fontWeight: FontWeight.w600)),
            const Text(
              "Il a peut-être été supprimé ou vous n'en faites plus partie.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go('/'), child: const Text('Mes journaux')),
          ],
        ),
      ),
    );
  }
}
