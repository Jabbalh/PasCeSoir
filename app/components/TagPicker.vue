<script setup lang="ts">
const props = defineProps<{
  options: string[]
  color?: 'primary' | 'warning' | 'success' | 'neutral'
  placeholder?: string
}>()
const model = defineModel<string[]>({ required: true })

const custom = ref('')

const allOptions = computed(() => {
  const set = new Set(props.options)
  for (const v of model.value) set.add(v)
  return [...set]
})

function toggle(value: string) {
  model.value = model.value.includes(value)
    ? model.value.filter(v => v !== value)
    : [...model.value, value]
}

function addCustom() {
  const value = custom.value.trim()
  if (!value) return
  const existing = allOptions.value.find(o => o.toLowerCase() === value.toLowerCase())
  if (!model.value.includes(existing ?? value)) model.value = [...model.value, existing ?? value]
  custom.value = ''
}
</script>

<template>
  <div class="space-y-2">
    <div class="flex flex-wrap gap-2">
      <UButton
        v-for="opt in allOptions"
        :key="opt"
        size="md"
        :color="model.includes(opt) ? (color ?? 'primary') : 'neutral'"
        :variant="model.includes(opt) ? 'solid' : 'outline'"
        :icon="model.includes(opt) ? 'i-lucide-check' : undefined"
        class="rounded-full"
        @click="toggle(opt)"
      >
        {{ opt }}
      </UButton>
    </div>
    <form class="flex gap-2" @submit.prevent="addCustom">
      <UInput v-model="custom" :placeholder="placeholder ?? 'Autre…'" class="flex-1" size="md" />
      <UButton type="submit" icon="i-lucide-plus" color="neutral" variant="soft" :disabled="!custom.trim()" aria-label="Ajouter" />
    </form>
  </div>
</template>
