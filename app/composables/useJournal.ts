import type { Approach, Journal, JournalOption, OptionKind, Wakeup } from '~/utils/db'

function nowIso() {
  return new Date().toISOString()
}

function newOption(journalId: string, kind: OptionKind, label: string, position: number): JournalOption {
  const now = nowIso()
  return {
    id: crypto.randomUUID(),
    journal_id: journalId,
    kind,
    label: label.trim(),
    position,
    created_at: now,
    updated_at: now,
    deleted_at: null,
    _dirty: 1,
    _lmod: Date.now()
  }
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
    // Aucune raison ni action par défaut : chaque journal construit ses propres listes
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
      wake_type: null,
      reason_ids: [],
      action_ids: [],
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

  async function updateWakeup(id: string, patch: Partial<Pick<Wakeup, 'woke_at' | 'wake_type' | 'reason_ids' | 'action_ids' | 'comment'>>) {
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

  // --- Options (raisons / actions) ---

  async function addOption(journalId: string, kind: OptionKind, label: string) {
    const siblings = await db.options.where('journal_id').equals(journalId).filter(o => o.kind === kind).toArray()
    // Une option archivée du même nom est restaurée plutôt que dupliquée
    const existing = siblings.find(o => o.label.toLowerCase() === label.trim().toLowerCase())
    if (existing) {
      if (existing.deleted_at) await updateOption(existing.id, { deleted_at: null })
      return existing
    }
    const option = newOption(journalId, kind, label, Math.max(0, ...siblings.map(o => o.position)) + 1)
    await db.options.add(option)
    schedule()
    return option
  }

  async function updateOption(id: string, patch: Partial<Pick<JournalOption, 'label' | 'position' | 'deleted_at'>>) {
    await db.options.update(id, { ...patch, _dirty: 1, _lmod: Date.now() })
    schedule()
  }

  /** Réécrit les positions dans l'ordre donné (seules les lignes modifiées sont marquées à envoyer) */
  async function reorderOptions(ordered: JournalOption[]) {
    const lmod = Date.now()
    await db.transaction('rw', db.options, async () => {
      for (const [i, o] of ordered.entries()) {
        if (o.position !== i + 1) await db.options.update(o.id, { position: i + 1, _dirty: 1, _lmod: lmod })
      }
    })
    schedule()
  }

  // --- Démarches (rituels, médication…) ---

  type ApproachInput = Pick<Approach, 'kind' | 'label' | 'start_date' | 'end_date' | 'periods' | 'comment'>

  async function addApproach(journalId: string, input: ApproachInput) {
    const now = nowIso()
    const approach: Approach = {
      id: crypto.randomUUID(),
      journal_id: journalId,
      ...input,
      label: input.label.trim(),
      created_by: user.value!.id,
      created_at: now,
      updated_at: now,
      deleted_at: null,
      _dirty: 1,
      _lmod: Date.now()
    }
    await db.approaches.add(approach)
    schedule()
    return approach
  }

  async function updateApproach(id: string, patch: Partial<ApproachInput>) {
    await db.approaches.update(id, { ...patch, _dirty: 1, _lmod: Date.now() })
    schedule()
  }

  async function deleteApproach(id: string) {
    await db.approaches.update(id, { deleted_at: nowIso(), _dirty: 1, _lmod: Date.now() })
    schedule(7000)
  }

  async function restoreApproach(id: string) {
    await db.approaches.update(id, { deleted_at: null, _dirty: 1, _lmod: Date.now() })
    schedule()
  }

  return {
    createJournal, updateJournal,
    addWakeup, updateWakeup, deleteWakeup, restoreWakeup,
    addOption, updateOption, reorderOptions,
    addApproach, updateApproach, deleteApproach, restoreApproach
  }
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

  function authorName(userId: string | null) {
    if (!userId) return 'Compte supprimé'
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

/** Raisons et actions d'un journal (réactif), triées par position */
export function useOptions(journalId: Ref<string>) {
  const db = useDb()
  const { data: all } = useLiveQuery(
    async () => (await db.options.where('journal_id').equals(journalId.value).toArray())
      .sort((a, b) => a.position - b.position || a.label.localeCompare(b.label)),
    [] as JournalOption[],
    [journalId]
  )

  const byId = computed(() => new Map(all.value.map(o => [o.id, o])))
  const reasons = computed(() => all.value.filter(o => o.kind === 'reason' && !o.deleted_at))
  const actions = computed(() => all.value.filter(o => o.kind === 'action' && !o.deleted_at))
  const archived = computed(() => all.value.filter(o => o.deleted_at))

  /** Libellé d'une option (y compris archivée) */
  function labelOf(id: string) {
    return byId.value.get(id)?.label ?? '?'
  }

  return { all, byId, reasons, actions, archived, labelOf }
}

/** Démarches (non supprimées) d'un journal, de la plus récente à la plus ancienne */
export function useApproaches(journalId: Ref<string>) {
  const db = useDb()
  return useLiveQuery(
    async () => (await db.approaches.where('journal_id').equals(journalId.value).toArray())
      .filter(a => !a.deleted_at)
      .sort((a, b) => b.start_date.localeCompare(a.start_date) || a.label.localeCompare(b.label)),
    [] as Approach[],
    [journalId]
  )
}
