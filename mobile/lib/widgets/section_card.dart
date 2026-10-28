import 'package:flutter/material.dart';

import '../theme.dart';

/// Carte titrée d'une page de réglages (équivalent de UCard avec en-tête)
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.danger = false,
  });

  final String title;
  final String? subtitle;

  /// À droite du titre (bascule, lien…)
  final Widget? trailing;
  final Widget child;

  /// Zone sensible : titre et bordure en rouge
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: danger
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: danger ? AppColors.error : null)),
                ),
                ?trailing,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'information (équivalent de UAlert variant « soft »)
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.title, this.description, this.color = AppColors.warning});

  final IconData icon;
  final String title;
  final String? description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                if (description != null) Text(description!, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
