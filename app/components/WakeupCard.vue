<script setup lang="ts">
import type { Wakeup } from '~/utils/db'

const props = defineProps<{
  wakeup: Wakeup
  author: string
  labelOf: (id: string) => string
  showDate?: boolean
}>()

const incomplete = computed(() => !props.wakeup.reason_ids.length && !props.wakeup.action_ids.length && !props.wakeup.comment)
const wakeType = computed(() => WAKE_TYPES.find(t => t.value === props.wakeup.wake_type))
const commentText = computed(() => props.wakeup.comment.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim())
</script>

<template>
  <NuxtLink
    :to="`/journal/${wakeup.journal_id}/reveil/${wakeup.id}`"
    class="block p-3.5 rounded-xl border bg-elevated/40 hover:bg-elevated active:scale-[0.99] transition"
    :class="incomplete ? 'border-dashed border-primary/50' : 'border-default'"
  >
    <div class="flex items-center gap-3">
      <div class="text-2xl font-bold tabular-nums">
        {{ formatTime(wakeup.woke_at) }}
      </div>
      <div class="min-w-0 flex-1">
        <p v-if="showDate" class="text-xs text-muted">
          {{ formatDateTime(wakeup.woke_at) }}
        </p>
        <p v-if="wakeType" class="text-sm font-medium flex items-center gap-1">
          <UIcon :name="wakeType.icon" class="size-3.5" /> {{ wakeType.label }}
        </p>
        <p class="text-xs text-muted flex items-center gap-1">
          <UIcon name="i-lucide-user" class="size-3" /> {{ author }}
          <UIcon v-if="wakeup._dirty" name="i-lucide-cloud-upload" class="size-3 text-warning ml-1" />
        </p>
      </div>
      <UBadge v-if="incomplete" color="primary" variant="soft" size="sm" icon="i-lucide-pencil">
        À compléter
      </UBadge>
      <UIcon v-else name="i-lucide-chevron-right" class="size-5 text-muted" />
    </div>

    <div v-if="wakeup.reason_ids.length || wakeup.action_ids.length" class="flex flex-wrap gap-1.5 mt-2">
      <UBadge v-for="r in wakeup.reason_ids" :key="`r-${r}`" color="warning" variant="subtle" size="sm">
        {{ labelOf(r) }}
      </UBadge>
      <UBadge v-for="a in wakeup.action_ids" :key="`a-${a}`" color="success" variant="subtle" size="sm" icon="i-lucide-hand-heart">
        {{ labelOf(a) }}
      </UBadge>
    </div>
    <p v-if="commentText" class="text-sm text-muted mt-2 line-clamp-2">
      {{ commentText }}
    </p>
  </NuxtLink>
</template>
