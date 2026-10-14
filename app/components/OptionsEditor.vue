<script setup lang="ts">
import type { JournalOption, OptionKind } from '~/utils/db'

const props = defineProps<{
  journalId: string
  kind: OptionKind
  /** options actives, triées */
  options: JournalOption[]
  /** options archivées */
  archived: JournalOption[]
  /** nombre de réveils utilisant chaque option */
  usage: Map<string, number>
}>()

const { addOption, updateOption, reorderOptions } = useJournalActions()
const toast = useToast()

const newLabel = ref('')
const editingId = ref<string | null>(null)
const editingLabel = ref('')
const showArchived = ref(false)

const archivedOfKind = computed(() => props.archived.filter(o => o.kind === props.kind))

async function add() {
  const label = newLabel.value.trim()
  if (!label) return
  await addOption(props.journalId, props.kind, label)
  newLabel.value = ''
}

function startEdit(o: JournalOption) {
  editingId.value = o.id
  editingLabel.value = o.label
}

async function commitEdit(o: JournalOption) {
  const label = editingLabel.value.trim()
  editingId.value = null
  if (!label || label === o.label) return
  const duplicate = props.options.some(x => x.id !== o.id && x.label.toLowerCase() === label.toLowerCase())
  if (duplicate) {
    toast.add({ title: 'Ce libellé existe déjà', color: 'warning' })
    return
  }
  await updateOption(o.id, { label })
}

async function move(index: number, delta: -1 | 1) {
  const list = [...props.options]
  const target = index + delta
  if (target < 0 || target >= list.length) return
  ;[list[index], list[target]] = [list[target]!, list[index]!]
  await reorderOptions(list)
}

async function archive(o: JournalOption) {
  await updateOption(o.id, { deleted_at: new Date().toISOString() })
  toast.add({
    title: `« ${o.label} » retiré de la liste`,
    description: 'Les réveils existants le conservent.',
    actions: [{ label: 'Annuler', color: 'neutral', variant: 'outline', onClick: () => updateOption(o.id, { deleted_at: null }) }]
  })
}

async function restore(o: JournalOption) {
  // remis en fin de liste
  await updateOption(o.id, { deleted_at: null, position: Math.max(0, ...props.options.map(x => x.position)) + 1 })
}
</script>

<template>
  <div class="space-y-3">
    <ul class="divide-y divide-default rounded-lg border border-default">
      <li v-for="(o, i) in options" :key="o.id" class="flex items-center gap-1 pl-3 pr-1 py-1.5">
        <form v-if="editingId === o.id" class="flex-1 flex gap-1" @submit.prevent="commitEdit(o)">
          <UInput v-model="editingLabel" size="sm" class="flex-1" autofocus @blur="commitEdit(o)" @keydown.esc="editingId = null" />
        </form>
        <button v-else type="button" class="flex-1 min-w-0 text-left py-1" @click="startEdit(o)">
          <span class="truncate">{{ o.label }}</span>
          <span v-if="usage.get(o.id)" class="text-xs text-muted ml-1.5">· {{ usage.get(o.id) }}</span>
          <UIcon v-if="o._dirty" name="i-lucide-cloud-upload" class="size-3 text-warning ml-1" />
        </button>
        <UButton icon="i-lucide-chevron-up" size="xs" color="neutral" variant="ghost" :disabled="i === 0" aria-label="Monter" @click="move(i, -1)" />
        <UButton icon="i-lucide-chevron-down" size="xs" color="neutral" variant="ghost" :disabled="i === options.length - 1" aria-label="Descendre" @click="move(i, 1)" />
        <UButton icon="i-lucide-x" size="xs" color="error" variant="ghost" aria-label="Retirer de la liste" @click="archive(o)" />
      </li>
      <li v-if="!options.length" class="px-3 py-3 text-sm text-muted">
        Aucun élément. Ajoutez-en ci-dessous.
      </li>
    </ul>

    <form class="flex gap-2" @submit.prevent="add">
      <UInput v-model="newLabel" :placeholder="kind === 'reason' ? 'Nouvelle raison…' : 'Nouvelle action…'" class="flex-1" />
      <UButton type="submit" icon="i-lucide-plus" :disabled="!newLabel.trim()">
        Ajouter
      </UButton>
    </form>

    <div v-if="archivedOfKind.length">
      <UButton
        size="xs"
        variant="link"
        color="neutral"
        :icon="showArchived ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
        @click="showArchived = !showArchived"
      >
        {{ archivedOfKind.length }} élément(s) retiré(s)
      </UButton>
      <ul v-if="showArchived" class="mt-1 space-y-1">
        <li v-for="o in archivedOfKind" :key="o.id" class="flex items-center gap-2 pl-3 text-sm text-muted">
          <span class="flex-1 line-through truncate">{{ o.label }}</span>
          <UButton size="xs" variant="ghost" color="neutral" icon="i-lucide-undo-2" @click="restore(o)">
            Remettre
          </UButton>
        </li>
      </ul>
    </div>
  </div>
</template>
