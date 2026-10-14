import type { Journal, AppDb } from '~/utils/db'

const online = ref(typeof navigator === 'undefined' ? true : navigator.onLine)
const syncing = ref(false)
const lastSyncAt = ref<Date | null>(null)
const lastError = ref<string | null>(null)
const pendingCount = ref(0)

let started = false
let running: Promise<void> | null = null
let rerun = false
let debounceTimer: ReturnType<typeof setTimeout> | null = null

const WAKEUP_FIELDS = ['id', 'journal_id', 'woke_at', 'wake_type', 'reason_ids', 'action_ids', 'comment', 'created_by', 'created_at', 'deleted_at'] as const
const OPTION_FIELDS = ['id', 'journal_id', 'kind', 'label', 'position', 'created_at', 'deleted_at'] as const
/** Marge de recouvrement pour ne rater aucune ligne commitée en retard */
const CURSOR_OVERLAP_MS = 60_000
const PAGE_SIZE = 500

function pick<T extends object, K extends keyof T>(obj: T, keys: readonly K[]): Pick<T, K> {
  const r = {} as Pick<T, K>
  for (const k of keys) r[k] = obj[k]
  return r
}

/** Retire le marqueur « à envoyer » sauf si la ligne a encore été modifiée pendant l'envoi */
async function markClean(table: AppDb['journals'] | AppDb['wakeups'] | AppDb['options'], rows: { id: string, _lmod: number }[]) {
  await Promise.all(rows.map(r =>
    (table as AppDb['wakeups']).where('id').equals(r.id).modify((row) => {
      if (row._lmod === r._lmod) row._dirty = 0
    })
  ))
}

function isPermissionError(err: { code?: string } | null) {
  return err?.code === '42501' || err?.code === 'PGRST301'
}

/**
 * Synchronisation bidirectionnelle IndexedDB <-> Supabase.
 * - Toute écriture est d'abord locale (marquée _dirty), puis poussée.
 * - Les changements distants sont tirés par journal grâce à updated_at (horodaté par le serveur).
 * - Conflits : la dernière écriture envoyée l'emporte ; une modif locale non envoyée n'est jamais écrasée.
 */
