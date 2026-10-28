import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../data/local_db.dart';

const _adminKey = 'pcs:admin';

/// Utilisateur connecté (réduit à ce dont l'application a besoin)
class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String email;
}

/// Authentification. La session est persistée par supabase_flutter et restaurée
/// au démarrage même hors connexion : l'app reste utilisable si le jeton ne peut
/// pas être rafraîchi.
class AuthService extends ChangeNotifier {
  AuthService(this._supabase, this._prefs);

  final SupabaseClient _supabase;
  final SharedPreferences _prefs;
  StreamSubscription<AuthState>? _sub;

  AppUser? _user;
  AppUser? get user => _user;

  /// Administrateur de l'application (affichage uniquement : les droits sont vérifiés par la base)
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  /// Arrivée par le lien « mot de passe oublié » : l'écran de nouveau mot de passe doit s'ouvrir
  bool _passwordRecovery = false;
  bool get passwordRecovery => _passwordRecovery;

  static AppUser? _fromSession(Session? session) {
    final u = session?.user;
    return u == null ? null : AppUser(id: u.id, email: u.email ?? '');
  }

  void init() {
    _user = _fromSession(_supabase.auth.currentSession);
    if (_user != null) _loadRole(_user!);

    _sub = _supabase.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        _clear();
        return;
      }
      if (state.event == AuthChangeEvent.passwordRecovery) _passwordRecovery = true;
      final u = _fromSession(state.session);
      if (u == null) return;
      final changed = u.id != _user?.id;
      _user = u;
      if (changed || state.event == AuthChangeEvent.signedIn) _loadRole(u);
      notifyListeners();
    });
  }

  /// Charge le rôle admin (hors ligne : dernière valeur connue)
  Future<void> _loadRole(AppUser u) async {
    _isAdmin = _prefs.getString(_adminKey) == u.id;
    notifyListeners();
    try {
      final row = await _supabase.from('app_admins').select('user_id').eq('user_id', u.id).maybeSingle();
      _isAdmin = row != null;
      if (_isAdmin) {
        await _prefs.setString(_adminKey, u.id);
      } else {
        await _prefs.remove(_adminKey);
      }
      notifyListeners();
    } catch (_) {
      // hors ligne : on garde la valeur en cache
    }
  }

  void _clear() {
    _user = null;
    _isAdmin = false;
    _passwordRecovery = false;
    _prefs.remove(_adminKey);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Inscription : réservée aux invitations (lien de partage d'un journal ou invitation
  /// à l'application créée par un admin), contrôle fait côté serveur.
  /// Le jeton d'un journal fait aussi rejoindre ce journal automatiquement.
  /// Retourne `true` si l'email doit encore être confirmé.
  Future<bool> signUp(String email, String password, String displayName,
      {String? journalInvite, String? appInvite}) async {
    final back = journalInvite != null ? '?redirect=${Uri.encodeComponent('/rejoindre/$journalInvite')}' : '';
    final res = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'display_name': displayName,
        'invite_token': ?journalInvite,
        'app_invite': ?appInvite,
      },
      emailRedirectTo: '$webBaseUrl/connexion$back',
    );
    return res.session == null;
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email, redirectTo: '$webBaseUrl/nouveau-mot-de-passe');
  }

  Future<void> updatePassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
    _passwordRecovery = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } finally {
      _clear();
    }
  }

  /// Suppression définitive du compte (côté serveur), puis effacement des données locales.
  /// Les journaux possédés sont supprimés pour tous ; ailleurs, seule l'adhésion disparaît.
  Future<void> deleteAccount() async {
    final userId = _user?.id;
    if (userId == null) return;
    await _supabase.rpc('delete_my_account');
    await signOut();
    await AppDb.delete(userId);
    for (final key in _prefs.getKeys().where((k) => k.startsWith('pcs:'))) {
      await _prefs.remove(key);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
