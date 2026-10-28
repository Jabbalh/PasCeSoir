import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/watch_state.dart';

/// Ouverture directe du dernier journal consulté, une seule fois au lancement de l'app
var _autoOpen = true;

/// Accueil : liste des journaux
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WatchState {
  List<Journal>? journals;
  var _counts = <String, int>{};

  @override
  void initState() {
    super.initState();
    watch(repo.watchJournals(), (j) {
      journals = j;
      _openLastJournal(j);
    });
    watch(repo.watchWakeupCounts(), (c) => _counts = c);
  }

  void _openLastJournal(List<Journal> journals) {
    if (!_autoOpen) return;
    _autoOpen = false;
    final last = prefs.getString('pcs:lastJournal');
    final target = journals.where((j) => j.id == last).firstOrNull ?? (journals.length == 1 ? journals.first : null);
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/journal/${target.id}');
    });
  }

  Future<void> _create() async {
    final journal = await showDialog<Journal>(context: context, builder: (_) => const _CreateJournalDialog());
    if (journal == null || !mounted) return;
    showToast(context, 'Journal créé');
    context.go('/journal/${journal.id}');
  }

  @override
  Widget build(BuildContext context) {
    final journals = this.journals;
    return Scaffold(
      appBar: const AppHeader(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Mes journaux', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Nouveau'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (journals == null)
            const Center(child: CircularProgressIndicator())
          else if (journals.isEmpty)
            const _Empty()
          else
            for (final j in journals)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _JournalTile(journal: j, count: _counts[j.id] ?? 0),
              ),
        ],
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  const _JournalTile({required this.journal, required this.count});

  final Journal journal;
  final int count;

  @override
  Widget build(BuildContext context) {
    final initial = (journal.childName.isNotEmpty ? journal.childName : journal.name).characters.first.toUpperCase();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          foregroundColor: AppColors.primary,
          child: Text(initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        title: Text(journal.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        subtitle: Text('$count réveil(s) enregistré(s)', style: const TextStyle(color: AppColors.muted)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (journal.dirty) const Icon(Icons.cloud_upload_outlined, color: AppColors.warning, size: 16),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
        onTap: () => context.go('/journal/${journal.id}'),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.bedtime_outlined, size: 48, color: AppColors.muted),
          SizedBox(height: 12),
          Text('Aucun journal pour le moment', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text(
            "Créez le journal des nuits de votre enfant, puis partagez-le avec l'autre parent.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CreateJournalDialog extends StatefulWidget {
  const _CreateJournalDialog();

  @override
  State<_CreateJournalDialog> createState() => _CreateJournalDialogState();
}

class _CreateJournalDialogState extends State<_CreateJournalDialog> {
  final _childName = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _childName.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final child = _childName.text.trim();
    if (child.isEmpty) return;
    final name = _name.text.trim();
    final journal = await repo.createJournal(name: name.isNotEmpty ? name : 'Les nuits de $child', childName: child);
    if (mounted) Navigator.pop(context, journal);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau journal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _childName,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: "Prénom de l'enfant"),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Nom du journal',
              helperText: _childName.text.trim().isNotEmpty ? 'Par défaut : Les nuits de ${_childName.text.trim()}' : 'Optionnel',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(onPressed: _childName.text.trim().isEmpty ? null : _submit, child: const Text('Créer')),
      ],
    );
  }
}
