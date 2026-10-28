import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Tables synchronisées avec Supabase (nom local)
const syncTables = ['journals', 'options', 'wakeups', 'approaches'];

/// Base SQLite locale, une par utilisateur (`pascesoir-<userId>.db`) : pas de mélange entre comptes.
///
/// Chaque ligne est stockée telle quelle en JSON (colonne `data`) ; seules les colonnes
/// utiles aux requêtes en sont extraites. Ajouter un champ ne demande donc pas de
/// migration locale : il suffit de tolérer son absence sur les lignes existantes.
class AppDb {
  AppDb._(this.userId);

  factory AppDb.forUser(String userId) => _instances.putIfAbsent(userId, () => AppDb._(userId));

  static final _instances = <String, AppDb>{};

  final String userId;
  late final Future<Database> _db = _open();
  final _changes = StreamController<Set<String>>.broadcast();

  static Future<String> _path(String userId) async => p.join(await getDatabasesPath(), 'pascesoir-$userId.db');

  Future<Database> _open() async => openDatabase(
        await _path(userId),
        version: 1,
        onCreate: (db, version) async {
          final batch = db.batch()
            ..execute('create table journals (id text primary key, _dirty integer not null, deleted integer not null, data text not null)')
            ..execute('create table options (id text primary key, journal_id text not null, _dirty integer not null, deleted integer not null, data text not null)')
            ..execute('create table wakeups (id text primary key, journal_id text not null, woke_at integer not null, _dirty integer not null, deleted integer not null, data text not null)')
            ..execute('create table approaches (id text primary key, journal_id text not null, _dirty integer not null, deleted integer not null, data text not null)')
            ..execute('create table members (key text primary key, journal_id text not null, data text not null)')
            ..execute('create table meta (key text primary key, value text not null)');
          for (final t in syncTables) {
            batch.execute('create index ${t}_dirty on $t (_dirty)');
          }
          batch
            ..execute('create index options_journal on options (journal_id)')
            ..execute('create index wakeups_journal on wakeups (journal_id, woke_at)')
            ..execute('create index approaches_journal on approaches (journal_id)')
            ..execute('create index members_journal on members (journal_id)');
          await batch.commit(noResult: true);
        },
      );

  /// Lecture hors transaction
  Future<T> read<T>(Future<T> Function(DbTxn t) fn) async => fn(DbTxn(await _db, {}));

  /// Écriture dans une transaction ; les requêtes observées sont relancées après validation
  Future<T> write<T>(Future<T> Function(DbTxn t) fn) async {
    final touched = <String>{};
    final result = await (await _db).transaction((txn) => fn(DbTxn(txn, touched)));
    if (touched.isNotEmpty && !_changes.isClosed) _changes.add(touched);
    return result;
  }

  /// Requête réactive (équivalent du `liveQuery` de Dexie) : émet le résultat, puis le
  /// recalcule après chaque écriture touchant l'une des [tables] (y compris par la synchro).
  /// À créer une seule fois par écran (ex. dans `initState`), pas dans `build`.
  Stream<T> watch<T>(Set<String> tables, Future<T> Function(DbTxn t) query) {
    late final StreamController<T> controller;
    StreamSubscription<Set<String>>? sub;
    var running = false;
    var rerun = false;

    Future<void> run() async {
      if (running) {
        rerun = true;
        return;
      }
      running = true;
      try {
        do {
          rerun = false;
          final value = await read(query);
          if (!controller.isClosed) controller.add(value);
        } while (rerun);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      } finally {
        running = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        sub = _changes.stream.where((t) => t.any(tables.contains)).listen((_) => run());
        run();
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Supprime définitivement la base locale d'un utilisateur
  static Future<void> delete(String userId) async {
    final instance = _instances.remove(userId);
    if (instance != null) {
      await (await instance._db).close();
      await instance._changes.close();
    }
    await deleteDatabase(await _path(userId));
  }
}

/// Opérations sur la base, dans une transaction ([AppDb.write]) ou non ([AppDb.read])
class DbTxn {
  DbTxn(this._ex, this._touched);

  final DatabaseExecutor _ex;
  final Set<String> _touched;

  static String _keyColumn(String table) => table == 'members' ? 'key' : 'id';

  static Map<String, dynamic> _decode(Map<String, Object?> row) =>
      jsonDecode(row['data'] as String) as Map<String, dynamic>;

  static Map<String, Object?> _columns(String table, Map<String, dynamic> row) => {
        _keyColumn(table): row[_keyColumn(table)],
        if (table != 'journals') 'journal_id': row['journal_id'],
        if (table == 'wakeups') 'woke_at': DateTime.parse(row['woke_at'] as String).microsecondsSinceEpoch,
        if (table != 'members') '_dirty': row['_dirty'] ?? 0,
        if (table != 'members') 'deleted': row['deleted_at'] != null ? 1 : 0,
        'data': jsonEncode(row),
      };

  Future<Map<String, dynamic>?> get(String table, String id) async {
    final rows = await _ex.query(table, columns: ['data'], where: '${_keyColumn(table)} = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _decode(rows.first);
  }

  Future<List<Map<String, dynamic>>> query(String table,
          {String? where, List<Object?>? whereArgs, String? orderBy}) async =>
      (await _ex.query(table, columns: ['data'], where: where, whereArgs: whereArgs, orderBy: orderBy))
          .map(_decode)
          .toList();

  /// Lignes d'un journal ; [withDeleted] inclut les lignes supprimées / archivées
  /// (sans effet sur `members`, qui n'a pas de colonne `deleted`)
  Future<List<Map<String, dynamic>>> byJournal(String table, String journalId,
          {bool withDeleted = false, String? orderBy}) =>
      query(table,
          where: withDeleted || table == 'members' ? 'journal_id = ?' : 'journal_id = ? and deleted = 0',
          whereArgs: [journalId],
          orderBy: orderBy);

  Future<List<Map<String, dynamic>>> dirty(String table) => query(table, where: '_dirty = 1');

  Future<int> countDirty(String table) async =>
      Sqflite.firstIntValue(await _ex.rawQuery('select count(*) from $table where _dirty = 1')) ?? 0;

  Future<void> put(String table, Map<String, dynamic> row) async {
    await _ex.insert(table, _columns(table, row), conflictAlgorithm: ConflictAlgorithm.replace);
    _touched.add(table);
  }

  /// Fusionne [patch] dans la ligne ; retourne `false` si elle n'existe pas
  Future<bool> patch(String table, String id, Map<String, dynamic> patch) async {
    final row = await get(table, id);
    if (row == null) return false;
    await put(table, {...row, ...patch});
    return true;
  }

  Future<void> delete(String table, String id) => deleteWhere(table, '${_keyColumn(table)} = ?', [id]);

  Future<void> deleteWhere(String table, String where, List<Object?> whereArgs) async {
    if (await _ex.delete(table, where: where, whereArgs: whereArgs) > 0) _touched.add(table);
  }

  Future<String?> getMeta(String key) async {
    final rows = await _ex.query('meta', columns: ['value'], where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) =>
      _ex.insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteMeta(Iterable<String> keys) async {
    for (final key in keys) {
      await _ex.delete('meta', where: 'key = ?', whereArgs: [key]);
    }
  }
}
