import Dexie, { type EntityTable } from 'dexie'

/** Champs techniques locaux pour la synchronisation */
interface SyncFields {
  /** 1 = modification locale non encore envoyée au serveur */
  _dirty: 0 | 1
  /** horodatage local de la dernière modification (évite d'écraser une modif faite pendant l'envoi) */
  _lmod: number
}

export interface Journal extends SyncFields {
  id: string
  name: string
  child_name: string
  created_by: string
  share_token: string | null
  created_at: string
  updated_at: string
  deleted_at: string | null
}

export type OptionKind = 'reason' | 'action'

/** Raison de réveil ou action, paramétrable par journal */
export interface JournalOption extends SyncFields {
  id: string
  journal_id: string
  kind: OptionKind
  label: string
  position: number
  created_at: string
  updated_at: string
  /** option archivée : masquée du choix, conservée pour l'historique */
  deleted_at: string | null
}

/** Lever du matin ou réveil nocturne */
export type WakeType = 'lever' | 'nocturne'

export const WAKE_TYPES: { value: WakeType, label: string, icon: string }[] = [
  { value: 'lever', label: 'Lever', icon: 'i-lucide-sunrise' },
  { value: 'nocturne', label: 'Réveil nocturne', icon: 'i-lucide-moon' }
]

export interface Wakeup extends SyncFields {
  id: string
  journal_id: string
  woke_at: string
  /** vide tant que non renseigné (absent sur les lignes locales antérieures) */
  wake_type?: WakeType | null
  reason_ids: string[]
  action_ids: string[]
  comment: string
  /** vide si le compte de l'auteur a été supprimé */
  created_by: string | null
  created_at: string
  updated_at: string
  deleted_at: string | null
}

/** Type de démarche (liste fixe) */
export type ApproachKind = 'rituel' | 'medication' | 'alimentation' | 'environnement' | 'autre'

/** `bar` : couleur pleine (frise des statistiques) ; `soft` : pastille d'icône (classes écrites en entier pour Tailwind) */
export const APPROACH_KINDS: { value: ApproachKind, label: string, icon: string, color: 'info' | 'error' | 'success' | 'secondary' | 'neutral', bar: string, soft: string }[] = [
  { value: 'rituel', label: 'Rituel', icon: 'i-lucide-repeat', color: 'info', bar: 'bg-info', soft: 'bg-info/15 text-info' },
  { value: 'medication', label: 'Médication', icon: 'i-lucide-pill', color: 'error', bar: 'bg-error', soft: 'bg-error/15 text-error' },
  { value: 'alimentation', label: 'Alimentation', icon: 'i-lucide-utensils', color: 'success', bar: 'bg-success', soft: 'bg-success/15 text-success' },
  { value: 'environnement', label: 'Environnement', icon: 'i-lucide-bed', color: 'secondary', bar: 'bg-secondary', soft: 'bg-secondary/15 text-secondary' },
  { value: 'autre', label: 'Autre', icon: 'i-lucide-circle-dot', color: 'neutral', bar: 'bg-inverted/50', soft: 'bg-elevated text-muted' }
]

export function approachKind(kind: ApproachKind) {
  return APPROACH_KINDS.find(k => k.value === kind) ?? APPROACH_KINDS[APPROACH_KINDS.length - 1]!
}

/** Moment de la journée où la démarche a lieu */
export type DayPeriod = 'matin' | 'midi' | 'apres_midi' | 'soir' | 'nuit'

export const DAY_PERIODS: { value: DayPeriod, label: string }[] = [
  { value: 'matin', label: 'Matin' },
  { value: 'midi', label: 'Midi' },
  { value: 'apres_midi', label: 'Après-midi' },
  { value: 'soir', label: 'Soir / coucher' },
  { value: 'nuit', label: 'Nuit' }
]

/** Démarche mise en place (rituel, médication…) de date à date ; sans date de fin = en cours */
export interface Approach extends SyncFields {
  id: string
  journal_id: string
  kind: ApproachKind
  label: string
  /** AAAA-MM-JJ */
  start_date: string
  /** AAAA-MM-JJ inclus ; null = toujours en cours */
  end_date: string | null
  periods: DayPeriod[]
  comment: string
  /** vide si le compte de l'auteur a été supprimé */
  created_by: string | null
  created_at: string
  updated_at: string
  deleted_at: string | null
}

export interface Member {
  key: string
  journal_id: string
  user_id: string
  role: 'owner' | 'member'
  display_name: string
}

export interface Meta {
  key: string
  value: unknown
}

export type AppDb = Dexie & {
  journals: EntityTable<Journal, 'id'>
  options: EntityTable<JournalOption, 'id'>
  wakeups: EntityTable<Wakeup, 'id'>
  approaches: EntityTable<Approach, 'id'>
  members: EntityTable<Member, 'key'>
  meta: EntityTable<Meta, 'key'>
}

const instances = new Map<string, AppDb>()

/** Supprime définitivement la base locale d'un utilisateur */
export async function deleteDb(userId: string) {
  const db = openDb(userId)
  instances.delete(userId)
  await db.delete()
}

/** Une base IndexedDB par utilisateur : pas de mélange de données entre comptes */
export function openDb(userId: string): AppDb {
  let db = instances.get(userId)
  if (!db) {
    db = new Dexie(`pascesoir-${userId}`) as AppDb
    db.version(1).stores({
      journals: 'id, _dirty',
      wakeups: 'id, journal_id, [journal_id+woke_at], _dirty',
      members: 'key, journal_id',
      meta: 'key'
    })
    // v2 : options par journal ; les réveils (libellés -> identifiants) sont rechargés depuis le serveur
    db.version(2).stores({
      options: 'id, journal_id, _dirty'
    }).upgrade(async (tx) => {
      await tx.table('wakeups').filter(w => !w._dirty).delete()
      await tx.table('meta').clear()
    })
    // v3 : nouveau rechargement complet, des lignes à l'ancien format ayant pu être tirées
    // avant la migration serveur. Les modifications non envoyées sont conservées.
    db.version(3).stores({}).upgrade(async (tx) => {
      await tx.table('wakeups').filter(w => !w._dirty).delete()
      await tx.table('wakeups').toCollection().modify((w) => {
        w.reason_ids ??= []
        w.action_ids ??= []
        delete w.reasons
        delete w.actions
      })
      await tx.table('meta').clear()
    })
    // v4 : démarches (rituels, médication…)
    db.version(4).stores({
      approaches: 'id, journal_id, _dirty'
    })
    instances.set(userId, db)
  }
  return db
}
