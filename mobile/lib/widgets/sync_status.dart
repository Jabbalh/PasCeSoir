import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

/// Indicateur de synchronisation (en-tête) ; un appui relance la synchro
class SyncStatus extends StatelessWidget {
  const SyncStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: syncService,
      builder: (context, _) {
        final s = syncService;
        final (icon, color, label) = !s.online
            ? (Icons.cloud_off_outlined, AppColors.warning, 'Hors ligne')
            : s.syncing
                ? (Icons.sync, AppColors.muted, 'Synchro…')
                : s.lastError != null
                    ? (Icons.cloud_off, AppColors.error, 'Erreur')
                    : s.pendingCount > 0
                        ? (Icons.cloud_upload_outlined, AppColors.warning, 'En attente')
                        : (Icons.cloud_done_outlined, AppColors.success, 'À jour');

        final details = [
          if (s.pendingCount > 0) '${s.pendingCount} modification(s) à envoyer',
          ?s.lastError,
          if (s.lastSyncAt != null) 'Dernière synchro : ${TimeOfDay.fromDateTime(s.lastSyncAt!).format(context)}',
        ];

        return Tooltip(
          message: details.isEmpty ? label : details.join(' · '),
          triggerMode: TooltipTriggerMode.longPress,
          child: TextButton.icon(
            onPressed: syncService.sync,
            icon: Icon(icon, color: color, size: 20),
            label: Text(s.pendingCount > 0 && !s.syncing ? '${s.pendingCount}' : '', style: TextStyle(color: color)),
            style: TextButton.styleFrom(minimumSize: const Size(40, 40), padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        );
      },
    );
  }
}