export function useSync() {
  const supabase = useSupabase()
  const { user } = useAuth()

  async function refreshPending() {
    if (!user.value) return
    const db = openDb(user.value.id)
    pendingCount.value = (await db.journals.where('_dirty').equals(1).count())
      + (await db.options.where('_dirty').equals(1).count())
      + (await db.wakeups.where('_dirty').equals(1).count())
  }

  async function pushJournals(db: AppDb, userId: string) {
    const dirty = await db.journals.where('_dirty').equals(1).toArray()
    if (!dirty.length) return
    const members = await db.members.toArray()
    for (const j of dirty) {
      const isOwner = j.created_by === userId
        || members.some(m => m.journal_id === j.id && m.user_id === userId && m.role === 'owner')
      const payload: Record<string, unknown> = {
        id: j.id,
        name: j.name,
        child_name: j.child_name,
        created_by: j.created_by,
        created_at: j.created_at
      }
      // Seul le propriétaire peut supprimer : on n'envoie pas ce champ sinon (refus serveur)
      if (isOwner) payload.deleted_at = j.deleted_at
      const { error } = await supabase.from('journals').upsert(payload)
      if (error && !isPermissionError(error)) throw error
      if (error) console.warn('[sync] journal refusé', j.id, error.message)
      await markClean(db.journals, [j])
    }
  }

  /** Envoie les lignes modifiées localement (réveils ou options) par lots */
  async function pushRows(db: AppDb, name: 'wakeups' | 'options') {
    const table = (name === 'wakeups' ? db.wakeups : db.options) as AppDb['wakeups']
    const remote = name === 'wakeups' ? 'wakeups' : 'journal_options'
    const fields = (name === 'wakeups' ? WAKEUP_FIELDS : OPTION_FIELDS) as readonly string[]
    const toPayload = (row: object) => pick(row as Record<string, unknown>, fields)

    const dirty = await table.where('_dirty').equals(1).toArray()
    for (let i = 0; i < dirty.length; i += 100) {
      const batch = dirty.slice(i, i + 100)
      const { error } = await supabase.from(remote).upsert(batch.map(toPayload))
      if (!error) {
        await markClean(table, batch)
        continue
      }
      if (!isPermissionError(error)) throw error
      // Lot refusé : on isole la ou les lignes fautives (journal quitté, etc.)
      for (const row of batch) {
        const { error: e } = await supabase.from(remote).upsert(toPayload(row))
        if (e && !isPermissionError(e)) throw e
        if (e) console.warn(`[sync] ${remote} refusé`, row.id, e.message)
        await markClean(table, [row])
      }
    }
  }

  async function pullJournals(db: AppDb) {
    const { data: journals, error } = await supabase.from('journals').select('*')
    if (error) throw error
    const { data: members, error: mErr } = await supabase
      .from('journal_members')
      .select('journal_id, user_id, role, profiles(display_name)')
    if (mErr) throw mErr

    const remoteIds = new Set(journals.map(j => j.id as string))
    await db.transaction('rw', [db.journals, db.members, db.wakeups, db.options, db.meta], async () => {
      for (const j of journals) {
        const local = await db.journals.get(j.id)
        if (local?._dirty) continue
        if (j.deleted_at) {
          await db.journals.delete(j.id)
          await db.wakeups.where('journal_id').equals(j.id).delete()
          await db.options.where('journal_id').equals(j.id).delete()
          await db.meta.bulkDelete([`cursor:${j.id}`, `ocursor:${j.id}`])
          continue
        }
        await db.journals.put({ ...j, _dirty: 0, _lmod: local?._lmod ?? 0 } as Journal)
      }
      // Journaux dont on n'est plus membre (et qui ne sont pas en attente de création)
      const locals = await db.journals.toArray()
      for (const l of locals) {
        if (!remoteIds.has(l.id) && !l._dirty) {
          await db.journals.delete(l.id)
          await db.wakeups.where('journal_id').equals(l.id).delete()
          await db.options.where('journal_id').equals(l.id).delete()
          await db.meta.bulkDelete([`cursor:${l.id}`, `ocursor:${l.id}`])
        }
      }
      // On garde les membres des journaux pas encore envoyés au serveur
      const pendingIds = new Set(locals.filter(l => l._dirty && !remoteIds.has(l.id)).map(l => l.id))
      await db.members.filter(m => !pendingIds.has(m.journal_id)).delete()
      await db.members.bulkPut(members.map(m => ({
        key: `${m.journal_id}:${m.user_id}`,
        journal_id: m.journal_id as string,
        user_id: m.user_id as string,
        role: m.role as 'owner' | 'member',
        display_name: (m.profiles as unknown as { display_name: string } | null)?.display_name ?? '?'
      })))
    })
    return journals.filter(j => !j.deleted_at).map(j => j.id as string)
  }

  /**
   * Tire les changements distants d'un journal (réveils ou options) depuis le dernier curseur.
   * Les réveils supprimés sont effacés localement ; les options archivées sont conservées
   * (leur libellé reste affiché sur les anciens réveils).
   */
  async function pullRows(db: AppDb, name: 'wakeups' | 'options', journalId: string) {
    const table = (name === 'wakeups' ? db.wakeups : db.options) as AppDb['wakeups']
    const remote = name === 'wakeups' ? 'wakeups' : 'journal_options'
    const cursorKey = `${name === 'wakeups' ? 'cursor' : 'ocursor'}:${journalId}`
    let cursor = ((await db.meta.get(cursorKey))?.value as string | undefined) ?? '1970-01-01T00:00:00Z'
    const since = new Date(new Date(cursor).getTime() - CURSOR_OVERLAP_MS).toISOString()
    let from = 0
    while (true) {
      const { data, error } = await supabase
        .from(remote)
        .select('*')
        .eq('journal_id', journalId)
        .gt('updated_at', since)
        .order('updated_at', { ascending: true })
        .order('id', { ascending: true })
        .range(from, from + PAGE_SIZE - 1)
      if (error) throw error
      if (!data.length) break

      await db.transaction('rw', table, async () => {
        for (const row of data) {
          const local = await table.get(row.id)
          if (local?._dirty) continue
          if (row.deleted_at && name === 'wakeups') await table.delete(row.id)
          else if (name === 'wakeups') {
            // tolère une ligne à l'ancien format (serveur pas encore migré)
            await table.put({ ...row, wake_type: row.wake_type ?? null, reason_ids: row.reason_ids ?? [], action_ids: row.action_ids ?? [], _dirty: 0, _lmod: local?._lmod ?? 0 })
          } else await table.put({ ...row, _dirty: 0, _lmod: local?._lmod ?? 0 })
        }
      })
      const last = data[data.length - 1]!.updated_at as string
      if (new Date(last) > new Date(cursor)) cursor = last
      if (data.length < PAGE_SIZE) break
      from += PAGE_SIZE
    }
    await db.meta.put({ key: cursorKey, value: cursor })
  }

  async function doSync() {
    if (!user.value || !online.value) return
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) return
    const userId = user.value.id
    const db = openDb(userId)
    syncing.value = true
    try {
      await pushJournals(db, userId)
      await pushRows(db, 'options')
      await pushRows(db, 'wakeups')
      // Les réveils supprimés et confirmés par le serveur ne sont plus utiles localement
      await db.wakeups.filter(w => !!w.deleted_at && !w._dirty).delete()
      const journalIds = await pullJournals(db)
      for (const id of journalIds) {
        await pullRows(db, 'options', id)
        await pullRows(db, 'wakeups', id)
      }
      lastSyncAt.value = new Date()
      lastError.value = null
    } catch (e) {
      lastError.value = e instanceof Error ? e.message : String(e)
      console.error('[sync]', e)
    } finally {
      syncing.value = false
      await refreshPending()
    }
  }

  /** Lance une synchro (les appels concurrents sont fusionnés) */
  function sync(): Promise<void> {
    if (running) {
      rerun = true
      return running
    }
    running = (async () => {
      do {
        rerun = false
        await doSync()
      } while (rerun)
    })().finally(() => {
      running = null
    })
    return running
  }

  /** À appeler après chaque écriture locale */
  function schedule(delay = 800) {
    refreshPending()
    if (debounceTimer) clearTimeout(debounceTimer)
    debounceTimer = setTimeout(() => sync(), delay)
  }

  function start() {
    if (started || typeof window === 'undefined') return
    started = true
    window.addEventListener('online', () => {
      online.value = true
      sync()
    })
    window.addEventListener('offline', () => {
      online.value = false
    })
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') sync()
    })
    setInterval(() => {
      if (document.visibilityState === 'visible') sync()
    }, 30_000)
    sync()
  }

  return { online, syncing, lastSyncAt, lastError, pendingCount, sync, schedule, start, refreshPending }
}
