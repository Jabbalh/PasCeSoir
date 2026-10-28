import 'package:uuid/uuid.dart';

import '../services/auth_service.dart';
import 'local_db.dart';
import 'models.dart';

const _uuid = Uuid();

String _nowIso() => DateTime.now().toUtc().toIso8601String();

/// Marque une modification locale à envoyer
Map<String, dynamic> _dirty(Map<String, dynamic> patch) =>
    {...patch, '_dirty': 1, '_lmod': DateTime.now().millisecondsSinceEpoch};

int _compareText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// Données d'un utilisateur : toute écriture est locale (marquée `_dirty`), puis la
/// synchronisation est planifiée. Les requêtes `watch…` sont réactives.
class JournalRepository {
  JournalRepository(this.db, this.user, this._schedule);

  final AppDb db;
  final AppUser user;

  /// Planifie une synchronisation (délai par défaut si `null`)
  final void Function([Duration? delay]) _schedule;

  // --- Journaux ---

  Future<Journal> createJournal({required String name, required String childName}) async {
    final now = _nowIso();
    final journal = _dirty({
      'id': _uuid.v4(),
      'name': name.trim(),
      'child_name': childName.trim(),
      'created_by': user.id,
      'share_token': null,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
    // Aucune raison ni action par défaut : chaque journal construit ses propres listes
    await db.write((t) async {
      await t.put('journals', journal);
      await t.put('members', {
        'key': '${journal['id']}:${user.id}',
        'journal_id': journal['id'],
        'user_id': user.id,
        'role': 'owner',
        'display_name': user.email.split('@').first,
      });
    });
    _schedule(Duration.zero);
    return Journal(journal);
  }

  /// [patch] : `name`, `child_name`, `deleted_at`
  Future<void> updateJournal(String id, Map<String, dynamic> patch) async {
    await db.write((t) => t.patch('journals', id, _dirty(patch)));
    _schedule(Duration.zero);
  }

  // --- Réveils ---

  Future<Wakeup> addWakeup(String journalId, [DateTime? wokeAt]) async {
    final now = _nowIso();
    final wakeup = _dirty({
      'id': _uuid.v4(),
      'journal_id': journalId,
      'woke_at': (wokeAt ?? DateTime.now()).toUtc().toIso8601String(),
      'wake_type': null,
      'reason_ids': <String>[],
      'action_ids': <String>[],
      'comment': '',
      'created_by': user.id,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
    await db.write((t) => t.put('wakeups', wakeup));
    _schedule();
    return Wakeup(wakeup);
  }

  /// Lecture ponctuelle (pas réactive) : un formulaire ne doit pas être écrasé par une synchro
  Future<Wakeup?> getWakeup(String id) async {
    final row = await db.read((t) => t.get('wakeups', id));
    return row == null ? null : Wakeup(row);
  }

  /// [patch] : `woke_at`, `wake_type`, `reason_ids`, `action_ids`, `comment`
  Future<void> updateWakeup(String id, Map<String, dynamic> patch) async {
    await db.write((t) => t.patch('wakeups', id, _dirty(patch)));
    _schedule();
  }

  Future<void> deleteWakeup(String id) async {
    await db.write((t) => t.patch('wakeups', id, _dirty({'deleted_at': _nowIso()})));
    // délai > durée du message « Annuler » : la ligne reste restaurable localement
    _schedule(const Duration(seconds: 7));
  }

  Future<void> restoreWakeup(String id) async {
    await db.write((t) => t.patch('wakeups', id, _dirty({'deleted_at': null})));
    _schedule();
  }

  // --- Options (raisons / actions) ---

  Future<JournalOption> addOption(String journalId, OptionKind kind, String label) async {
    final siblings = (await db.read((t) => t.byJournal('options', journalId, withDeleted: true)))
        .map(JournalOption.new)
        .where((o) => o.kind == kind)
        .toList();
    // Une option archivée du même nom est restaurée plutôt que dupliquée
    final existing = siblings.where((o) => o.label.toLowerCase() == label.trim().toLowerCase()).firstOrNull;
    if (existing != null) {
      if (existing.archived) await updateOption(existing.id, {'deleted_at': null});
      return existing;
    }
    final now = _nowIso();
    final position = siblings.fold(0, (max, o) => o.position > max ? o.position : max) + 1;
    final option = _dirty({
      'id': _uuid.v4(),
      'journal_id': journalId,
      'kind': kind.name,
      'label': label.trim(),
      'position': position,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
    await db.write((t) => t.put('options', option));
    _schedule();
    return JournalOption(option);
  }

  /// [patch] : `label`, `position`, `deleted_at`
  Future<void> updateOption(String id, Map<String, dynamic> patch) async {
    await db.write((t) => t.patch('options', id, _dirty(patch)));
    _schedule();
  }

  /// Réécrit les positions dans l'ordre donné (seules les lignes modifiées sont marquées à envoyer)
  Future<void> reorderOptions(List<JournalOption> ordered) async {
    await db.write((t) async {
      for (final (i, o) in ordered.indexed) {
        if (o.position != i + 1) await t.patch('options', o.id, _dirty({'position': i + 1}));
      }
    });
    _schedule();
  }

  // --- Démarches (rituels, médication…) ---

  /// [input] : `kind`, `label`, `start_date`, `end_date`, `periods`, `comment`
  Future<Approach> addApproach(String journalId, Map<String, dynamic> input) async {
    final now = _nowIso();
    final approach = _dirty({
      'id': _uuid.v4(),
      'journal_id': journalId,
      ...input,
      'label': (input['label'] as String).trim(),
      'created_by': user.id,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
    await db.write((t) => t.put('approaches', approach));
    _schedule();
    return Approach(approach);
  }

  /// Lecture ponctuelle (pas réactive) : un formulaire ne doit pas être écrasé par une synchro
  Future<Approach?> getApproach(String id) async {
    final row = await db.read((t) => t.get('approaches', id));
    return row == null ? null : Approach(row);
  }

  Future<void> updateApproach(String id, Map<String, dynamic> patch) async {
    await db.write((t) => t.patch('approaches', id, _dirty(patch)));
    _schedule();
  }

  Future<void> deleteApproach(String id) async {
    await db.write((t) => t.patch('approaches', id, _dirty({'deleted_at': _nowIso()})));
    _schedule(const Duration(seconds: 7));
  }

  Future<void> restoreApproach(String id) async {
    await db.write((t) => t.patch('approaches', id, _dirty({'deleted_at': null})));
    _schedule();
  }

  // --- Requêtes réactives ---

  /// Journaux (non supprimés), par nom
  Stream<List<Journal>> watchJournals() => db.watch({'journals'}, (t) async {
        final rows = (await t.query('journals', where: 'deleted = 0')).map(Journal.new).toList();
        return rows..sort((a, b) => _compareText(a.name, b.name));
      });

  /// Nombre de réveils (non supprimés) par journal
  Stream<Map<String, int>> watchWakeupCounts() => db.watch({'wakeups'}, (t) async {
        final rows = await t.query('wakeups', where: 'deleted = 0');
        final counts = <String, int>{};
        for (final w in rows) {
          final id = w['journal_id'] as String;
          counts[id] = (counts[id] ?? 0) + 1;
        }
        return counts;
      });

  Stream<Journal?> watchJournal(String id) => db.watch({'journals'}, (t) async {
        final row = await t.get('journals', id);
        return row == null ? null : Journal(row);
      });

  Stream<List<Member>> watchMembers(String journalId) => db.watch(
      {'members'}, (t) async => (await t.byJournal('members', journalId)).map(Member.new).toList());

  /// Réveils (non supprimés) d'un journal, du plus récent au plus ancien
  Stream<List<Wakeup>> watchWakeups(String journalId) => db.watch(
      {'wakeups'},
      (t) async =>
          (await t.byJournal('wakeups', journalId, orderBy: 'woke_at desc')).map(Wakeup.new).toList());

  /// Raisons et actions d'un journal, y compris archivées, triées par position
  Stream<List<JournalOption>> watchOptions(String journalId) => db.watch({'options'}, (t) async {
        final rows = (await t.byJournal('options', journalId, withDeleted: true)).map(JournalOption.new).toList();
        return rows
          ..sort((a, b) => a.position != b.position ? a.position - b.position : _compareText(a.label, b.label));
      });

  /// Démarches (non supprimées) d'un journal, de la plus récente à la plus ancienne
  Stream<List<Approach>> watchApproaches(String journalId) => db.watch({'approaches'}, (t) async {
        final rows = (await t.byJournal('approaches', journalId)).map(Approach.new).toList();
        return rows
          ..sort((a, b) {
            final byDate = b.startDate.compareTo(a.startDate);
            return byDate != 0 ? byDate : _compareText(a.label, b.label);
          });
      });
}
