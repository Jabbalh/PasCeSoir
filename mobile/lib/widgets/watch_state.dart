import 'dart:async';

import 'package:flutter/widgets.dart';

/// Abonnement d'un écran à des requêtes réactives : chaque nouvelle valeur
/// redessine l'écran ; les abonnements sont coupés à sa fermeture.
mixin WatchState<W extends StatefulWidget> on State<W> {
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// À appeler dans `initState`
  void watch<T>(Stream<T> stream, void Function(T value) onData) {
    _subscriptions.add(stream.listen(
      (value) {
        if (mounted) setState(() => onData(value));
      },
      // ex. base locale fermée par la suppression du compte
      onError: (Object e) => debugPrint('[watch] $e'),
    ));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
