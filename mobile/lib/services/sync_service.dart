import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local_db.dart';
import '../data/models.dart';
import '../utils/errors.dart';
import 'auth_service.dart';

/// Table synchronisée par lots : table distante, champs envoyés, préfixe du curseur de lecture
class _RowTable {
  const _RowTable(this.remote, this.fields, this.cursor);

  final String remote;
  final List<String> fields;
  final String cursor;
}

/// ⚠️ Ajouter un champ ici **après** avoir appliqué la migration serveur (sinon colonne inconnue)
const _rowTables = {
  'options': _RowTable('journal_options', ['id', 'journal_id', 'kind', 'label', 'position', 'created_at', 'deleted_at'], 'ocursor'),
  'wakeups': _RowTable('wakeups', ['id', 'journal_id', 'woke_at', 'wake_type', 'reason_ids', 'action_ids', 'comment', 'created_by', 'created_at', 'deleted_at'], 'cursor'),
  'approaches': _RowTable('approaches', ['id', 'journal_id', 'kind', 'label', 'start_date', 'end_date', 'periods', 'comment', 'created_by', 'created_at', 'deleted_at'], 'acursor'),
};

/// Curseurs de lecture d'un journal (à effacer avec lui)
Iterable<String> _cursorKeys(String journalId) => _rowTables.values.map((t) => '${t.cursor}:$journalId');

/// Marge de recouvrement pour ne rater aucune ligne commitée en retard
const _cursorOverlap = Duration(seconds: 60);
const _pageSize = 500;
const _batchSize = 100;

bool _isPermissionError(PostgrestException e) => e.code == '42501' || e.code == 'PGRST301';

