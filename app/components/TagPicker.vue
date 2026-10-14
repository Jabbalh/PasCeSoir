<script setup lang="ts">
interface PickerOption {
  id: string
  label: string
}

const props = defineProps<{
  /** options actives du journal */
  options: PickerOption[]
  /** libellé d'un identifiant (pour les options archivées encore sélectionnées) */
  labelOf: (id: string) => string
  /** crée une nouvelle option dans le journal et renvoie son identifiant */
  create: (label: string) => Promise<string>
  color?: 'primary' | 'warning' | 'success' | 'neutral'
  placeholder?: string
}>()
const model = defineModel<string[]>({ required: true })

const custom = ref('')

/** Options actives + options archivées encore sélectionnées sur ce réveil */
const allOptions = computed(() => {
  const list = [...props.options]
  for (const id of model.value) {
    if (!list.some(o => o.id === id)) list.push({ id, label: props.labelOf(id) })
  }
  return list
})

function toggle(id: string) {
  model.value = model.value.includes(id)
    ? model.value.filter(v => v !== id)
    : [...model.value, id]
}

async function addCustom() {
  const label = custom.value.trim()
  if (!label) return
  const id = await props.create(label)
  if (!model.value.includes(id)) model.value = [...model.value, id]
  custom.value = ''
}
</script>

<template>
  <div class="space-y-2">
    <div class="flex flex-wrap gap-2">
      <UButton
        v-for="opt in allOptions"
        :key="opt.id"
        size="md"
        :color="model.includes(opt.id) ? (color ?? 'primary') : 'neutral'"
        :variant="model.includes(opt.id) ? 'solid' : 'outline'"
        :icon="model.includes(opt.id) ? 'i-lucide-check' : undefined"
        class="rounded-full"
        @click="toggle(opt.id)"
      >
        {{ opt.label }}
      </UButton>
    </div>
    <form class="flex gap-2" @submit.prevent="addCustom">
      <UInput v-model="custom" :placeholder="placeholder ?? 'Autre…'" class="flex-1" size="md" />
      <UButton type="submit" icon="i-lucide-plus" color="neutral" variant="soft" :disabled="!custom.trim()" aria-label="Ajouter" />
    </form>
  </div>
</template>
