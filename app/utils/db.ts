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

export interface Wakeup extends SyncFields {
  id: string
  journal_id: string
  woke_at: string
  reason_ids: string[]
  action_ids: string[]
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
    instances.set(userId, db)
  }
  return db
}
