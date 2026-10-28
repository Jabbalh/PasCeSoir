import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillController;
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../main.dart';
import '../theme.dart';
import '../utils/approach.dart';
import '../utils/night.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/rich_text_editor.dart';
import '../widgets/watch_state.dart';

/// Création (`aid` = `nouveau`) ou détail / modification d'une démarche
class ApproachScreen extends StatefulWidget {
  const ApproachScreen({super.key, required this.journalId, required this.approachId});

  final String journalId;
  final String approachId;

  @override
  State<ApproachScreen> createState() => _ApproachScreenState();
}

class _ApproachScreenState extends State<ApproachScreen> with WatchState {
  bool get _isNew => widget.approachId == 'nouveau';
  final _today = toDateKey(DateTime.now());

  var _members = <Member>[];
  Approach? _original;
  var _loaded = false;
  var _notFound = false;
  var _saving = false;

  ApproachKind? _kind;
  final _label = TextEditingController();
  late String _startDate = _today;
  String? _endDate;
  var _periods = <ApproachPeriod>[];
  QuillController _comment = quillControllerFromHtml('');

  @override
  void initState() {
    super.initState();
    watch(repo.watchMembers(widget.journalId), (m) => _members = m);
    _load();
  }

  /// Chargement ponctuel (pas réactif) pour ne pas écraser la saisie en cours si une synchro arrive
  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loaded = true);
      return;
    }
    final a = await repo.getApproach(widget.approachId);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      if (a == null || a.deleted) {
        _notFound = true;
        return;
      }
      _original = a;
      _kind = a.kind;
      _label.text = a.label;
      _startDate = a.startDate;
      _endDate = a.endDate;
      _periods = [...a.periods];
      _comment.dispose();
      _comment = quillControllerFromHtml(a.comment);
    });
  }

  @override
  void dispose() {
    _label.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/journal/${widget.journalId}/demarches');
    }
  }

  Future<String?> _pickDate(String? current, {String? min, String? max}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: fromDateKey(current ?? min ?? _today),
      firstDate: min != null ? fromDateKey(min) : DateTime(2020),
      lastDate: max != null ? fromDateKey(max) : DateTime(2100),
    );
    return date == null ? null : toDateKey(date);
  }

  void _error(String title) => showToast(context, title, error: true);

  Future<void> _save() async {
    final kind = _kind;
    final label = _label.text.trim();
    if (kind == null) {
      _error('Choisissez un type de démarche');
      return;
    }
    if (label.isEmpty) {
      _error('Indiquez un nom pour la démarche');
      return;
    }
    final end = _endDate;
    if (end != null && end.compareTo(_startDate) < 0) {
      _error('La date de fin doit suivre la date de début');
      return;
    }

    setState(() => _saving = true);
    try {
      final input = {
        'kind': kind.name,
        'label': label,
        'start_date': _startDate,
        'end_date': end,
        // ordre de la journée, quel que soit l'ordre de sélection
        'periods': [for (final p in ApproachPeriod.values) if (_periods.contains(p)) p.value],
        'comment': quillControllerToHtml(_comment),
      };
      if (_isNew) {
        await repo.addApproach(widget.journalId, input);
      } else {
        await repo.updateApproach(widget.approachId, input);
      }
      if (!mounted) return;
      showToast(context, 'Démarche enregistrée', duration: const Duration(seconds: 2));
      _goBack();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(context,
        title: 'Supprimer cette démarche ?', description: 'Cette action est réversible quelques secondes.', label: 'Supprimer');
    if (!ok || !mounted) return;
    final id = widget.approachId;
    final r = repo;
    await r.deleteApproach(id);
    if (!mounted) return;
    showToast(context, 'Démarche supprimée', actions: [(label: 'Annuler', onPressed: () => r.restoreApproach(id))]);
    _goBack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Retour', onPressed: _goBack),
        title: Text(_isNew ? 'Nouvelle démarche' : 'Démarche', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Démarche introuvable', style: TextStyle(fontWeight: FontWeight.w600)),
            const Text('Elle a peut-être été supprimée.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/journal/${widget.journalId}/demarches'),
              child: const Text('Retour aux démarches'),
            ),
          ],
        ),
      );

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _dateField(String label, String? value, VoidCallback onTap, {String? hint}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, helperText: hint, suffixIcon: const Icon(Icons.event, size: 20)),
          child: Text(value != null ? formatDay(value) : '—'),
        ),
      );

  Widget _form() {
    final original = _original;
    final ongoing = _endDate == null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _heading('Type'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in ApproachKind.values)
              ChoiceChip(
                avatar: Icon(k.icon, size: 18),
                label: Text(k.label),
                selected: _kind == k,
                showCheckmark: false,
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() => _kind = k),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _heading('Nom'),
        TextField(
          controller: _label,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex. Bain avant le coucher, mélatonine 1 mg, psychomotricienne…'),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _dateField('Du', _startDate, () async {
                final d = await _pickDate(_startDate, max: _endDate);
                if (d != null) setState(() => _startDate = d);
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dateField('Au', _endDate, () async {
                final d = await _pickDate(_endDate, min: _startDate);
                if (d != null) setState(() => _endDate = d);
              }, hint: ongoing ? 'En cours' : null),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ongoing
              ? FilledButton.tonalIcon(
                  onPressed: _startDate.compareTo(_today) > 0 ? null : () => setState(() => _endDate = _today),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text("Terminer aujourd'hui"),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                )
              : FilledButton.tonalIcon(
                  onPressed: () => setState(() => _endDate = null),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Toujours en cours (sans date de fin)'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                ),
        ),
        const SizedBox(height: 24),
        _heading('Moment(s) de la journée'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in ApproachPeriod.values)
              FilterChip(
                label: Text(p.label),
                selected: _periods.contains(p),
                shape: const StadiumBorder(),
                onSelected: (on) => setState(() => _periods = on ? [..._periods, p] : _periods.where((x) => x != p).toList()),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _heading('Commentaire'),
        RichTextEditor(controller: _comment, placeholder: 'Dosage, déroulé, conseils du médecin…'),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.edit_note, size: 18, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: original != null
                  ? Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Ajoutée par '),
                        TextSpan(
                          text: authorName(_members, original.createdBy, auth.user!.id),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextSpan(text: ' le ${formatDateTime(original.createdAt)}'),
                      ]),
                      style: const TextStyle(fontSize: 14, color: AppColors.muted),
                    )
                  : const Text('Sera enregistrée à votre nom', style: TextStyle(fontSize: 14, color: AppColors.muted)),
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
