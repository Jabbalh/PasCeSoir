import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../data/models.dart';
import '../main.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/token.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/options_editor.dart';
import '../widgets/section_card.dart';
import '../widgets/watch_state.dart';

final _supabase = Supabase.instance.client;

/// Réglages d'un journal : informations, raisons / actions, partage, membres, zone sensible
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.journalId});

  final String journalId;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WatchState {
  Journal? _journal;
  var _members = <Member>[];
  var _options = OptionList(const []);
  var _usage = <String, int>{};

  final _name = TextEditingController();
  final _childName = TextEditingController();
  var _formFilled = false;
  var _optionKind = OptionKind.reason;
  var _sharing = false;

  String get _me => auth.user!.id;

  bool get _isOwner =>
      _journal?.createdBy == _me || _members.any((m) => m.userId == _me && m.isOwner);

  @override
  void initState() {
    super.initState();
    final id = widget.journalId;
    watch(repo.watchJournal(id), (j) {
      _journal = j;
      if (j != null && !_formFilled) {
        _formFilled = true;
        _name.text = j.name;
        _childName.text = j.childName;
      }
    });
    watch(repo.watchMembers(id), (m) => _members = m);
    watch(repo.watchOptions(id), (o) => _options = OptionList(o));
    watch(repo.watchWakeups(id), (wakeups) {
      final usage = <String, int>{};
      for (final w in wakeups) {
        for (final o in [...w.reasonIds, ...w.actionIds]) {
          usage[o] = (usage[o] ?? 0) + 1;
        }
      }
      _usage = usage;
    });
    syncService.addListener(_onSync);
  }

  /// L'état « en ligne » conditionne les actions de partage et de membres
  void _onSync() => setState(() {});

  @override
  void dispose() {
    syncService.removeListener(_onSync);
    _name.dispose();
    _childName.dispose();
    super.dispose();
  }

  // --- Informations ---

  Future<void> _saveInfo() async {
    if (_name.text.trim().isEmpty) {
      showToast(context, 'Indiquez un nom pour le journal', error: true);
      return;
    }
    await repo.updateJournal(widget.journalId, {'name': _name.text.trim(), 'child_name': _childName.text.trim()});
    if (mounted) showToast(context, 'Journal mis à jour');
  }

  // --- Partage ---

  String? get _shareUrl {
    final token = _journal?.shareToken;
    return token == null ? null : '$webBaseUrl/rejoindre/$token';
  }

  Future<void> _setShareToken(String? token) async {
    setState(() => _sharing = true);
    try {
      // le journal doit exister côté serveur avant de générer un lien
      await syncService.sync();
      await _supabase.from('journals').update({'share_token': token}).eq('id', widget.journalId);
      await syncService.sync();
      if (mounted) showToast(context, token != null ? 'Lien de partage créé' : 'Lien de partage désactivé');
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _share() async {
    final child = _journal?.childName ?? '';
    await shareLink(
        _shareUrl!, 'Rejoins le journal des nuits de ${child.isNotEmpty ? child : 'notre enfant'} sur Pas ce soir');
  }

  Future<void> _copy() async {
    await copyText(_shareUrl!);
    if (mounted) showToast(context, 'Lien copié');
  }

  // --- Membres ---

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showToast(context, 'Oups', description: errorMessage(e), error: true);
    }
  }

  Future<void> _removeMember(Member m) async {
    final ok = await confirmAction(context,
        title: 'Retirer ${m.displayName} ?', description: "Cette personne n'aura plus accès au journal.", label: 'Retirer');
    if (!ok) return;
    await _run(() async {
      await _supabase.from('journal_members').delete().eq('journal_id', widget.journalId).eq('user_id', m.userId);
      await syncService.sync();
    });
  }

  Future<void> _leave() async {
    final ok = await confirmAction(context,
        title: 'Quitter ce journal ?', description: "Vous n'y aurez plus accès, sauf nouvelle invitation.", label: 'Quitter');
    if (!ok) return;
    await _run(() async {
      await _supabase.from('journal_members').delete().eq('journal_id', widget.journalId).eq('user_id', _me);
      await syncService.sync();
      if (mounted) context.go('/');
    });
  }

  Future<void> _delete() async {
    final ok = await confirmAction(context,
        title: 'Supprimer ce journal ?',
        description: 'Le journal et tous ses réveils seront supprimés pour tous les membres.',
        label: 'Supprimer définitivement');
    if (!ok) return;
    await repo.updateJournal(widget.journalId, {'deleted_at': DateTime.now().toUtc().toIso8601String()});
    await prefs.remove('pcs:lastJournal');
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final online = syncService.online;
    final shareUrl = _shareUrl;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Réglages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Journal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _childName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: "Prénom de l'enfant"),
              ),
              const SizedBox(height: 16),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom du journal')),
              const SizedBox(height: 16),
              FilledButton(onPressed: _saveInfo, child: const Text('Enregistrer')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Raisons et actions',
          subtitle:
              "Les choix proposés lors de la saisie d'un réveil. Touchez un libellé pour le renommer : l'historique est mis à jour.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<OptionKind>(
                segments: [
                  ButtonSegment(value: OptionKind.reason, label: Text('Raisons (${_options.reasons.length})')),
                  ButtonSegment(value: OptionKind.action, label: Text('Actions (${_options.actions.length})')),
                ],
                selected: {_optionKind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _optionKind = s.first),
              ),
              const SizedBox(height: 12),
              OptionsEditor(
                key: ValueKey(_optionKind),
                journalId: widget.journalId,
                kind: _optionKind,
                options: _optionKind == OptionKind.reason ? _options.reasons : _options.actions,
                archived: _options.archived,
                usage: _usage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Partager le journal',
          subtitle: "Envoyez ce lien à l'autre parent, à la nounou… Il pourra créer un compte et rejoindre le journal.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!online) ...[
                const InfoBanner(icon: Icons.wifi_off, title: 'Connexion internet requise pour gérer le partage'),
                const SizedBox(height: 12),
              ],
              if (shareUrl != null) ...[
                SelectableText(shareUrl, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('Partager')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                          onPressed: _copy, icon: const Icon(Icons.copy), label: const Text('Copier')),
                    ),
                  ],
                ),
                if (_isOwner)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: !online || _sharing ? null : () => _setShareToken(randomToken()),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Nouveau lien'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                      ),
                      TextButton.icon(
                        onPressed: !online || _sharing ? null : () => _setShareToken(null),
                        icon: const Icon(Icons.link_off, size: 16),
                        label: const Text('Désactiver le lien'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      ),
                    ],
                  ),
              ] else if (_isOwner)
                FilledButton.icon(
                  onPressed: !online || _sharing ? null : () => _setShareToken(randomToken()),
                  icon: const Icon(Icons.link),
                  label: const Text("Créer un lien d'invitation"),
                )
              else
                const Text("Seul le créateur du journal peut créer un lien d'invitation.",
                    style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Membres (${_members.length})',
          child: Column(
            children: [
              for (final m in _members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text(m.displayName.isNotEmpty ? m.displayName.characters.first.toUpperCase() : '?'),
                  ),
                  title: Text(m.userId == _me ? '${m.displayName} (moi)' : m.displayName,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(m.isOwner ? 'Créateur' : 'Membre', style: const TextStyle(fontSize: 12)),
                  trailing: _isOwner && m.userId != _me
                      ? IconButton(
                          icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                          tooltip: 'Retirer',
                          onPressed: online ? () => _removeMember(m) : null,
                        )
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Zone sensible',
          danger: true,
          child: _isOwner
              ? FilledButton.tonalIcon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer le journal'),
                  style: FilledButton.styleFrom(foregroundColor: AppColors.error),
                )
              : FilledButton.tonalIcon(
                  onPressed: online ? _leave : null,
                  icon: const Icon(Icons.logout),
                  label: const Text('Quitter le journal'),
                  style: FilledButton.styleFrom(foregroundColor: AppColors.error),
                ),
        ),
      ],
    );
  }
}
