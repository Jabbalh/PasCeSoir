import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/journal_repository.dart';
import 'data/local_db.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'theme.dart';

/// Services de l'application, créés au démarrage
late final SharedPreferences prefs;
late final AuthService auth;
late final SyncService syncService;

/// Données locales de l'utilisateur connecté
JournalRepository get repo {
  final user = auth.user!;
  return JournalRepository(AppDb.forUser(user.id), user, syncService.schedule);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    debugPrint('[Pas ce soir] SUPABASE_URL / SUPABASE_KEY manquants (--dart-define-from-file=env.json)');
  }
  // Sur le web, SQLite tourne en wasm (web/sqlite3.wasm et web/sqflite_sw.js, générés par
  // `dart run sqflite_common_ffi_web:setup`)
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  prefs = await SharedPreferences.getInstance();
  auth = AuthService(Supabase.instance.client, prefs)..init();
  syncService = SyncService(Supabase.instance.client, auth);
  // Synchronisation dès qu'un utilisateur est connecté
  void startSync() {
    if (auth.user != null) syncService.start();
  }
  auth.addListener(startSync);
  startSync();

  runApp(PasCeSoirApp(router: buildRouter(auth)));
}

class PasCeSoirApp extends StatelessWidget {
  const PasCeSoirApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pas ce soir',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: [
        ...GlobalMaterialLocalizations.delegates,
        FlutterQuillLocalizations.delegate,
      ],
    );
  }
}

/// Bouton d'un message (ex. « Annuler »)
typedef ToastAction = ({String label, VoidCallback onPressed});

/// Message bref en bas de l'écran (équivalent des toasts de la PWA)
void showToast(BuildContext context, String title,
    {String? description, bool error = false, List<ToastAction> actions = const [], Duration? duration}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    backgroundColor: error ? AppColors.error : null,
    duration: duration ?? Duration(seconds: description != null || actions.isNotEmpty ? 6 : 4),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (description != null) Text(description),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final a in actions)
                  OutlinedButton(
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      a.onPressed();
                    },
                    child: Text(a.label),
                  ),
              ],
            ),
          ),
      ],
    ),
  ));
}
