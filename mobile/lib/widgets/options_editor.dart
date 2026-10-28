import 'package:flutter/material.dart';

import '../data/models.dart';
import '../main.dart';
import '../theme.dart';

/// Gestion des raisons ou des actions d'un journal : ajout, renommage, ordre, retrait / remise
class OptionsEditor extends StatefulWidget {
  const OptionsEditor({
    super.key,
    required this.journalId,
    required this.kind,
    required this.options,
    required this.archived,
    required this.usage,
  });

  final String journalId;
  final OptionKind kind;

  /// Options actives, triées
  final List<JournalOption> options;

  /// Options archivées (tous types)
  final List<JournalOption> archived;

  /// Nombre de réveils utilisant chaque option
  final Map<String, int> usage;

  @override
  State<OptionsEditor> createState() => _OptionsEditorState();
}

class _OptionsEditorState extends State<OptionsEditor> {
  final _newLabel = TextEditingController();
  final _editLabel = TextEditingController();
  String? _editingId;
  var _showArchived = false;

  @override
  void dispose() {
    _newLabel.dispose();
    _editLabel.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final label = _newLabel.text.trim();
    if (label.isEmpty) return;
    await repo.addOption(widget.journalId, widget.kind, label);
    _newLabel.clear();
    setState(() {});
  }

  void _startEdit(JournalOption o) {
    setState(() => _editingId = o.id);
    _editLabel.text = o.label;
  }

  Future<void> _commitEdit(JournalOption o) async {
    final label = _editLabel.text.trim();
    setState(() => _editingId = null);
    if (label.isEmpty || label == o.label) return;
    final duplicate = widget.options.any((x) => x.id != o.id && x.label.toLowerCase() == label.toLowerCase());
    if (duplicate) {
      showToast(context, 'Ce libellé existe déjà');
      return;
    }
    await repo.updateOption(o.id, {'label': label});
  }

  Future<void> _move(int index, int delta) async {
    final list = [...widget.options];
    final target = index + delta;
    if (target < 0 || target >= list.length) return;
    final tmp = list[index];
    list[index] = list[target];
    list[target] = tmp;
    await repo.reorderOptions(list);
  }

  Future<void> _archive(JournalOption o) async {
    final r = repo;
    await r.updateOption(o.id, {'deleted_at': DateTime.now().toUtc().toIso8601String()});
    if (!mounted) return;
    showToast(
      context,
      '« ${o.label} » retiré de la liste',
      description: 'Les réveils existants le conservent.',
      actions: [(label: 'Annuler', onPressed: () => r.updateOption(o.id, {'deleted_at': null}))],
    );
  }

  /// Remise en fin de liste
  Future<void> _restore(JournalOption o) async {
    final last = widget.options.fold(0, (max, x) => x.position > max ? x.position : max);
    await repo.updateOption(o.id, {'deleted_at': null, 'position': last + 1});
  }

  @override
  Widget build(BuildContext context) {
    final archived = widget.archived.where((o) => o.kind == widget.kind).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
          child: widget.options.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Aucun élément. Ajoutez-en ci-dessous.', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                )
              : Column(
                  children: [
                    for (final (i, o) in widget.options.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      _row(i, o),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newLabel,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.kind == OptionKind.reason ? 'Nouvelle raison…' : 'Nouvelle action…',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _newLabel.text.trim().isEmpty ? null : _add,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
        ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showArchived = !_showArchived),
              icon: Icon(_showArchived ? Icons.expand_more : Icons.chevron_right, size: 18),
              label: Text('${archived.length} élément(s) retiré(s)'),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            ),
          ),
          if (_showArchived)
            for (final o in archived)
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      o.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.muted, decoration: TextDecoration.lineThrough),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _restore(o),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Remettre'),
                  ),
                ],
              ),
        ],
      ],
    );
  }

  Widget _row(int i, JournalOption o) {
    final used = widget.usage[o.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          Expanded(
            child: _editingId == o.id
                ? Focus(
                    onFocusChange: (focused) {
                      if (!focused) _commitEdit(o);
                    },
                    child: TextField(
                      controller: _editLabel,
                      autofocus: true,
                      decoration: const InputDecoration(isDense: true),
                      onSubmitted: (_) => _commitEdit(o),
                    ),
                  )
                : InkWell(
                    onTap: () => _startEdit(o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Flexible(child: Text(o.label, overflow: TextOverflow.ellipsis)),
                          if (used > 0) Text(' · $used', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          if (o.dirty) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.cloud_upload_outlined, size: 12, color: AppColors.warning),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            tooltip: 'Monter',
            visualDensity: VisualDensity.compact,
            onPressed: i == 0 ? null : () => _move(i, -1),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            tooltip: 'Descendre',
            visualDensity: VisualDensity.compact,
            onPressed: i == widget.options.length - 1 ? null : () => _move(i, 1),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppColors.error),
            tooltip: 'Retirer de la liste',
            visualDensity: VisualDensity.compact,
            onPressed: () => _archive(o),
          ),
        ],
      ),
    );
  }
}
