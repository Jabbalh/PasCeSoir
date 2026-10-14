import type { Journal, Wakeup } from '~/utils/db'

function nowIso() {
  return new Date().toISOString()
}

export function useJournalActions() {
  const db = useDb()
  const { user } = useAuth()
  const { schedule } = useSync()

  async function createJournal(input: { name: string, child_name: string }) {
    const userId = user.value!.id
    const now = nowIso()
    const journal: Journal = {
      id: crypto.randomUUID(),
      name: input.name.trim(),
      child_name: input.child_name.trim(),
      created_by: userId,
      share_token: null,
      created_at: now,
      updated_at: now,
      deleted_at: null,
      _dirty: 1,
      _lmod: Date.now()
    }
    await db.transaction('rw', db.journals, db.members, async () => {
      await db.journals.add(journal)
      await db.members.put({ key: `${journal.id}:${userId}`, journal_id: journal.id, user_id: userId, role: 'owner', display_name: user.value!.email.split('@')[0] ?? '' })
    })
    schedule(0)
    return journal
  }

  async function updateJournal(id: string, patch: Partial<Pick<Journal, 'name' | 'child_name' | 'deleted_at'>>) {
    await db.journals.update(id, { ...patch, _dirty: 1, _lmod: Date.now() })
    schedule(0)
  }

  async function addWakeup(journalId: string, wokeAt: Date = new Date()) {
    const now = nowIso()
    const wakeup: Wakeup = {
      id: crypto.randomUUID(),
      journal_id: journalId,
      woke_at: wokeAt.toISOString(),
      reasons: [],
      actions: [],
      comment: '',
      created_by: user.value!.id,
      created_at: now,
      updated_at: now,
      deleted_at: null,
      _dirty: 1,
      _lmod: Date.now()
    }
    await db.wakeups.add(wakeup)
    schedule()
    return wakeup
  }

  async function updateWakeup(id: string, patch: Partial<Pick<Wakeup, 'woke_at' | 'reasons' | 'actions' | 'comment'>>) {
    await db.wakeups.update(id, { ...patch, _dirty: 1, _lmod: Date.now() })
    schedule()
  }

  async function deleteWakeup(id: string) {
    await db.wakeups.update(id, { deleted_at: nowIso(), _dirty: 1, _lmod: Date.now() })
    // délai > durée du toast « Annuler » : la ligne reste restaurable localement
    schedule(7000)
  }

  async function restoreWakeup(id: string) {
    await db.wakeups.update(id, { deleted_at: null, _dirty: 1, _lmod: Date.now() })
    schedule()
  }

  return { createJournal, updateJournal, addWakeup, updateWakeup, deleteWakeup, restoreWakeup }
}

/** Journal + membres (réactif) */
export function useJournal(journalId: Ref<string>) {
  const db = useDb()
  const { user } = useAuth()

  const { data: journal, loading } = useLiveQuery(
    () => db.journals.get(journalId.value),
    undefined as Journal | undefined,
    [journalId]
  )
  const { data: members } = useLiveQuery(
    () => db.members.where('journal_id').equals(journalId.value).toArray(),
    [],
    [journalId]
  )

  const isOwner = computed(() =>
    journal.value?.created_by === user.value?.id
    || members.value.some(m => m.user_id === user.value?.id && m.role === 'owner'))

  function authorName(userId: string) {
    if (userId === user.value?.id) return 'Moi'
    return members.value.find(m => m.user_id === userId)?.display_name ?? 'Ancien membre'
  }

  return { journal, loading, members, isOwner, authorName }
}

/** Tous les réveils (non supprimés) d'un journal, du plus récent au plus ancien */
export function useWakeups(journalId: Ref<string>) {
  const db = useDb()
  return useLiveQuery(
    async () => {
      const rows = await db.wakeups
        .where('[journal_id+woke_at]')
        .between([journalId.value, ''], [journalId.value, '￿'])
        .reverse()
        .toArray()
      return rows.filter(w => !w.deleted_at)
    },
    [] as Wakeup[],
    [journalId]
  )
}
