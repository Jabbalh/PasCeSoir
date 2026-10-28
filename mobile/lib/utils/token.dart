import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Jeton aléatoire URL-safe (144 bits) pour les liens d'invitation
String randomToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(18, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Feuille de partage Android (le lien peut aussi y être copié)
Future<void> shareLink(String url, String text) =>
    SharePlus.instance.share(ShareParams(text: '$text\n$url', subject: 'Pas ce soir'));

Future<void> copyText(String text) => Clipboard.setData(ClipboardData(text: text));
