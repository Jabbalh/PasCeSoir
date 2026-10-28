import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme.dart';

/// Choix multiple parmi les options d'un journal, avec création d'une nouvelle option
class TagPicker extends StatefulWidget {
  const TagPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    required this.create,
    this.color = AppColors.primary,
    this.placeholder = 'Autre…',
  });

  /// Options actives du journal
  final List<JournalOption> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Libellé d'un identifiant (pour les options archivées encore sélectionnées)
  final String Function(String id) labelOf;

  /// Crée une nouvelle option dans le journal et renvoie son identifiant
  final Future<String> Function(String label) create;
  final Color color;
  final String placeholder;

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    final s = widget.selected;
    widget.onChanged(s.contains(id) ? s.where((v) => v != id).toList() : [...s, id]);
  }

  Future<void> _addCustom() async {
    final label = _custom.text.trim();
    if (label.isEmpty) return;
    final id = await widget.create(label);
    if (!widget.selected.contains(id)) widget.onChanged([...widget.selected, id]);
    _custom.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Options actives + options archivées encore sélectionnées sur ce réveil
    final all = [
      for (final o in widget.options) (id: o.id, label: o.label),
      for (final id in widget.selected)
        if (!widget.options.any((o) => o.id == id)) (id: id, label: widget.labelOf(id)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (all.isEmpty)
          const Text(
            "Liste vide pour l'instant : saisissez un premier choix ci-dessous, il sera proposé les prochaines fois.",
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in all)
                FilterChip(
                  label: Text(o.label),
                  selected: widget.selected.contains(o.id),
                  onSelected: (_) => _toggle(o.id),
                  selectedColor: widget.color,
                  checkmarkColor: Colors.black,
                  labelStyle: widget.selected.contains(o.id) ? const TextStyle(color: Colors.black) : null,
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _custom,
                decoration: InputDecoration(hintText: widget.placeholder, isDense: true),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _custom.text.trim().isEmpty ? null : _addCustom,
              icon: const Icon(Icons.add),
              tooltip: 'Ajouter',
            ),
          ],
        ),
      ],
    );
  }
}
