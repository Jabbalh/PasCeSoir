import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../theme.dart';
import '../utils/approach.dart';
import '../utils/rich_text.dart';

/// Carte d'une démarche dans la liste ; un appui ouvre le détail
class ApproachCard extends StatelessWidget {
  const ApproachCard({super.key, required this.approach, required this.today});

  final Approach approach;
  final String today;

  @override
  Widget build(BuildContext context) {
    final kind = approach.kind;
    final comment = htmlToPlainText(approach.comment);
    final finished = approachStatus(approach, today) == ApproachStatus.terminee;
    final radius = BorderRadius.circular(12);

    return Opacity(
      opacity: finished ? 0.7 : 1,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push('/journal/${approach.journalId}/demarches/${approach.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: kind.color.withValues(alpha: 0.15),
                      child: Icon(kind.icon, size: 20, color: kind.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(approach.label,
                              style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          Row(children: [
                            Flexible(
                              child: Text(
                                '${kind.label} · ${approachDates(approach, today)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ),
                            if (approach.dirty) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.cloud_upload_outlined, size: 12, color: AppColors.warning),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
                if (approach.periods.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in ApproachPeriod.values.where(approach.periods.contains))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.schedule, size: 12, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(p.label, style: const TextStyle(fontSize: 12)),
                          ]),
                        ),
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
      ),
    );
  }
}
