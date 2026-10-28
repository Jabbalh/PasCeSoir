import 'package:flutter/material.dart';

import '../theme.dart';

/// Demande de confirmation d'une action sensible ; `true` si confirmée
Future<bool> confirmAction(BuildContext context,
    {required String title, String? description, required String label, bool destructive = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: description != null ? Text(description) : null,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive ? TextButton.styleFrom(foregroundColor: AppColors.error) : null,
          child: Text(label),
        ),
      ],
    ),
  );
  return ok == true;
}