/// Synchronisation bidirectionnelle SQLite <-> Supabase.
/// - Toute écriture est d'abord locale (marquée `_dirty`), puis poussée.
/// - Les changements distants sont tirés par journal grâce à `updated_at` (horodaté par le serveur).
/// - Conflits : la dernière écriture envoyée l'emporte ; une modif locale non envoyée n'est jamais écrasée.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService(this._supabase, this._auth);

  final SupabaseClient _supabase;
  final AuthService _auth;

  bool online = true;
  bool syncing = false;
  DateTime? lastSyncAt;
  String? lastError;
  int pendingCount = 0;

  bool _started = false;
  bool _foreground = true;
  Future<void>? _running;
  bool _rerun = false;
  Timer? _debounce;

  /// Déclencheurs : démarrage, retour du réseau, retour au premier plan, toutes les 30 s
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    final connectivity = Connectivity();
    online = !(await connectivity.checkConnectivity()).contains(ConnectivityResult.none);
    connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = online;
      online = !results.contains(ConnectivityResult.none);
      notifyListeners();
      if (online && !wasOnline) sync();
    });
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground) sync();
    });
    sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) sync();
  }

  /// À appeler après chaque écriture locale
  void schedule([Duration? delay]) {
    refreshPending();
    _debounce?.cancel();
    _debounce = Timer(delay ?? const Duration(milliseconds: 800), sync);
  }

  /// Lance une synchro (les appels concurrents sont fusionnés)
  Future<void> sync() {
    if (_running != null) {
      _rerun = true;
      return _running!;
    }
    return _running = () async {
      try {
        do {
          _rerun = false;
          await _doSync();
        } while (_rerun);
      } finally {
        _running = null;
      }
    }();
  }

  Future<void> refreshPending() async {
    final user = _auth.user;
    if (user == null) return;
    final db = AppDb.forUser(user.id);
    var count = 0;
    for (final table in syncTables) {
      count += await db.read((t) => t.countDirty(table));
    }
    pendingCount = count;
    notifyListeners();
  }

  Future<void> _doSync() async {
    final user = _auth.user;
    if (user == null || !online || _supabase.auth.currentSession == null) return;
    final db = AppDb.forUser(user.id);
    syncing = true;
    notifyListeners();
    try {
      await _pushJournals(db, user.id);
      for (final table in _rowTables.keys) {
        await _pushRows(db, table);
      }
      // Les réveils et démarches supprimés et confirmés par le serveur ne sont plus utiles localement
      await db.write((t) async {
        await t.deleteWhere('wakeups', 'deleted = 1 and _dirty = 0', []);
        await t.deleteWhere('approaches', 'deleted = 1 and _dirty = 0', []);
      });
      final journalIds = await _pullJournals(db);
      for (final id in journalIds) {
        for (final table in _rowTables.keys) {
          await _pullRows(db, table, id);
        }
      }
      lastSyncAt = DateTime.now();
      lastError = null;
    } catch (e, st) {
      lastError = errorMessage(e);
      debugPrint('[sync] $e\n$st');
    } finally {
      syncing = false;
      await refreshPending();
    }
  }

  /// Retire le marqueur « à envoyer » sauf si la ligne a encore été modifiée pendant l'envoi
  Future<void> _markClean(AppDb db, String table, List<Map<String, dynamic>> rows) => db.write((t) async {
        for (final row in rows) {
          final current = await t.get(table, row['id'] as String);
          if (current != null && current['_lmod'] == row['_lmod']) await t.put(table, {...current, '_dirty': 0});
        }
      });

  Future<void> _pushJournals(AppDb db, String userId) async {
    final dirty = await db.read((t) => t.dirty('journals'));
    if (dirty.isEmpty) return;
    final members = (await db.read((t) => t.query('members'))).map(Member.new).toList();
    for (final row in dirty) {
      final j = Journal(row);
      final isOwner = j.createdBy == userId || members.any((m) => m.journalId == j.id && m.userId == userId && m.isOwner);
      final payload = {
        'id': j.id,
        'name': j.name,
        'child_name': j.childName,
        'created_by': j.createdBy,
        'created_at': row['created_at'],
        // Seul le propriétaire peut supprimer : on n'envoie pas ce champ sinon (refus serveur)
        if (isOwner) 'deleted_at': row['deleted_at'],
      };
      try {
        await _supabase.from('journals').upsert(payload);
      } on PostgrestException catch (e) {
        if (!_isPermissionError(e)) rethrow;
        debugPrint('[sync] journal refusé ${j.id} ${e.message}');
      }
      await _markClean(db, 'journals', [row]);
    }
  }

  /// Envoie les lignes modifiées localement (réveils, options ou démarches) par lots
  Future<void> _pushRows(AppDb db, String table) async {
    final config = _rowTables[table]!;
    Map<String, dynamic> toPayload(Map<String, dynamic> row) => {for (final f in config.fields) f: row[f]};

    final dirty = await db.read((t) => t.dirty(table));
    for (var i = 0; i < dirty.length; i += _batchSize) {
      final batch = dirty.sublist(i, i + _batchSize > dirty.length ? dirty.length : i + _batchSize);
      try {
        await _supabase.from(config.remote).upsert(batch.map(toPayload).toList());
        await _markClean(db, table, batch);
        continue;
      } on PostgrestException catch (e) {
        if (!_isPermissionError(e)) rethrow;
      }
      // Lot refusé : on isole la ou les lignes fautives (journal quitté, etc.)
      for (final row in batch) {
        try {
          await _supabase.from(config.remote).upsert(toPayload(row));
        } on PostgrestException catch (e) {
          if (!_isPermissionError(e)) rethrow;
          debugPrint('[sync] ${config.remote} refusé ${row['id']} ${e.message}');
        }
        await _markClean(db, table, [row]);
      }
    }
  }

  /// Tire journaux et membres ; retourne les identifiants des journaux actifs
  Future<List<String>> _pullJournals(AppDb db) async {
    final journals = await _supabase.from('journals').select();
    final members = await _supabase.from('journal_members').select('journal_id, user_id, role, profiles(display_name)');
    final remoteIds = journals.map((j) => j['id'] as String).toSet();

    await db.write((t) async {
      Future<void> purgeJournal(String id) async {
        await t.delete('journals', id);
        for (final table in _rowTables.keys) {
          await t.deleteWhere(table, 'journal_id = ?', [id]);
        }
        await t.deleteMeta(_cursorKeys(id));
      }

      for (final j in journals) {
        final id = j['id'] as String;
        final local = await t.get('journals', id);
        if (local?['_dirty'] == 1) continue;
        if (j['deleted_at'] != null) {
          await purgeJournal(id);
          continue;
        }
        await t.put('journals', {...j, '_dirty': 0, '_lmod': local?['_lmod'] ?? 0});
      }
      // Journaux dont on n'est plus membre (et qui ne sont pas en attente de création)
      final locals = await t.query('journals');
      for (final l in locals) {
        if (!remoteIds.contains(l['id']) && l['_dirty'] != 1) await purgeJournal(l['id'] as String);
      }
      // On garde les membres des journaux pas encore envoyés au serveur
      final pendingIds = [
        for (final l in locals)
          if (l['_dirty'] == 1 && !remoteIds.contains(l['id'])) l['id'] as String
      ];
      await t.deleteWhere(
          'members',
          pendingIds.isEmpty ? '1 = 1' : 'journal_id not in (${List.filled(pendingIds.length, '?').join(', ')})',
          pendingIds);
      for (final m in members) {
        final profile = m['profiles'] as Map<String, dynamic>?;
        await t.put('members', {
          'key': '${m['journal_id']}:${m['user_id']}',
          'journal_id': m['journal_id'],
          'user_id': m['user_id'],
          'role': m['role'],
          'display_name': profile?['display_name'] ?? '?',
        });
      }
    });
    return [
      for (final j in journals)
        if (j['deleted_at'] == null) j['id'] as String
    ];
  }

  /// Tire les changements distants d'un journal (réveils, options ou démarches) depuis le dernier curseur.
  /// Les réveils et démarches supprimés sont effacés localement ; les options archivées sont conservées
  /// (leur libellé reste affiché sur les anciens réveils).
  Future<void> _pullRows(AppDb db, String table, String journalId) async {
    final config = _rowTables[table]!;
    final cursorKey = '${config.cursor}:$journalId';
    var cursor = DateTime.parse(await db.read((t) => t.getMeta(cursorKey)) ?? '1970-01-01T00:00:00Z');
    final since = cursor.subtract(_cursorOverlap).toUtc().toIso8601String();
    var from = 0;
    while (true) {
      final data = await _supabase
          .from(config.remote)
          .select()
          .eq('journal_id', journalId)
          .gt('updated_at', since)
          .order('updated_at', ascending: true)
          .order('id', ascending: true)
          .range(from, from + _pageSize - 1);
      if (data.isEmpty) break;

      await db.write((t) async {
        for (final row in data) {
          final id = row['id'] as String;
          final local = await t.get(table, id);
          if (local?['_dirty'] == 1) continue;
          if (row['deleted_at'] != null && table != 'options') {
            await t.delete(table, id);
          } else {
            await t.put(table, {
              ...row,
              if (table == 'wakeups') ...{
                'reason_ids': row['reason_ids'] ?? <String>[],
                'action_ids': row['action_ids'] ?? <String>[],
              },
              '_dirty': 0,
              '_lmod': local?['_lmod'] ?? 0,
            });
          }
        }
      });
      final last = DateTime.parse(data.last['updated_at'] as String);
      if (last.isAfter(cursor)) cursor = last;
      if (data.length < _pageSize) break;
      from += _pageSize;
    }
    await db.write((t) => t.setMeta(cursorKey, cursor.toUtc().toIso8601String()));
  }
}
