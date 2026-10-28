import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../theme.dart';
import 'sync_status.dart';

/// En-tête commun : logo (retour aux journaux), état de la synchro, menu utilisateur
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  Future<void> _logout(BuildContext context) async {
    final pending = syncService.pendingCount;
    if (pending > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: Text("$pending modification(s) n'ont pas encore été synchronisées. Se déconnecter quand même ?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await auth.signOut();
    if (!context.mounted) return;
    showToast(context, 'Déconnecté');
    context.go('/connexion');
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: InkWell(
        onTap: () => context.go('/'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/icon.svg', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text('Pas ce soir', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: [
        const SyncStatus(),
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle_outlined),
          tooltip: 'Menu utilisateur',
          onSelected: (v) {
            switch (v) {
              case 'logout':
                _logout(context);
              case final path:
                context.go(path);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(enabled: false, child: Text(auth.user?.email ?? '')),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: '/',
              child: ListTile(
                leading: Icon(Icons.menu_book_outlined),
                title: Text('Mes journaux'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: '/profil',
              child: ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('Mon profil'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (auth.isAdmin)
              const PopupMenuItem(
                value: '/admin',
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Administration'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: AppColors.error),
                title: Text('Se déconnecter', style: TextStyle(color: AppColors.error)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
    );
  }
}
