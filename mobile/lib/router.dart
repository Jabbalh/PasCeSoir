import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/admin_screen.dart';
import 'screens/approach_screen.dart';
import 'screens/approaches_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/journal_shell.dart';
import 'screens/login_screen.dart';
import 'screens/new_password_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/wakeup_screen.dart';
import 'services/auth_service.dart';

const _publicRoutes = ['/connexion', '/nouveau-mot-de-passe'];

final _rootNavigator = GlobalKey<NavigatorState>();

/// Routes de l'application, mêmes chemins que la PWA (utile pour les liens profonds)
GoRouter buildRouter(AuthService auth) => GoRouter(
      navigatorKey: _rootNavigator,
      refreshListenable: auth,
      redirect: (context, state) {
        final path = state.uri.path;
        final isPublic = _publicRoutes.contains(path) || path.startsWith('/inscription/');

        if (auth.passwordRecovery && path != '/nouveau-mot-de-passe') return '/nouveau-mot-de-passe';
        if (auth.user == null && !isPublic) {
          final target = state.uri.toString();
          return Uri(path: '/connexion', queryParameters: target != '/' ? {'redirect': target} : null).toString();
        }
        if (auth.user != null && path == '/connexion') {
          final redirect = state.uri.queryParameters['redirect'];
          return redirect != null && redirect.startsWith('/') ? redirect : '/';
        }
        if (path.startsWith('/admin') && !auth.isAdmin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/connexion',
          builder: (context, state) => LoginScreen(redirect: state.uri.queryParameters['redirect']),
        ),
        GoRoute(path: '/nouveau-mot-de-passe', builder: (context, state) => const NewPasswordScreen()),
        GoRoute(
          path: '/inscription/:token',
          builder: (context, state) => SignupScreen(token: state.pathParameters['token']!),
        ),
        GoRoute(
          path: '/rejoindre/:token',
          builder: (context, state) => JoinScreen(token: state.pathParameters['token']!),
        ),
        GoRoute(path: '/profil', builder: (context, state) => const ProfileScreen()),
        GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
        // Écrans d'un journal, avec la navigation du bas
        ShellRoute(
          builder: (context, state, child) => JournalShell(
            journalId: state.pathParameters['id']!,
            location: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/journal/:id',
              builder: (context, state) => JournalScreen(
                key: ValueKey(state.pathParameters['id']),
                journalId: state.pathParameters['id']!,
              ),
              routes: [
                // Formulaire de réveil : plein écran, au-dessus de la navigation du bas
                GoRoute(
                  path: 'reveil/:wid',
                  parentNavigatorKey: _rootNavigator,
                  builder: (context, state) => WakeupScreen(
                    journalId: state.pathParameters['id']!,
                    wakeupId: state.pathParameters['wid']!,
                  ),
                ),
                GoRoute(
                  path: 'demarches',
                  builder: (context, state) => ApproachesScreen(journalId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: ':aid',
                      parentNavigatorKey: _rootNavigator,
                      builder: (context, state) => ApproachScreen(
                        journalId: state.pathParameters['id']!,
                        approachId: state.pathParameters['aid']!,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'stats',
                  builder: (context, state) => StatsScreen(journalId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'reglages',
                  builder: (context, state) => SettingsScreen(journalId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ],
    );
