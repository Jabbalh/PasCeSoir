<script setup lang="ts">
const { online, syncing, pendingCount, lastSyncAt, lastError, sync } = useSync()

const state = computed(() => {
  if (!online.value) return { icon: 'i-lucide-cloud-off', color: 'warning' as const, label: 'Hors ligne' }
  if (syncing.value) return { icon: 'i-lucide-refresh-cw', color: 'neutral' as const, label: 'Synchro…' }
  if (lastError.value) return { icon: 'i-lucide-cloud-alert', color: 'error' as const, label: 'Erreur' }
  if (pendingCount.value) return { icon: 'i-lucide-cloud-upload', color: 'warning' as const, label: 'En attente' }
  return { icon: 'i-lucide-cloud-check', color: 'success' as const, label: 'À jour' }
})

const tooltip = computed(() => {
  const parts: string[] = []
  if (pendingCount.value) parts.push(`${pendingCount.value} modification(s) à envoyer`)
  if (lastError.value) parts.push(lastError.value)
  if (lastSyncAt.value) parts.push(`Dernière synchro : ${formatTime(lastSyncAt.value)}`)
  return parts.join(' · ') || 'Synchroniser'
})
</script>

<template>
  <UTooltip :text="tooltip">
    <UButton
      :icon="state.icon"
      :color="state.color"
      variant="ghost"
      size="sm"
      :aria-label="state.label"
      :ui="{ leadingIcon: syncing ? 'animate-spin' : '' }"
      @click="sync()"
    >
      <span class="text-xs">{{ pendingCount && !syncing ? pendingCount : '' }}</span>
    </UButton>
  </UTooltip>
</template>
