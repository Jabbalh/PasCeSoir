import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillController;
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../main.dart';
import '../theme.dart';
import '../utils/night.dart';
import '../widgets/rich_text_editor.dart';
import '../widgets/tag_picker.dart';
import '../widgets/watch_state.dart';

/// Création (`wid` = `nouveau`) ou détail / modification d'un réveil
class WakeupScreen extends StatefulWidget {
  const WakeupScreen({super.key, required this.journalId, required this.wakeupId});

  final String journalId;
  final String wakeupId;

  @override
  State<WakeupScreen> createState() => _WakeupScreenState();
}

class _WakeupScreenState extends State<WakeupScreen> with WatchState {
  bool get _isNew => widget.wakeupId == 'nouveau';

  var _members = <Member>[];
  var _options = OptionList(const []);

  Wakeup? _original;
  var _loaded = false;
  var _notFound = false;
  var _saving = false;

  var _wokeAt = DateTime.now();
  WakeType? _wakeType;
  var _reasonIds = <String>[];
  var _actionIds = <String>[];
  QuillController _comment = quillControllerFromHtml('');

  @override
  void initState() {
    super.initState();
    watch(repo.watchMembers(widget.journalId), (m) => _members = m);
    watch(repo.watchOptions(widget.journalId), (o) => _options = OptionList(o));
    _load();
  }

  /// Chargement ponctuel (pas réactif) pour ne pas écraser la saisie en cours si une synchro arrive
  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loaded = true);
      return;
    }
    final w = await repo.getWakeup(widget.wakeupId);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      if (w == null || w.deleted) {
        _notFound = true;
        return;
      }
      _original = w;
      _wokeAt = w.wokeAt;
      _wakeType = w.wakeType;
      _reasonIds = [...w.reasonIds];
      _actionIds = [...w.actionIds];
      _comment.dispose();
      _comment = quillControllerFromHtml(w.comment);
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/journal/${widget.journalId}');
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _wokeAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_wokeAt));
    if (time == null) return;
    setState(() => _wokeAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  /// « Autre… » : ajoute l'option au paramétrage du journal pour pouvoir la réutiliser
  Future<String> _create(OptionKind kind, String label) async =>
      (await repo.addOption(widget.journalId, kind, label)).id;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final patch = {
        'woke_at': _wokeAt.toUtc().toIso8601String(),
        'wake_type': _wakeType?.name,
        'reason_ids': [..._reasonIds],
        'action_ids': [..._actionIds],
        'comment': quillControllerToHtml(_comment),
      };
      final r = repo;
      if (_isNew) {
        final w = await r.addWakeup(widget.journalId, _wokeAt);
        await r.updateWakeup(w.id, patch);
      } else {
        await r.updateWakeup(widget.wakeupId, patch);
      }
      if (!mounted) return;
      showToast(context, 'Réveil enregistré', duration: const Duration(seconds: 2));
      _goBack();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce réveil ?'),
        content: const Text('Cette action est réversible quelques secondes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final id = widget.wakeupId;
    final r = repo;
    await r.deleteWakeup(id);
    if (!mounted) return;
    showToast(context, 'Réveil supprimé', actions: [(label: 'Annuler', onPressed: () => r.restoreWakeup(id))]);
    _goBack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Retour', onPressed: _goBack),
        title: Text(_isNew ? 'Nouveau réveil' : 'Détail du réveil', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!_isNew && !_notFound)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Supprimer',
              onPressed: _delete,
            ),
          if (!_notFound)
            IconButton(icon: const Icon(Icons.check), tooltip: 'Enregistrer', onPressed: _saving ? null : _save),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _notFound
              ? _notFoundView()
              : _form(),
    );
  }

  Widget _notFoundView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text('Réveil introuvable', style: TextStyle(fontWeight: FontWeight.w600)),
            const Text('Il a peut-être été supprimé.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            TextButton(onPressed: () => context.go('/journal/${widget.journalId}'), child: const Text('Retour au journal')),
          ],
        ),
      );

  Widget _label(String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
            ?trailing,
          ],
        ),
      );

  Widget _form() {
    final original = _original;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _label('Date et heure du réveil'),
        InkWell(
          onTap: _pickDateTime,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.event)),
            child: Text(formatDateTime(_wokeAt), style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 24),
        _label('Type de réveil'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in WakeType.values)
              ChoiceChip(
                avatar: Icon(t.icon, size: 18),
                label: Text(t.label),
                selected: _wakeType == t,
                showCheckmark: false,
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() => _wakeType = _wakeType == t ? null : t),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _label(
          'Raison(s) du réveil',
          trailing: TextButton(
            onPressed: () => context.go('/journal/${widget.journalId}/reglages'),
            child: const Text('Gérer la liste', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ),
        TagPicker(
          options: _options.reasons,
          selected: _reasonIds,
          onChanged: (ids) => setState(() => _reasonIds = ids),
          labelOf: _options.labelOf,
          create: (label) => _create(OptionKind.reason, label),
          color: AppColors.warning,
          placeholder: 'Autre raison…',
        ),
        const SizedBox(height: 24),
        _label('Ce qui a été fait'),
        TagPicker(
          options: _options.actions,
          selected: _actionIds,
          onChanged: (ids) => setState(() => _actionIds = ids),
          labelOf: _options.labelOf,
          create: (label) => _create(OptionKind.action, label),
          color: AppColors.success,
          placeholder: 'Autre action…',
        ),
        const SizedBox(height: 24),
        _label('Commentaire'),
        RichTextEditor(controller: _comment, placeholder: 'Durée, humeur, détails…'),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.edit_note, size: 18, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: original != null
                  ? Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Enregistré par '),
                        TextSpan(
                          text: authorName(_members, original.createdBy, auth.user!.id),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextSpan(text: ' le ${formatDateTime(original.createdAt)}'),
                      ]),
                      style: const TextStyle(fontSize: 14, color: AppColors.muted),
                    )
                  : const Text('Sera enregistré à votre nom', style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
