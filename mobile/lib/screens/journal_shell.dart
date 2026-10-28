import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/app_header.dart';

/// Cadre des écrans d'un journal : en-tête + navigation du bas (Réveils, Démarches, Stats, Réglages)
class JournalShell extends StatelessWidget {
  const JournalShell({super.key, required this.journalId, required this.location, required this.child});

  final String journalId;
  final String location;
  final Widget child;

  static const _tabs = [
    (path: '', label: 'Réveils', icon: Icons.nights_stay_outlined),
    (path: '/demarches', label: 'Démarches', icon: Icons.checklist),
    (path: '/stats', label: 'Stats', icon: Icons.bar_chart),
    (path: '/reglages', label: 'Réglages', icon: Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final base = '/journal/$journalId';
    final index = _tabs.lastIndexWhere((t) => t.path.isEmpty ? location == base : location.startsWith('$base${t.path}'));

    return Scaffold(
      appBar: const AppHeader(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        onDestinationSelected: (i) => context.go('$base${_tabs[i].path}'),
        destinations: [
          for (final t in _tabs) NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}

/// Écran pas encore porté
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title, required this.step});

  final String title;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_outlined, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('À venir (étape $step de la migration)', style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
