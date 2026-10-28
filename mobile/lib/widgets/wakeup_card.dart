import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../theme.dart';
import '../utils/night.dart';
import '../utils/rich_text.dart';

/// Carte d'un réveil dans la liste ; un appui ouvre le détail
class WakeupCard extends StatelessWidget {
  const WakeupCard({super.key, required this.wakeup, required this.author, required this.labelOf});

  final Wakeup wakeup;
  final String author;
  final String Function(String id) labelOf;

  /// « À compléter » = ni raison, ni action, ni commentaire
  bool get _incomplete => wakeup.reasonIds.isEmpty && wakeup.actionIds.isEmpty && wakeup.comment.isEmpty;

  @override
  Widget build(BuildContext context) {
    final type = wakeup.wakeType;
    final comment = htmlToPlainText(wakeup.comment);
    final radius = BorderRadius.circular(12);

    return Material(
      color: AppColors.surface.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: _incomplete ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.push('/journal/${wakeup.journalId}/reveil/${wakeup.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    formatTime(wakeup.wokeAt),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (type != null)
                          Row(children: [
                            Icon(type.icon, size: 14),
                            const SizedBox(width: 4),
                            Text(type.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ]),
                        Row(children: [
                          const Icon(Icons.person_outline, size: 12, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(author,
                                style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                          ),
                          if (wakeup.dirty) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.cloud_upload_outlined, size: 12, color: AppColors.warning),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  if (_incomplete)
                    const _Badge(label: 'À compléter', color: AppColors.primary, icon: Icons.edit_outlined)
                  else
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              if (wakeup.reasonIds.isNotEmpty || wakeup.actionIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in wakeup.reasonIds) _Badge(label: labelOf(r), color: AppColors.warning),
                    for (final a in wakeup.actionIds)
                      _Badge(label: labelOf(a), color: AppColors.success, icon: Icons.volunteer_activism_outlined),
                  ],
                ),
              ],
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille colorée (équivalent de UBadge variant « subtle »)
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
