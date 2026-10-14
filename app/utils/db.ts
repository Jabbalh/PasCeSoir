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

export interface Wakeup extends SyncFields {
  id: string
  journal_id: string
  woke_at: string
  reasons: string[]
  actions: string[]
  comment: string
  created_by: string
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
  wakeups: EntityTable<Wakeup, 'id'>
  members: EntityTable<Member, 'key'>
  meta: EntityTable<Meta, 'key'>
}

const instances = new Map<string, AppDb>()

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
    instances.set(userId, db)
  }
  return db
}
