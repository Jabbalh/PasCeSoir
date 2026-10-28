import 'package:flutter/material.dart';

import '../theme.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
List<String> _strings(Object? v) => (v as List?)?.cast<String>() ?? const [];

/// Ligne locale synchronisée : vue typée sur le document JSON stocké
/// (mêmes champs que la table Supabase, plus `_dirty` et `_lmod`)
abstract class Doc {
  const Doc(this.map);

  final Map<String, dynamic> map;

  String get id => map['id'] as String;

  /// Modification locale non encore envoyée au serveur
  bool get dirty => map['_dirty'] == 1;

  /// Horodatage local de la dernière modification (évite de « nettoyer » une ligne modifiée pendant son envoi)
  int get lmod => (map['_lmod'] as num?)?.toInt() ?? 0;

  DateTime get createdAt => _date(map['created_at'])!;
  bool get deleted => map['deleted_at'] != null;
}

class Journal extends Doc {
  const Journal(super.map);

  String get name => map['name'] as String;
  String get childName => map['child_name'] as String;
  String get createdBy => map['created_by'] as String;
  String? get shareToken => map['share_token'] as String?;
}

enum OptionKind { reason, action }

/// Raison de réveil ou action, paramétrable par journal
class JournalOption extends Doc {
  const JournalOption(super.map);

  String get journalId => map['journal_id'] as String;
  OptionKind get kind => OptionKind.values.byName(map['kind'] as String);
  String get label => map['label'] as String;
  int get position => (map['position'] as num).toInt();

  /// Option archivée : masquée du choix, conservée pour l'historique
  bool get archived => deleted;
}

/// Lever du matin ou réveil nocturne
enum WakeType {
  lever('Lever', Icons.wb_twilight),
  nocturne('Réveil nocturne', Icons.bedtime_outlined);

  const WakeType(this.label, this.icon);

  final String label;
  final IconData icon;

  static WakeType? parse(Object? v) => values.where((t) => t.name == v).firstOrNull;
}

class Wakeup extends Doc {
  const Wakeup(super.map);

  String get journalId => map['journal_id'] as String;
  DateTime get wokeAt => _date(map['woke_at'])!;

  /// Vide tant que non renseigné
  WakeType? get wakeType => WakeType.parse(map['wake_type']);
  List<String> get reasonIds => _strings(map['reason_ids']);
  List<String> get actionIds => _strings(map['action_ids']);
  String get comment => map['comment'] as String? ?? '';

  /// Vide si le compte de l'auteur a été supprimé
  String? get createdBy => map['created_by'] as String?;
}

/// Type de démarche (liste fixe), avec sa couleur distincte
enum ApproachKind {
  rituel('Rituel', Icons.repeat, AppColors.info),
  medication('Médication', Icons.medication_outlined, AppColors.error),
  soin('Soin', Icons.medical_services_outlined, AppColors.tertiary),
  alimentation('Alimentation', Icons.restaurant, AppColors.success),
  environnement('Environnement', Icons.bed_outlined, AppColors.secondary),
  autre('Autre', Icons.radio_button_checked, AppColors.muted);

  const ApproachKind(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static ApproachKind parse(Object? v) => values.where((k) => k.name == v).firstOrNull ?? autre;
}

/// Moment de la journée où la démarche a lieu
enum ApproachPeriod {
  matin('matin', 'Matin'),
  midi('midi', 'Midi'),
  apresMidi('apres_midi', 'Après-midi'),
  soir('soir', 'Soir / coucher'),
  nuit('nuit', 'Nuit');

  const ApproachPeriod(this.value, this.label);

  /// Valeur stockée en base
  final String value;
  final String label;

  static ApproachPeriod? parse(Object? v) => values.where((p) => p.value == v).firstOrNull;
}

/// Démarche mise en place (rituel, médication…) de date à date ; sans date de fin = en cours
class Approach extends Doc {
  const Approach(super.map);

  String get journalId => map['journal_id'] as String;
  ApproachKind get kind => ApproachKind.parse(map['kind']);
  String get label => map['label'] as String;

  /// AAAA-MM-JJ
  String get startDate => map['start_date'] as String;

  /// AAAA-MM-JJ inclus ; null = toujours en cours
  String? get endDate => map['end_date'] as String?;
  List<ApproachPeriod> get periods => _strings(map['periods']).map(ApproachPeriod.parse).nonNulls.toList();
  String get comment => map['comment'] as String? ?? '';
  String? get createdBy => map['created_by'] as String?;
}

/// Membre d'un journal, avec son nom affiché (lecture seule, tiré du serveur)
class Member {
  const Member(this.map);

  final Map<String, dynamic> map;

  String get journalId => map['journal_id'] as String;
  String get userId => map['user_id'] as String;
  bool get isOwner => map['role'] == 'owner';
  String get displayName => map['display_name'] as String;
}

/// Nom de l'auteur d'un réveil ou d'une démarche
String authorName(List<Member> members, String? userId, String meId) {
  if (userId == null) return 'Compte supprimé';
  if (userId == meId) return 'Moi';
  return members.where((m) => m.userId == userId).firstOrNull?.displayName ?? 'Ancien membre';
}

/// Raisons et actions d'un journal (y compris archivées), triées par position
class OptionList {
  OptionList(this.all) : _byId = {for (final o in all) o.id: o};

  final List<JournalOption> all;
  final Map<String, JournalOption> _byId;

  List<JournalOption> get reasons => all.where((o) => o.kind == OptionKind.reason && !o.archived).toList();
  List<JournalOption> get actions => all.where((o) => o.kind == OptionKind.action && !o.archived).toList();
  List<JournalOption> get archived => all.where((o) => o.archived).toList();

  /// Libellé d'une option (y compris archivée)
  String labelOf(String id) => _byId[id]?.label ?? '?';
}
