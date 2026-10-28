import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/app_header.dart';
import '../widgets/section_card.dart';

final _supabase = Supabase.instance.client;

/// Journal possédé, tel que décrit par `account_deletion_preview`
typedef _OwnedJournal = ({String id, String name, int otherMembers});

/// Profil : nom affiché, suppression du compte
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayName = TextEditingController();
  var _saving = false;

  @override
  void initState() {
    super.initState();
    syncService.addListener(_onSync);
    _load();
  }

  void _onSync() => setState(() {});

  @override
  void dispose() {
    syncService.removeListener(_onSync);
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!syncService.online) return;
    try {
      final row = await _supabase.from('profiles').select('display_name').eq('id', auth.user!.id).single();
      if (mounted) _displayName.text = row['display_name'] as String? ?? '';
    } catch (_) {
      // hors ligne : le champ reste vide
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _supabase.from('profiles').update({'display_name': _displayName.text.trim()}).eq('id', auth.user!.id);
      if (mounted) showToast(context, 'Profil enregistré');
      syncService.sync();
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDelete() async {
    try {
      final rows = await _supabase.rpc('account_deletion_preview') as List<dynamic>;
      final owned = [
        for (final r in rows.cast<Map<String, dynamic>>())
          (id: r['journal_id'] as String, name: r['journal_name'] as String, otherMembers: (r['other_members'] as num).toInt())
      ];
      // journaux dont on est simple membre (données locales, à jour après synchro)
      final ownedIds = owned.map((j) => j.id).toSet();
      final memberOf = [
        for (final j in await repo.watchJournals().first)
          if (!ownedIds.contains(j.id)) j.name
      ];
      if (!mounted) return;
      final deleted = await showDialog<bool>(
        context: context,
        builder: (_) => _DeleteAccountDialog(owned: owned, memberOf: memberOf),
      );
      if (deleted == true && mounted) context.go('/connexion');
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = syncService.online;
    return Scaffold(
      appBar: const AppHeader(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text('Mon profil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    initialValue: auth.user?.email,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _displayName,
                    decoration: const InputDecoration(
                      labelText: 'Nom affiché',
                      helperText: 'Visible par les autres membres de vos journaux',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: !online || _saving ? null : _save,
                    child: Text(online ? 'Enregistrer' : 'Connexion requise'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Supprimer mon compte',
            subtitle: 'Suppression définitive de votre compte et de vos données. Cette action est irréversible.',
            danger: true,
            child: FilledButton.tonalIcon(
              onPressed: online ? _openDelete : null,
              icon: const Icon(Icons.person_off_outlined),
              label: Text(online ? 'Supprimer mon compte…' : 'Connexion requise'),
              style: FilledButton.styleFrom(foregroundColor: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.owned, required this.memberOf});

  final List<_OwnedJournal> owned;
  final List<String> memberOf;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  var _acknowledged = false;
  var _deleting = false;

  Future<void> _confirm() async {
    setState(() => _deleting = true);
    // La déconnexion renvoie vers la connexion et ferme cet écran : message affiché par l'application
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('Compte supprimé : toutes vos données ont été effacées.')));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Oups', description: errorMessage(e), error: true);
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shared = widget.owned.where((j) => j.otherMembers > 0).toList();
    final alone = widget.owned.where((j) => j.otherMembers == 0).toList();
    final pending = syncService.pendingCount;
    const muted = TextStyle(color: AppColors.muted);

    return AlertDialog(
      title: const Text('Supprimer votre compte ?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cette action est définitive.', style: muted),
            const SizedBox(height: 16),
            if (shared.isNotEmpty) ...[
              InfoBanner(
                icon: Icons.warning_amber,
                color: AppColors.error,
                title: 'Des journaux partagés seront supprimés pour tout le monde',
                description: [
                  for (final j in shared)
                    '• ${j.name} : ${j.otherMembers} autre(s) membre(s) perdront l\'accès et tout l\'historique'
                ].join('\n'),
              ),
              const SizedBox(height: 16),
            ],
            if (alone.isNotEmpty) ...[
              const Text('Vos journaux supprimés avec leurs réveils :', style: TextStyle(fontWeight: FontWeight.w500)),
              for (final j in alone) Text('• ${j.name}', style: muted),
              const SizedBox(height: 16),
            ],
            if (widget.memberOf.isNotEmpty) ...[
              const Text('Journaux que vous quitterez :', style: TextStyle(fontWeight: FontWeight.w500)),
              for (final name in widget.memberOf) Text('• $name', style: muted),
              const Text(
                'Ces journaux sont conservés. Les réveils que vous y avez saisis restent visibles, sans votre nom.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.owned.isEmpty && widget.memberOf.isEmpty)
              const Text("Vous n'avez aucun journal. Seul votre compte sera supprimé.", style: muted),
            if (pending > 0) ...[
              const SizedBox(height: 8),
              InfoBanner(icon: Icons.cloud_off, title: '$pending modification(s) non synchronisée(s) seront perdues'),
            ],
            if (shared.isNotEmpty)
              CheckboxListTile(
                value: _acknowledged,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Je comprends que ces journaux seront supprimés pour tous leurs membres',
                    style: TextStyle(fontSize: 14)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(
          onPressed: _deleting || (shared.isNotEmpty && !_acknowledged) ? null : _confirm,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Supprimer définitivement'),
        ),
      ],
    );
  }
}
